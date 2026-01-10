import SwiftUI
import Grape

/// A force-directed network graph showing movie connections
struct MovieNetworkGraphView: View {
    let graph: MovieGraph
    let connectionReasons: [String: String]

    @State private var graphState = ForceDirectedGraphState()
    @State private var selectedNode: MovieNode?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Network Graph")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    graphState.modelTransform = .identity
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if graph.nodes.isEmpty {
                ContentUnavailableView {
                    Label("No Connections", systemImage: "link.badge.plus")
                } description: {
                    Text("No movie connections to display.")
                }
                .frame(height: 300)
            } else {
                graphView
                    .frame(height: 350)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.quaternary.opacity(0.3))
                    )
            }
        }
    }

    private var graphView: some View {
        ForceDirectedGraph(states: graphState) {
            // Define nodes with labels
            Series(graph.nodes) { node in
                NodeMark(id: node.id)
                    .symbol(.circle)
                    .symbolSize(radius: node.isSourceMovie ? 12.0 : 8.0)
                    .foregroundStyle(nodeColor(for: node))
                    .stroke()
                    .annotation(node.id, alignment: .bottom, offset: CGVector(dx: 0, dy: 20)) {
                        nodeLabel(for: node)
                    }
            }

            // Define edges/links
            Series(graph.edges) { edge in
                LinkMark(from: edge.sourceID, to: edge.targetID)
            }
        } force: {
            .manyBody(strength: -30)
            .center()
            .link(
                originalLength: 80.0,
                stiffness: .weightedByDegree { _, _ in 0.8 }
            )
        }
        .graphOverlay { proxy in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .withGraphDragGesture(proxy, of: String.self)
                .onTapGesture { location in
                    if let nodeID = proxy.node(of: String.self, at: location) {
                        if let node = graph.nodes.first(where: { $0.id == nodeID }) {
                            selectedNode = node
                        }
                    }
                }
        }
        .navigationDestination(item: $selectedNode) { node in
            ConnectedMovieDetailView(
                movieTitle: node.title,
                movieYear: node.year
            )
        }
    }

    @ViewBuilder
    private func nodeLabel(for node: MovieNode) -> some View {
        Text(abbreviatedTitle(node.title))
            .font(.system(size: node.isSourceMovie ? 10 : 8, weight: node.isSourceMovie ? .semibold : .regular))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(node.isSourceMovie ? Color.blue : Color.black.opacity(0.75))
                    .shadow(radius: 2, y: 1)
            }
    }

    private func nodeColor(for node: MovieNode) -> Color {
        if node.isSourceMovie {
            return .blue
        }

        let isInfluencer = graph.edges.contains { $0.sourceID == node.id }
        let isInfluenced = graph.edges.contains { $0.targetID == node.id }

        if isInfluencer && isInfluenced {
            return .purple
        } else if isInfluencer {
            return .orange
        } else {
            return .green
        }
    }

    private func abbreviatedTitle(_ title: String) -> String {
        if title.count <= 15 {
            return title
        }
        let words = title.split(separator: " ")
        if words.count > 2 {
            return words.prefix(2).joined(separator: " ") + "..."
        }
        return String(title.prefix(12)) + "..."
    }
}

// MARK: - Full Screen Graph View

/// Full-screen expandable view for the network graph
struct MovieNetworkGraphDetailView: View {
    let movie: Movie
    @State private var graph: MovieGraph = .empty
    @State private var connectionReasons: [String: String] = [:]
    @State private var isLoading = true
    @State private var graphState = ForceDirectedGraphState()
    @State private var selectedNode: MovieNode?

    private let curatedService = CuratedConnectionsService()

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading connections...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if graph.isEmpty {
                ContentUnavailableView {
                    Label("No Connections Found", systemImage: "link.badge.plus")
                } description: {
                    Text("No movie connections were found for this film.")
                }
            } else {
                graphContent
            }
        }
        .navigationTitle("Connection Graph")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    graphState.modelTransform = .identity
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
        }
        .task {
            await loadConnections()
        }
        .navigationDestination(item: $selectedNode) { node in
            ConnectedMovieDetailView(
                movieTitle: node.title,
                movieYear: node.year
            )
        }
    }

    private var graphContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ForceDirectedGraph(states: graphState) {
                    // Nodes with labels
                    Series(graph.nodes) { node in
                        NodeMark(id: node.id)
                            .symbol(.circle)
                            .symbolSize(radius: nodeSize(for: node))
                            .foregroundStyle(nodeColor(for: node))
                            .stroke()
                            .annotation(node.id, alignment: .bottom, offset: CGVector(dx: 0, dy: 20)) {
                                nodeLabel(for: node)
                            }
                    }

                    // Links/edges
                    Series(graph.edges) { edge in
                        LinkMark(from: edge.sourceID, to: edge.targetID)
                    }
                } force: {
                    .manyBody(strength: -50)
                    .center()
                    .link(
                        originalLength: 100.0,
                        stiffness: .weightedByDegree { _, _ in 0.6 }
                    )
                }
                .graphOverlay { proxy in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .withGraphDragGesture(proxy, of: String.self)
                        .onTapGesture { location in
                            if let nodeID = proxy.node(of: String.self, at: location) {
                                if let node = graph.nodes.first(where: { $0.id == nodeID }) {
                                    // Don't navigate to the same movie we're viewing
                                    if node.title.lowercased() != movie.displayTitle.lowercased() {
                                        selectedNode = node
                                    }
                                }
                            }
                        }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)

                // Legend and stats
                VStack(spacing: 8) {
                    Text("\(graph.nodes.count) films, \(graph.edges.count) connections")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    legendView
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func nodeLabel(for node: MovieNode) -> some View {
        Text(abbreviatedTitle(node.title))
            .font(.system(size: node.isSourceMovie ? 11 : 9, weight: node.isSourceMovie ? .semibold : .regular))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(node.isSourceMovie ? Color.blue : Color.black.opacity(0.75))
                    .shadow(radius: 2, y: 1)
            }
    }

    private func nodeSize(for node: MovieNode) -> Double {
        if node.isSourceMovie {
            return 14.0
        }
        let connectionCount = graph.edges.filter { $0.sourceID == node.id || $0.targetID == node.id }.count
        return Double(8 + min(connectionCount * 2, 8))
    }

    private var legendView: some View {
        HStack(spacing: 12) {
            legendItem(color: .blue, label: "Selected")
            legendItem(color: .purple, label: "Hub")
            legendItem(color: .orange, label: "Influencer")
            legendItem(color: .green, label: "Influenced")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func nodeColor(for node: MovieNode) -> Color {
        if node.isSourceMovie {
            return .blue
        }

        let isInfluencer = graph.edges.contains { $0.sourceID == node.id }
        let isInfluenced = graph.edges.contains { $0.targetID == node.id }

        if isInfluencer && isInfluenced {
            return .purple
        } else if isInfluencer {
            return .orange
        } else {
            return .green
        }
    }

    private func abbreviatedTitle(_ title: String) -> String {
        if title.count <= 18 {
            return title
        }
        let words = title.split(separator: " ")
        if words.count > 2 {
            return words.prefix(2).joined(separator: " ") + "..."
        }
        return String(title.prefix(15)) + "..."
    }

    private func loadConnections() async {
        let (recursiveGraph, reasons) = await loadConnectionsRecursively(
            startingFrom: movie.displayTitle,
            maxDepth: 2
        )

        await MainActor.run {
            self.graph = recursiveGraph
            self.connectionReasons = reasons
            self.isLoading = false
        }
    }

    private func loadConnectionsRecursively(
        startingFrom movieTitle: String,
        maxDepth: Int
    ) async -> (MovieGraph, [String: String]) {
        var allNodes: [String: MovieNode] = [:]
        var allEdges: Set<EdgeKey> = []
        var reasons: [String: String] = [:]
        var visitedTitles: Set<String> = []

        struct EdgeKey: Hashable {
            let sourceID: String
            let targetID: String
        }

        var queue: [(title: String, depth: Int, isSource: Bool)] = [(movieTitle, 0, true)]

        while !queue.isEmpty {
            let (currentTitle, currentDepth, _) = queue.removeFirst()

            guard !visitedTitles.contains(currentTitle.lowercased()) else { continue }
            guard currentDepth <= maxDepth else { continue }

            visitedTitles.insert(currentTitle.lowercased())

            let movieGraph = await curatedService.fetchConnections(for: currentTitle)

            guard !movieGraph.isEmpty else { continue }

            for node in movieGraph.nodes {
                let nodeID = normalizeNodeID(title: node.title)

                if allNodes[nodeID] == nil {
                    let isOriginalSource = node.isSourceMovie && currentTitle.lowercased() == movieTitle.lowercased()
                    allNodes[nodeID] = MovieNode(
                        id: nodeID,
                        title: node.title,
                        year: node.year,
                        isSourceMovie: isOriginalSource
                    )
                }

                if !node.isSourceMovie && currentDepth < maxDepth {
                    queue.append((node.title, currentDepth + 1, false))
                }

                if !node.isSourceMovie {
                    if let reason = await curatedService.getConnectionReason(
                        for: currentTitle,
                        connectedTo: node.title
                    ) {
                        reasons[node.title] = reason
                    }
                }
            }

            for edge in movieGraph.edges {
                let sourceNode = movieGraph.nodes.first { $0.id == edge.sourceID }
                let targetNode = movieGraph.nodes.first { $0.id == edge.targetID }

                guard let sourceTitle = sourceNode?.title,
                      let targetTitle = targetNode?.title else { continue }

                let normalizedSourceID = normalizeNodeID(title: sourceTitle)
                let normalizedTargetID = normalizeNodeID(title: targetTitle)

                let edgeKey = EdgeKey(sourceID: normalizedSourceID, targetID: normalizedTargetID)
                let reverseEdgeKey = EdgeKey(sourceID: normalizedTargetID, targetID: normalizedSourceID)

                if !allEdges.contains(edgeKey) && !allEdges.contains(reverseEdgeKey) {
                    allEdges.insert(edgeKey)
                }
            }
        }

        let nodes = Array(allNodes.values)
        let edges = allEdges.map { MovieEdge(sourceID: $0.sourceID, targetID: $0.targetID, relationshipType: .inspiredBy) }

        return (MovieGraph(nodes: nodes, edges: edges), reasons)
    }

    private func normalizeNodeID(title: String) -> String {
        return "node:" + title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview("Blade Runner") {
    NavigationStack {
        MovieNetworkGraphDetailView(movie: Movie(
            title: "Blade Runner",
            imageURL: nil,
            showtimes: []
        ))
    }
}

#Preview("2001: A Space Odyssey") {
    NavigationStack {
        MovieNetworkGraphDetailView(movie: Movie(
            title: "2001: A Space Odyssey",
            imageURL: nil,
            showtimes: []
        ))
    }
}

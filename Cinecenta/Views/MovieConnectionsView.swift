import SwiftUI

/// View displaying movie connections
struct MovieConnectionsView: View {
    let movie: Movie
    @State private var graph: MovieGraph = .empty
    @State private var isLoading = true
    @State private var dataSource: DataSource = .none
    @State private var connectionReasons: [String: String] = [:]

    private let curatedService = CuratedConnectionsService()
    private let wikidataService = WikidataService()
    private let foundationModelService = FoundationModelService()

    enum DataSource {
        case none
        case curated
        case wikidata
        case foundationModels

        var displayName: String {
            switch self {
            case .none: return ""
            case .curated: return "Curated"
            case .wikidata: return "Wikidata"
            case .foundationModels: return "AI Generated"
            }
        }

        var icon: String {
            switch self {
            case .none: return ""
            case .curated: return "checkmark.seal.fill"
            case .wikidata: return "globe"
            case .foundationModels: return "sparkles"
            }
        }
    }

    /// Edges where the source movie was influenced BY another film
    /// (edges pointing TO the source movie)
    private var influencedByEdges: [MovieEdge] {
        graph.edges.filter { edge in
            let sourceNode = graph.nodes.first { $0.id == edge.sourceID }
            let targetNode = graph.nodes.first { $0.id == edge.targetID }
            // Source is NOT the main movie, but target IS the main movie
            return sourceNode?.isSourceMovie == false && targetNode?.isSourceMovie == true
        }
    }

    /// Edges where the source movie influenced another film
    /// (edges pointing FROM the source movie)
    private var influencedEdges: [MovieEdge] {
        graph.edges.filter { edge in
            let sourceNode = graph.nodes.first { $0.id == edge.sourceID }
            let targetNode = graph.nodes.first { $0.id == edge.targetID }
            // Source IS the main movie, and target is NOT the main movie
            return sourceNode?.isSourceMovie == true && targetNode?.isSourceMovie == false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Movie Connections")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                if !isLoading && dataSource != .none {
                    dataSourceBadge
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if graph.isEmpty && !isLoading {
                noConnectionsView
            } else if !graph.isEmpty {
                // Network graph visualization
                MovieNetworkGraphView(
                    graph: graph,
                    connectionReasons: connectionReasons
                )

                // List view
                connectionsList
            }
        }
        .task {
            await loadConnections()
        }
    }

    private var dataSourceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: dataSource.icon)
                .font(.caption2)
            Text(dataSource.displayName)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(dataSource == .curated ? Color.green.opacity(0.2) : Color.secondary.opacity(0.2))
        .foregroundStyle(dataSource == .curated ? .green : .secondary)
        .clipShape(Capsule())
    }

    private var noConnectionsView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "link.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No known connections")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var connectionsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Influenced By section
            if !influencedByEdges.isEmpty {
                connectionSection(
                    title: "Influenced By",
                    icon: "arrow.down.left",
                    edges: influencedByEdges,
                    isIncoming: true
                )
            }

            // Influenced section
            if !influencedEdges.isEmpty {
                connectionSection(
                    title: "Influenced",
                    icon: "arrow.up.right",
                    edges: influencedEdges,
                    isIncoming: false
                )
            }
        }
    }

    private func connectionSection(title: String, icon: String, edges: [MovieEdge], isIncoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(edges) { edge in
                    if isIncoming {
                        if let sourceNode = graph.nodes.first(where: { $0.id == edge.sourceID && !$0.isSourceMovie }) {
                            connectionRow(edge: edge, targetNode: sourceNode, incoming: true)
                        }
                    } else {
                        if let targetNode = graph.nodes.first(where: { $0.id == edge.targetID && !$0.isSourceMovie }) {
                            connectionRow(edge: edge, targetNode: targetNode)
                        }
                    }
                }
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func connectionRow(edge: MovieEdge, targetNode: MovieNode, incoming: Bool = false) -> some View {
        NavigationLink {
            ConnectedMovieDetailView(
                movieTitle: targetNode.title,
                movieYear: targetNode.year
            )
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: edge.relationshipType.icon)
                        .foregroundStyle(relationshipColor(for: edge.relationshipType))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(targetNode.title)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if let year = targetNode.year {
                                Text("(\(String(year)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }

                // Show reason if available (for curated data)
                if let reason = connectionReasons[targetNode.title] {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 32)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func relationshipColor(for type: MovieConnection.RelationshipType) -> Color {
        switch type {
        case .inspiredBy: return .yellow
        case .basedOn: return .purple
        case .remake: return .red
        case .sequel, .prequel: return .green
        case .spinOff: return .cyan
        }
    }

    private func loadConnections() async {
        // Extract year from TMDb info if available
        let year: Int? = movie.tmdbInfo.flatMap { info -> Int? in
            guard let releaseDate = info.releaseDate else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: releaseDate) else { return nil }
            return Calendar.current.component(.year, from: date)
        }

        // 1. Try curated database first (best quality data) with recursive loading
        let initialGraph = await curatedService.fetchConnections(for: movie.displayTitle)
        if !initialGraph.isEmpty {
            let (recursiveGraph, reasons) = await loadConnectionsRecursively(
                startingFrom: movie.displayTitle,
                maxDepth: 2
            )

            await MainActor.run {
                self.graph = recursiveGraph
                self.connectionReasons = reasons
                self.dataSource = .curated
                self.isLoading = false
            }
            return
        }

        // 2. Try Foundation Models (iOS 26.0+)
        if await foundationModelService.isAvailable {
            let fmGraph = await foundationModelService.fetchMovieGraph(
                for: movie.displayTitle,
                year: year,
                imdbID: movie.tmdbInfo?.imdbID
            )

            if !fmGraph.isEmpty {
                await MainActor.run {
                    self.graph = fmGraph
                    self.dataSource = .foundationModels
                    self.isLoading = false
                }
                return
            }
        }

        // 3. Fall back to Wikidata if we have an IMDb ID
        if let imdbID = movie.tmdbInfo?.imdbID {
            let wikidataGraph = await wikidataService.fetchMovieConnections(
                imdbID: imdbID,
                movieTitle: movie.displayTitle
            )

            await MainActor.run {
                self.graph = wikidataGraph
                self.dataSource = wikidataGraph.isEmpty ? .none : .wikidata
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.isLoading = false
            }
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

// MARK: - Expanded Detail View

/// Full-screen view for exploring movie connections in detail
struct MovieConnectionsDetailView: View {
    let movie: Movie
    @State private var graph: MovieGraph = .empty
    @State private var isLoading = true
    @State private var dataSource: MovieConnectionsView.DataSource = .none
    @State private var connectionReasons: [String: String] = [:]
    @State private var viewMode: ViewMode = .graph

    private let curatedService = CuratedConnectionsService()
    private let wikidataService = WikidataService()
    private let foundationModelService = FoundationModelService()

    enum ViewMode: String, CaseIterable {
        case graph = "Graph"
        case list = "List"

        var icon: String {
            switch self {
            case .graph: return "circle.grid.cross"
            case .list: return "list.bullet"
            }
        }
    }

    /// Edges where the source movie was influenced BY another film
    /// (edges pointing TO the source movie)
    private var influencedByEdges: [MovieEdge] {
        graph.edges.filter { edge in
            let sourceNode = graph.nodes.first { $0.id == edge.sourceID }
            let targetNode = graph.nodes.first { $0.id == edge.targetID }
            // Source is NOT the main movie, but target IS the main movie
            return sourceNode?.isSourceMovie == false && targetNode?.isSourceMovie == true
        }
    }

    /// Edges where the source movie influenced another film
    /// (edges pointing FROM the source movie)
    private var influencedEdges: [MovieEdge] {
        graph.edges.filter { edge in
            let sourceNode = graph.nodes.first { $0.id == edge.sourceID }
            let targetNode = graph.nodes.first { $0.id == edge.targetID }
            // Source IS the main movie, and target is NOT the main movie
            return sourceNode?.isSourceMovie == true && targetNode?.isSourceMovie == false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if graph.isEmpty && !isLoading {
                ContentUnavailableView {
                    Label("No Connections Found", systemImage: "link.badge.plus")
                } description: {
                    Text("No movie connections were found for this film.")
                }
            } else if !graph.isEmpty {
                // View mode picker
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if viewMode == .graph {
                    // Full screen graph view
                    MovieNetworkGraphDetailView(movie: movie)
                } else {
                    // List view
                    ScrollView {
                        connectionsListSection
                            .padding()
                    }
                }
            }
        }
        .navigationTitle("Movie Connections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isLoading && dataSource != .none {
                ToolbarItem(placement: .navigationBarTrailing) {
                    dataSourceBadge
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView("Loading connections...")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            await loadConnections()
        }
    }

    private var dataSourceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: dataSource.icon)
                .font(.caption2)
            Text(dataSource.displayName)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(dataSource == .curated ? Color.green.opacity(0.2) : Color.secondary.opacity(0.2))
        .foregroundStyle(dataSource == .curated ? .green : .secondary)
        .clipShape(Capsule())
    }

    private var connectionsListSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Influenced By section
            if !influencedByEdges.isEmpty {
                connectionSection(
                    title: "Influenced By",
                    subtitle: "Films that inspired \(movie.displayTitle)",
                    icon: "arrow.down.left",
                    edges: influencedByEdges,
                    isIncoming: true
                )
            }

            // Influenced section
            if !influencedEdges.isEmpty {
                connectionSection(
                    title: "Influenced",
                    subtitle: "Films inspired by \(movie.displayTitle)",
                    icon: "arrow.up.right",
                    edges: influencedEdges,
                    isIncoming: false
                )
            }
        }
    }

    private func connectionSection(title: String, subtitle: String, icon: String, edges: [MovieEdge], isIncoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.headline)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(edges) { edge in
                if isIncoming {
                    if let sourceNode = graph.nodes.first(where: { $0.id == edge.sourceID && !$0.isSourceMovie }) {
                        connectionDetailRow(for: edge, node: sourceNode)
                    }
                } else {
                    if let targetNode = graph.nodes.first(where: { $0.id == edge.targetID && !$0.isSourceMovie }) {
                        connectionDetailRow(for: edge, node: targetNode)
                    }
                }
            }
        }
    }

    private func connectionDetailRow(for edge: MovieEdge, node: MovieNode) -> some View {
        NavigationLink {
            ConnectedMovieDetailView(
                movieTitle: node.title,
                movieYear: node.year
            )
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: edge.relationshipType.icon)
                        .foregroundStyle(relationshipColor(for: edge.relationshipType))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(node.title)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if let year = node.year {
                                Text("(\(String(year)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }

                // Show reason if available
                if let reason = connectionReasons[node.title] {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 36)
                }
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func relationshipColor(for type: MovieConnection.RelationshipType) -> Color {
        switch type {
        case .inspiredBy: return .yellow
        case .basedOn: return .purple
        case .remake: return .red
        case .sequel, .prequel: return .green
        case .spinOff: return .cyan
        }
    }

    private func loadConnections() async {
        // Extract year from TMDb info if available
        let year: Int? = movie.tmdbInfo.flatMap { info -> Int? in
            guard let releaseDate = info.releaseDate else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: releaseDate) else { return nil }
            return Calendar.current.component(.year, from: date)
        }

        // 1. Try curated database first (best quality data)
        let curatedGraph = await curatedService.fetchConnections(for: movie.displayTitle)
        if !curatedGraph.isEmpty {
            // Fetch reasons for each connection
            var reasons: [String: String] = [:]
            for node in curatedGraph.nodes where !node.isSourceMovie {
                if let reason = await curatedService.getConnectionReason(
                    for: movie.displayTitle,
                    connectedTo: node.title
                ) {
                    reasons[node.title] = reason
                }
            }

            await MainActor.run {
                self.graph = curatedGraph
                self.connectionReasons = reasons
                self.dataSource = .curated
                self.isLoading = false
            }
            return
        }

        // 2. Try Foundation Models (iOS 26.0+)
        if await foundationModelService.isAvailable {
            let fmGraph = await foundationModelService.fetchMovieGraph(
                for: movie.displayTitle,
                year: year,
                imdbID: movie.tmdbInfo?.imdbID
            )

            if !fmGraph.isEmpty {
                await MainActor.run {
                    self.graph = fmGraph
                    self.dataSource = .foundationModels
                    self.isLoading = false
                }
                return
            }
        }

        // 3. Fall back to Wikidata if we have an IMDb ID
        if let imdbID = movie.tmdbInfo?.imdbID {
            let wikidataGraph = await wikidataService.fetchMovieConnections(
                imdbID: imdbID,
                movieTitle: movie.displayTitle
            )

            await MainActor.run {
                self.graph = wikidataGraph
                self.dataSource = wikidataGraph.isEmpty ? .none : .wikidata
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Compact Preview for MovieDetailView

/// A compact preview of movie connections for the MovieDetailView
/// Tapping navigates to the full MovieConnectionsDetailView
struct MovieConnectionsPreview: View {
    let movie: Movie
    @State private var connectionCount: Int = 0
    @State private var isLoading = true
    @State private var dataSource: MovieConnectionsView.DataSource = .none

    private let curatedService = CuratedConnectionsService()
    private let foundationModelService = FoundationModelService()
    private let wikidataService = WikidataService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Movie Connections")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                if !isLoading && dataSource != .none {
                    dataSourceBadge
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 20)
                    Spacer()
                }
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if connectionCount == 0 {
                noConnectionsView
            } else {
                connectionSummaryView
            }
        }
        .task {
            await loadConnectionCount()
        }
    }

    private var dataSourceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: dataSource.icon)
                .font(.caption2)
            Text(dataSource.displayName)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(dataSource == .curated ? Color.green.opacity(0.2) : Color.secondary.opacity(0.2))
        .foregroundStyle(dataSource == .curated ? .green : .secondary)
        .clipShape(Capsule())
    }

    private var noConnectionsView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "link.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No known connections")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var connectionSummaryView: some View {
        HStack(spacing: 16) {
            // Connection icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: "link")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(connectionCount) \(connectionCount == 1 ? "Connection" : "Connections")")
                    .font(.headline)

                Text("Tap to explore film influences")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadConnectionCount() async {
        // Extract year from TMDb info if available
        let year: Int? = movie.tmdbInfo.flatMap { info -> Int? in
            guard let releaseDate = info.releaseDate else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: releaseDate) else { return nil }
            return Calendar.current.component(.year, from: date)
        }

        // 1. Try curated database first
        let curatedGraph = await curatedService.fetchConnections(for: movie.displayTitle)
        if !curatedGraph.isEmpty {
            await MainActor.run {
                self.connectionCount = curatedGraph.nodes.count - 1 // Exclude the source movie
                self.dataSource = .curated
                self.isLoading = false
            }
            return
        }

        // 2. Try Foundation Models (iOS 26.0+)
        if await foundationModelService.isAvailable {
            let fmGraph = await foundationModelService.fetchMovieGraph(
                for: movie.displayTitle,
                year: year,
                imdbID: movie.tmdbInfo?.imdbID
            )

            if !fmGraph.isEmpty {
                await MainActor.run {
                    self.connectionCount = fmGraph.nodes.count - 1
                    self.dataSource = .foundationModels
                    self.isLoading = false
                }
                return
            }
        }

        // 3. Fall back to Wikidata
        if let imdbID = movie.tmdbInfo?.imdbID {
            let wikidataGraph = await wikidataService.fetchMovieConnections(
                imdbID: imdbID,
                movieTitle: movie.displayTitle
            )

            await MainActor.run {
                self.connectionCount = max(0, wikidataGraph.nodes.count - 1)
                self.dataSource = wikidataGraph.isEmpty ? .none : .wikidata
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        MovieConnectionsDetailView(movie: Movie(
            title: "Star Wars",
            imageURL: nil,
            showtimes: []
        ))
    }
}

#Preview("Connections Preview") {
    NavigationStack {
        MovieConnectionsPreview(movie: Movie(
            title: "Blade Runner",
            imageURL: nil,
            showtimes: []
        ))
        .padding()
    }
}

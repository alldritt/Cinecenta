import Foundation

// MARK: - Curated Database Models

struct CuratedDatabase: Codable {
    let version: Int
    let lastUpdated: String
    let films: [String: CuratedFilm]
}

struct CuratedFilm: Codable {
    let year: Int
    let director: String
    let influencedBy: [CuratedConnection]
    let influenced: [CuratedConnection]
}

struct CuratedConnection: Codable {
    let title: String
    let year: Int
    let reason: String
}

// MARK: - Curated Connections Service

/// Service for loading and querying the curated movie connections database
actor CuratedConnectionsService {
    private var database: CuratedDatabase?
    private var isLoaded = false

    /// Load the curated database from the app bundle
    func loadDatabase() async {
        guard !isLoaded else { return }

        guard let url = Bundle.main.url(forResource: "CuratedMovieConnections", withExtension: "json") else {
            print("CuratedConnectionsService: Could not find CuratedMovieConnections.json in bundle")
            isLoaded = true
            return
        }

        do {
            let data = try Data(contentsOf: url)
            database = try JSONDecoder().decode(CuratedDatabase.self, from: data)
            print("CuratedConnectionsService: Loaded \(database?.films.count ?? 0) films")
        } catch {
            print("CuratedConnectionsService: Failed to load database: \(error)")
        }

        isLoaded = true
    }

    /// Fetch connections for a movie by title
    /// Uses fuzzy matching to handle slight title variations
    func fetchConnections(for movieTitle: String) async -> MovieGraph {
        await loadDatabase()

        guard let database = database else {
            return .empty
        }

        // Try exact match first
        if let film = database.films[movieTitle] {
            return buildGraph(for: movieTitle, film: film)
        }

        // Try case-insensitive match
        let normalizedTitle = movieTitle.lowercased()
        for (title, film) in database.films {
            if title.lowercased() == normalizedTitle {
                return buildGraph(for: title, film: film)
            }
        }

        // Try matching without articles
        let withoutArticles = normalizedTitle
            .replacingOccurrences(of: "^the ", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^a ", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^an ", with: "", options: .regularExpression)

        for (title, film) in database.films {
            let titleWithoutArticles = title.lowercased()
                .replacingOccurrences(of: "^the ", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^a ", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^an ", with: "", options: .regularExpression)

            if titleWithoutArticles == withoutArticles {
                return buildGraph(for: title, film: film)
            }
        }

        return .empty
    }

    /// Check if we have curated data for a given movie
    func hasData(for movieTitle: String) async -> Bool {
        let graph = await fetchConnections(for: movieTitle)
        return !graph.isEmpty
    }

    /// Build a MovieGraph from curated film data
    private func buildGraph(for movieTitle: String, film: CuratedFilm) -> MovieGraph {
        var nodes: [MovieNode] = []
        var edges: [MovieEdge] = []

        // Add source movie node
        let sourceID = "curated:\(movieTitle)"
        nodes.append(MovieNode(
            id: sourceID,
            title: movieTitle,
            year: film.year,
            isSourceMovie: true
        ))

        // Add "influenced by" connections (films that influenced this one)
        for (index, connection) in film.influencedBy.enumerated() {
            let nodeID = "curated:influencer:\(index):\(connection.title)"

            nodes.append(MovieNode(
                id: nodeID,
                title: connection.title,
                year: connection.year,
                isSourceMovie: false
            ))

            // Edge goes from influencer -> this film
            edges.append(MovieEdge(
                sourceID: nodeID,
                targetID: sourceID,
                relationshipType: .inspiredBy
            ))
        }

        // Add "influenced" connections (films this one influenced)
        for (index, connection) in film.influenced.enumerated() {
            let nodeID = "curated:influenced:\(index):\(connection.title)"

            nodes.append(MovieNode(
                id: nodeID,
                title: connection.title,
                year: connection.year,
                isSourceMovie: false
            ))

            // Edge goes from this film -> influenced film
            edges.append(MovieEdge(
                sourceID: sourceID,
                targetID: nodeID,
                relationshipType: .inspiredBy
            ))
        }

        return MovieGraph(nodes: nodes, edges: edges)
    }

    /// Get the reason for a specific connection
    func getConnectionReason(for movieTitle: String, connectedTo: String) async -> String? {
        await loadDatabase()

        guard let database = database,
              let film = findFilm(titled: movieTitle, in: database) else {
            return nil
        }

        // Check influenced by
        if let connection = film.influencedBy.first(where: { $0.title.lowercased() == connectedTo.lowercased() }) {
            return connection.reason
        }

        // Check influenced
        if let connection = film.influenced.first(where: { $0.title.lowercased() == connectedTo.lowercased() }) {
            return connection.reason
        }

        return nil
    }

    private func findFilm(titled movieTitle: String, in database: CuratedDatabase) -> CuratedFilm? {
        // Exact match
        if let film = database.films[movieTitle] {
            return film
        }

        // Case-insensitive
        let normalizedTitle = movieTitle.lowercased()
        for (title, film) in database.films {
            if title.lowercased() == normalizedTitle {
                return film
            }
        }

        return nil
    }

    /// Get all available film titles in the database
    func availableFilms() async -> [String] {
        await loadDatabase()
        return database?.films.keys.sorted() ?? []
    }
}

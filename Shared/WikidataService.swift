import Foundation

// MARK: - Movie Connection Models

/// Represents a connection between two movies
struct MovieConnection: Identifiable, Hashable {
    let id: String
    let sourceTitle: String
    let targetTitle: String
    let relationshipType: RelationshipType
    let targetWikidataID: String

    enum RelationshipType: String, CaseIterable {
        case inspiredBy = "inspired by"
        case basedOn = "based on"
        case remake = "remake of"
        case sequel = "sequel to"
        case prequel = "prequel to"
        case spinOff = "spin-off of"

        var displayName: String {
            rawValue
        }

        var icon: String {
            switch self {
            case .inspiredBy: return "lightbulb"
            case .basedOn: return "book"
            case .remake: return "arrow.2.squarepath"
            case .sequel: return "arrow.right"
            case .prequel: return "arrow.left"
            case .spinOff: return "arrow.branch"
            }
        }
    }
}

/// A node in the movie relationship graph
struct MovieNode: Identifiable, Hashable {
    let id: String  // Wikidata ID
    let title: String
    let year: Int?
    let isSourceMovie: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MovieNode, rhs: MovieNode) -> Bool {
        lhs.id == rhs.id
    }
}

/// Edge in the movie relationship graph
struct MovieEdge: Identifiable, Hashable {
    let id: String
    let sourceID: String
    let targetID: String
    let relationshipType: MovieConnection.RelationshipType

    init(sourceID: String, targetID: String, relationshipType: MovieConnection.RelationshipType) {
        self.id = "\(sourceID)-\(targetID)-\(relationshipType.rawValue)"
        self.sourceID = sourceID
        self.targetID = targetID
        self.relationshipType = relationshipType
    }
}

/// Complete graph of movie relationships
struct MovieGraph {
    var nodes: [MovieNode]
    var edges: [MovieEdge]

    var isEmpty: Bool {
        edges.isEmpty
    }

    static let empty = MovieGraph(nodes: [], edges: [])
}

// MARK: - Wikidata Service

/// Service for querying Wikidata SPARQL endpoint for movie relationships
actor WikidataService {
    private let sparqlEndpoint = URL(string: "https://query.wikidata.org/sparql")!
    private var cache: [String: MovieGraph] = [:]

    /// Increment this when the SPARQL query changes to invalidate cached results
    private static let queryVersion = 2
    private static let queryVersionKey = "wikidata_query_version"

    init() {
        // Clear cache if query version changed
        let storedVersion = UserDefaults.standard.integer(forKey: Self.queryVersionKey)
        if storedVersion != Self.queryVersion {
            UserDefaults.standard.set(Self.queryVersion, forKey: Self.queryVersionKey)
            // Cache is in-memory only, so just starting fresh is fine
        }
    }

    /// Fetches movie relationships from Wikidata using IMDb ID
    func fetchMovieConnections(imdbID: String, movieTitle: String) async -> MovieGraph {
        // Check cache first
        if let cached = cache[imdbID] {
            return cached
        }

        // Query for the Wikidata entity using IMDb ID, then get relationships
        let query = buildSPARQLQuery(imdbID: imdbID)

        guard let results = await executeSPARQLQuery(query) else {
            return .empty
        }

        let graph = parseResults(results, sourceTitle: movieTitle, sourceImdbID: imdbID)
        cache[imdbID] = graph
        return graph
    }

    /// Builds SPARQL query to find movie relationships
    private func buildSPARQLQuery(imdbID: String) -> String {
        // Query finds the movie by IMDb ID, then gets relationships via multiple properties:
        // - P941: inspired by (specific creative inspiration)
        // - P737: influenced by (broader influence)
        // - P144: based on (adaptations)
        // - P4969: derivative work
        // Plus inverse relationships for films influenced BY this one
        """
        SELECT DISTINCT ?relation ?relationType ?relatedFilm ?relatedFilmLabel ?relatedYear WHERE {
          # Find the source film by IMDb ID
          ?sourceFilm wdt:P345 "\(imdbID)" .

          {
            # P941 - Films this movie was inspired by
            ?sourceFilm wdt:P941 ?relatedFilm .
            BIND("inspired_by" AS ?relationType)
            BIND("outgoing" AS ?relation)
          } UNION {
            # P737 - Films this movie was influenced by (broader)
            ?sourceFilm wdt:P737 ?relatedFilm .
            ?relatedFilm wdt:P31/wdt:P279* wd:Q11424 .
            BIND("inspired_by" AS ?relationType)
            BIND("outgoing" AS ?relation)
          } UNION {
            # P144 - Works this movie is based on (filter to films)
            ?sourceFilm wdt:P144 ?relatedFilm .
            ?relatedFilm wdt:P31/wdt:P279* wd:Q11424 .
            BIND("based_on" AS ?relationType)
            BIND("outgoing" AS ?relation)
          } UNION {
            # P941 inverse - Films inspired by this movie
            ?relatedFilm wdt:P941 ?sourceFilm .
            ?relatedFilm wdt:P31/wdt:P279* wd:Q11424 .
            BIND("inspired_by" AS ?relationType)
            BIND("incoming" AS ?relation)
          } UNION {
            # P737 inverse - Films influenced by this movie (broader)
            ?relatedFilm wdt:P737 ?sourceFilm .
            ?relatedFilm wdt:P31/wdt:P279* wd:Q11424 .
            BIND("inspired_by" AS ?relationType)
            BIND("incoming" AS ?relation)
          } UNION {
            # P144 inverse - Remakes/adaptations of this movie
            ?relatedFilm wdt:P144 ?sourceFilm .
            ?relatedFilm wdt:P31/wdt:P279* wd:Q11424 .
            BIND("remake_of" AS ?relationType)
            BIND("incoming" AS ?relation)
          } UNION {
            # P4969 - Derivative works of this movie
            ?relatedFilm wdt:P4969 ?sourceFilm .
            ?relatedFilm wdt:P31/wdt:P279* wd:Q11424 .
            BIND("remake_of" AS ?relationType)
            BIND("incoming" AS ?relation)
          }

          # Get publication year if available
          OPTIONAL { ?relatedFilm wdt:P577 ?pubDate . }
          BIND(YEAR(?pubDate) AS ?relatedYear)

          SERVICE wikibase:label { bd:serviceParam wikibase:language "en" . }
        }
        ORDER BY ?relationType ?relatedYear
        LIMIT 50
        """
    }

    /// Executes SPARQL query against Wikidata endpoint
    private func executeSPARQLQuery(_ query: String) async -> [[String: Any]]? {
        var components = URLComponents(url: sparqlEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CinecentaApp/1.0 (iOS Movie Schedule App)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [String: Any],
                  let bindings = results["bindings"] as? [[String: Any]] else {
                return nil
            }

            return bindings
        } catch {
            print("Wikidata query error: \(error)")
            return nil
        }
    }

    /// Parses SPARQL results into a MovieGraph
    private func parseResults(_ bindings: [[String: Any]], sourceTitle: String, sourceImdbID: String) -> MovieGraph {
        var nodes: [String: MovieNode] = [:]
        var edges: [MovieEdge] = []

        // Add source movie as a node
        let sourceID = "imdb:\(sourceImdbID)"
        nodes[sourceID] = MovieNode(id: sourceID, title: sourceTitle, year: nil, isSourceMovie: true)

        for binding in bindings {
            guard let relatedFilmValue = binding["relatedFilm"] as? [String: Any],
                  let relatedFilmURI = relatedFilmValue["value"] as? String,
                  let relationTypeValue = binding["relationType"] as? [String: Any],
                  let relationTypeStr = relationTypeValue["value"] as? String,
                  let relationValue = binding["relation"] as? [String: Any],
                  let relationDirection = relationValue["value"] as? String else {
                continue
            }

            // Extract Wikidata ID from URI
            let wikidataID = relatedFilmURI.replacingOccurrences(of: "http://www.wikidata.org/entity/", with: "")

            // Get label
            let labelValue = binding["relatedFilmLabel"] as? [String: Any]
            let label = labelValue?["value"] as? String ?? wikidataID

            // Get year
            let yearValue = binding["relatedYear"] as? [String: Any]
            let yearStr = yearValue?["value"] as? String
            let year = yearStr.flatMap { Int($0) }

            // Add node if not exists
            if nodes[wikidataID] == nil {
                nodes[wikidataID] = MovieNode(id: wikidataID, title: label, year: year, isSourceMovie: false)
            }

            // Determine relationship type and direction
            let relationshipType: MovieConnection.RelationshipType
            switch relationTypeStr {
            case "inspired_by":
                relationshipType = .inspiredBy
            case "based_on":
                relationshipType = .basedOn
            case "remake_of":
                relationshipType = .remake
            default:
                continue
            }

            // Create edge based on direction
            let edge: MovieEdge
            if relationDirection == "outgoing" {
                // Source movie -> related film
                edge = MovieEdge(sourceID: sourceID, targetID: wikidataID, relationshipType: relationshipType)
            } else {
                // Related film -> source movie
                edge = MovieEdge(sourceID: wikidataID, targetID: sourceID, relationshipType: relationshipType)
            }

            // Avoid duplicate edges
            if !edges.contains(where: { $0.id == edge.id }) {
                edges.append(edge)
            }
        }

        return MovieGraph(nodes: Array(nodes.values), edges: edges)
    }

    /// Clears the cache
    func clearCache() {
        cache.removeAll()
    }
}

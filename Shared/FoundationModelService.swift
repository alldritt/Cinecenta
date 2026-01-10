import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Response Models

/// A single film connection returned by the model
struct FilmConnectionResult: Codable, Hashable {
    let title: String
    let year: Int?
    let relationship: String  // "influenced_by" or "influenced"
    let reason: String
}

/// Response containing all connections for a film
struct FilmConnectionsResponse: Codable {
    let connections: [FilmConnectionResult]
}

// MARK: - Persistent Cache Models

/// Structure for persisting Foundation Model results to disk
struct FoundationModelCache: Codable {
    let version: Int
    let entries: [String: FoundationModelCacheEntry]

    static let currentVersion = 1
}

struct FoundationModelCacheEntry: Codable {
    let connections: [FilmConnectionResult]
    let timestamp: Date

    /// Cache entries expire after 30 days
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 30 * 24 * 60 * 60
    }
}

// MARK: - Foundation Model Service

/// Service for querying Apple's on-device Foundation Models for movie connections
actor FoundationModelService {
    private var memoryCache: [String: [FilmConnectionResult]] = [:]
    private var diskCacheLoaded = false

    private let fileManager = FileManager.default
    private let cacheFileName = "foundation_model_cache.json"

    private var cacheURL: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(cacheFileName)
    }

    /// Check if Foundation Models are available on this device
    var isAvailable: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    /// Load disk cache into memory
    private func loadDiskCache() async {
        guard !diskCacheLoaded else { return }
        diskCacheLoaded = true

        guard let url = cacheURL,
              fileManager.fileExists(atPath: url.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let cache = try JSONDecoder().decode(FoundationModelCache.self, from: data)

            // Check version compatibility
            guard cache.version == FoundationModelCache.currentVersion else {
                try? fileManager.removeItem(at: url)
                return
            }

            // Load non-expired entries into memory
            for (key, entry) in cache.entries where !entry.isExpired {
                memoryCache[key] = entry.connections
            }

            print("FoundationModelService: Loaded \(memoryCache.count) cached entries from disk")
        } catch {
            print("FoundationModelService: Failed to load disk cache: \(error)")
        }
    }

    /// Save memory cache to disk
    private func saveDiskCache() {
        guard let url = cacheURL else { return }

        let entries = memoryCache.mapValues { connections in
            FoundationModelCacheEntry(connections: connections, timestamp: Date())
        }

        let cache = FoundationModelCache(version: FoundationModelCache.currentVersion, entries: entries)

        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: url, options: .atomic)
        } catch {
            print("FoundationModelService: Failed to save disk cache: \(error)")
        }
    }

    /// Fetch movie connections using Apple's Foundation Models
    func fetchConnections(for movieTitle: String, year: Int?) async -> [FilmConnectionResult] {
        // Load disk cache if not already loaded
        await loadDiskCache()

        // Check memory cache first
        let cacheKey = "\(movieTitle.lowercased())|\(year ?? 0)"
        if let cached = memoryCache[cacheKey] {
            return cached
        }

        // Query the model
        let results = await queryFoundationModel(movieTitle: movieTitle, year: year)

        // Cache results (both memory and disk)
        if !results.isEmpty {
            memoryCache[cacheKey] = results
            saveDiskCache()
        }

        return results
    }

    private func queryFoundationModel(movieTitle: String, year: Int?) async -> [FilmConnectionResult] {
        guard #available(iOS 26.0, *) else {
            return []
        }

        #if canImport(FoundationModels)
        do {
            let yearStr = year.map { " (\($0))" } ?? ""
            let prompt = """
            For the film "\(movieTitle)"\(yearStr), provide factual information about:
            1. Films that directly influenced or inspired it (if known)
            2. Notable films that were influenced by it or contain clear homages to it

            Only include well-documented connections that are commonly discussed in film criticism.
            Do not make up connections. If you're not sure, don't include it.

            Respond with a JSON object in this exact format:
            {
              "connections": [
                {
                  "title": "Film Title",
                  "year": 1968,
                  "relationship": "influenced_by",
                  "reason": "Brief explanation of the connection"
                }
              ]
            }

            Use "influenced_by" for films that influenced \(movieTitle).
            Use "influenced" for films that \(movieTitle) influenced.
            Limit to 10 most significant connections.
            """

            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)

            // Parse the JSON response
            return parseModelResponse(response.content)
        } catch {
            print("Foundation Model error: \(error)")
            return []
        }
        #else
        return []
        #endif
    }

    private func parseModelResponse(_ content: String) -> [FilmConnectionResult] {
        // Try to extract JSON from the response
        // The model might include markdown code blocks
        var jsonString = content

        // Remove markdown code blocks if present
        if let startRange = jsonString.range(of: "```json") {
            jsonString = String(jsonString[startRange.upperBound...])
        } else if let startRange = jsonString.range(of: "```") {
            jsonString = String(jsonString[startRange.upperBound...])
        }

        if let endRange = jsonString.range(of: "```") {
            jsonString = String(jsonString[..<endRange.lowerBound])
        }

        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse JSON
        guard let data = jsonString.data(using: .utf8) else {
            return []
        }

        do {
            let response = try JSONDecoder().decode(FilmConnectionsResponse.self, from: data)
            return response.connections
        } catch {
            print("JSON parsing error: \(error)")
            // Try to find JSON object in the string
            if let start = jsonString.firstIndex(of: "{"),
               let end = jsonString.lastIndex(of: "}") {
                let extracted = String(jsonString[start...end])
                if let extractedData = extracted.data(using: .utf8),
                   let response = try? JSONDecoder().decode(FilmConnectionsResponse.self, from: extractedData) {
                    return response.connections
                }
            }
            return []
        }
    }

    /// Clear both memory and disk caches
    func clearCache() {
        memoryCache.removeAll()
        diskCacheLoaded = false

        // Also clear disk cache
        if let url = cacheURL {
            try? fileManager.removeItem(at: url)
        }
    }
}

// MARK: - Integration with MovieGraph

extension FoundationModelService {
    /// Convert Foundation Model results to MovieGraph format
    func fetchMovieGraph(for movieTitle: String, year: Int?, imdbID: String?) async -> MovieGraph {
        let connections = await fetchConnections(for: movieTitle, year: year)

        guard !connections.isEmpty else {
            return .empty
        }

        // Create source node
        let sourceID = imdbID ?? "source:\(movieTitle)"
        var nodes: [MovieNode] = [
            MovieNode(id: sourceID, title: movieTitle, year: year, isSourceMovie: true)
        ]
        var edges: [MovieEdge] = []

        // Create nodes and edges for each connection
        for (index, connection) in connections.enumerated() {
            let nodeID = "fm:\(index):\(connection.title)"

            nodes.append(MovieNode(
                id: nodeID,
                title: connection.title,
                year: connection.year,
                isSourceMovie: false
            ))

            let relationshipType: MovieConnection.RelationshipType
            switch connection.relationship.lowercased() {
            case "influenced_by":
                relationshipType = .inspiredBy
            case "influenced":
                relationshipType = .inspiredBy
            case "based_on":
                relationshipType = .basedOn
            case "remake":
                relationshipType = .remake
            default:
                relationshipType = .inspiredBy
            }

            // Direction depends on relationship
            if connection.relationship.lowercased() == "influenced_by" {
                // This film was influenced by the connection
                edges.append(MovieEdge(
                    sourceID: nodeID,
                    targetID: sourceID,
                    relationshipType: relationshipType
                ))
            } else {
                // This film influenced the connection
                edges.append(MovieEdge(
                    sourceID: sourceID,
                    targetID: nodeID,
                    relationshipType: relationshipType
                ))
            }
        }

        return MovieGraph(nodes: nodes, edges: edges)
    }
}

import Foundation

/// Handles offline caching of movie data
actor MovieCache {
    static let shared = MovieCache()

    private let fileManager = FileManager.default
    private let cacheFileName = "cached_movies.json"

    private var cacheURL: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(cacheFileName)
    }

    /// Cached movie data structure
    struct CachedData: Codable {
        let movies: [CachedMovie]
        let timestamp: Date

        var isExpired: Bool {
            // Consider cache expired after 72 hours
            Date().timeIntervalSince(timestamp) > 72 * 60 * 60
        }

        var isStale: Bool {
            // Consider cache stale after 24 hours (should refresh if possible)
            Date().timeIntervalSince(timestamp) > 24 * 60 * 60
        }
    }

    /// Codable version of Movie for caching
    struct CachedMovie: Codable {
        let id: UUID
        let title: String
        let imageURL: URL?
        let showtimes: [CachedShowtime]

        init(from movie: Movie) {
            self.id = movie.id
            self.title = movie.title
            self.imageURL = movie.imageURL
            self.showtimes = movie.showtimes.map { CachedShowtime(from: $0) }
        }

        func toMovie() -> Movie {
            Movie(
                id: id,
                title: title,
                imageURL: imageURL,
                showtimes: showtimes.map { $0.toShowtime() }
            )
        }
    }

    /// Codable version of Showtime for caching
    struct CachedShowtime: Codable {
        let id: UUID
        let startDate: Date
        let endDate: Date?

        init(from showtime: Showtime) {
            self.id = showtime.id
            self.startDate = showtime.startDate
            self.endDate = showtime.endDate
        }

        func toShowtime() -> Showtime {
            Showtime(id: id, startDate: startDate, endDate: endDate)
        }
    }

    // MARK: - Public Methods

    /// Save movies to cache
    func save(_ movies: [Movie]) async {
        guard let url = cacheURL else { return }

        let cachedMovies = movies.map { CachedMovie(from: $0) }
        let cachedData = CachedData(movies: cachedMovies, timestamp: Date())

        do {
            let data = try JSONEncoder().encode(cachedData)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save cache: \(error)")
        }
    }

    /// Load movies from cache
    func load() async -> [Movie]? {
        guard let url = cacheURL,
              fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let cachedData = try JSONDecoder().decode(CachedData.self, from: data)

            // Don't return expired cache
            guard !cachedData.isExpired else {
                await clearCache()
                return nil
            }

            return cachedData.movies.map { $0.toMovie() }
        } catch {
            print("Failed to load cache: \(error)")
            return nil
        }
    }

    /// Check if cache exists and is not expired
    func hasFreshCache() async -> Bool {
        guard let url = cacheURL,
              fileManager.fileExists(atPath: url.path) else {
            return false
        }

        do {
            let data = try Data(contentsOf: url)
            let cachedData = try JSONDecoder().decode(CachedData.self, from: data)
            return !cachedData.isStale
        } catch {
            return false
        }
    }

    /// Get cache timestamp
    func cacheTimestamp() async -> Date? {
        guard let url = cacheURL,
              fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let cachedData = try JSONDecoder().decode(CachedData.self, from: data)
            return cachedData.timestamp
        } catch {
            return nil
        }
    }

    /// Clear the cache
    func clearCache() async {
        guard let url = cacheURL else { return }
        try? fileManager.removeItem(at: url)
    }
}

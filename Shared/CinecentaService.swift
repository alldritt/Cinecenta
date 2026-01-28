import Foundation

/// Errors that can occur when fetching movie data
enum CinecentaError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parsingError(String)
    case noDataFound
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .noDataFound:
            return "No movie data found on the page"
        case .offline:
            return "No internet connection and no cached data available"
        }
    }
}

/// Result indicating whether data came from network or cache
enum FetchResult {
    case fromNetwork([Movie])
    case fromCache([Movie])
}

/// Service for fetching and parsing Cinecenta movie schedules
actor CinecentaService {
    private let calendarURL = URL(string: "https://www.cinecenta.com/calendar/")!
    private let cache = MovieCache.shared

    /// Fetches movies with offline fallback - returns movies and source
    func fetchMoviesWithCache() async throws -> FetchResult {
        // Try network first
        do {
            let movies = try await fetchFromNetwork()
            // Cache successful network response
            await cache.save(movies)
            return .fromNetwork(movies)
        } catch {
            // Network failed, try cache
            if let cachedMovies = await cache.load(), !cachedMovies.isEmpty {
                return .fromCache(cachedMovies)
            }
            // No cache available, throw the original error
            throw CinecentaError.offline
        }
    }

    /// Fetches the current movie schedule from Cinecenta (with cache fallback)
    func fetchMovies() async throws -> [Movie] {
        let result = try await fetchMoviesWithCache()
        switch result {
        case .fromNetwork(let movies), .fromCache(let movies):
            return movies
        }
    }

    /// Fetches directly from network without cache
    func fetchFromNetwork() async throws -> [Movie] {
        let (data, response) = try await URLSession.shared.data(from: calendarURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CinecentaError.networkError(
                NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0)
            )
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw CinecentaError.parsingError("Could not decode HTML")
        }

        return try parseMovies(from: html)
    }

    /// Force refresh from network and update cache
    func refreshMovies() async throws -> [Movie] {
        let movies = try await fetchFromNetwork()
        await cache.save(movies)
        return movies
    }

    /// Fetches all movies playing tonight
    func fetchTonightMovies() async throws -> [Movie] {
        let movies = try await fetchMovies()
        let calendar = Calendar.current

        // Find movies with showtimes today
        let tonightMovies = movies.compactMap { movie -> Movie? in
            let tonightShowtimes = movie.showtimes.filter { calendar.isDateInToday($0.startDate) }
            guard !tonightShowtimes.isEmpty else { return nil }
            return Movie(
                id: movie.id,
                title: movie.title,
                imageURL: movie.imageURL,
                showtimes: tonightShowtimes
            )
        }

        // Sort by earliest showtime
        return tonightMovies.sorted { movie1, movie2 in
            guard let time1 = movie1.showtimes.first?.startDate,
                  let time2 = movie2.showtimes.first?.startDate else {
                return false
            }
            return time1 < time2
        }
    }

    /// Parses movies from HTML by extracting JSON-LD structured data
    private func parseMovies(from html: String) throws -> [Movie] {
        let events = extractSchemaEvents(from: html)

        guard !events.isEmpty else {
            throw CinecentaError.noDataFound
        }

        return groupEventsIntoMovies(events)
    }

    /// Extracts Schema.org Event objects from JSON-LD script tags
    private func extractSchemaEvents(from html: String) -> [SchemaEvent] {
        var events: [SchemaEvent] = []

        // Find all JSON-LD script blocks
        let pattern = #"<script[^>]*type="application/ld\+json"[^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        for match in matches {
            guard let jsonRange = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard let jsonData = jsonString.data(using: .utf8) else { continue }

            // Use the flexible parser that handles mixed @graph contents
            let parsedEvents = SchemaParser.parseEvents(from: jsonData)
            events.append(contentsOf: parsedEvents)
        }

        return events
    }

    /// Groups individual screening events into Movie objects with multiple showtimes
    private func groupEventsIntoMovies(_ events: [SchemaEvent]) -> [Movie] {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]

        var movieDict: [String: (imageURL: URL?, showtimes: [Showtime])] = [:]

        for event in events {
            guard let startDate = iso8601Formatter.date(from: event.startDate) else { continue }

            let endDate = event.endDate.flatMap { iso8601Formatter.date(from: $0) }
            let showtime = Showtime(startDate: startDate, endDate: endDate)

            let imageURL = event.imageURL.flatMap { URL(string: $0) }

            if var existing = movieDict[event.name] {
                existing.showtimes.append(showtime)
                // Keep the image URL if we didn't have one
                if existing.imageURL == nil && imageURL != nil {
                    existing.imageURL = imageURL
                }
                movieDict[event.name] = existing
            } else {
                movieDict[event.name] = (imageURL: imageURL, showtimes: [showtime])
            }
        }

        return movieDict.map { title, data in
            Movie(
                title: title,
                imageURL: data.imageURL,
                showtimes: data.showtimes.sorted { $0.startDate < $1.startDate }
            )
        }.sorted { movie1, movie2 in
            // Sort by next showtime
            guard let next1 = movie1.nextShowtime ?? movie1.showtimes.first,
                  let next2 = movie2.nextShowtime ?? movie2.showtimes.first else {
                return movie1.title < movie2.title
            }
            return next1.startDate < next2.startDate
        }
    }
}

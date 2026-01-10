import Foundation

// MARK: - TMDb Configuration

/// TMDb API configuration
enum TMDbConfig {
    /// API key for TMDb - get one free at https://www.themoviedb.org/settings/api
    /// Store this securely in production (e.g., in Keychain or environment variable)
    static let apiKey = "f443acc7d6e447fc92d25c0696ade55e"

    static let baseURL = "https://api.themoviedb.org/3"
    static let imageBaseURL = "https://image.tmdb.org/t/p"

    /// Image size configurations
    enum PosterSize: String {
        case small = "w185"
        case medium = "w342"
        case large = "w500"
        case original = "original"
    }

    enum BackdropSize: String {
        case small = "w300"
        case medium = "w780"
        case large = "w1280"
        case original = "original"
    }
}

// MARK: - TMDb API Response Models

/// Search results response
struct TMDbSearchResponse: Codable {
    let page: Int
    let results: [TMDbSearchResult]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

/// Individual search result
struct TMDbSearchResult: Codable, Identifiable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double?
    let voteCount: Int?
    let genreIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case originalTitle = "original_title"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genreIds = "genre_ids"
    }
}

/// Detailed movie response
struct TMDbMovieDetail: Codable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String?
    let tagline: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let runtime: Int?
    let voteAverage: Double?
    let voteCount: Int?
    let genres: [TMDbGenre]?
    let credits: TMDbCredits?
    let videos: TMDbVideosResponse?
    let externalIds: TMDbExternalIds?
    let watchProviders: TMDbWatchProvidersResponse?

    enum CodingKeys: String, CodingKey {
        case id, title, overview, tagline, runtime, genres, credits, videos
        case originalTitle = "original_title"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case externalIds = "external_ids"
        case watchProviders = "watch/providers"
    }
}

/// External IDs for a movie (IMDb, etc.)
struct TMDbExternalIds: Codable {
    let imdbId: String?
    let wikidataId: String?
    let facebookId: String?
    let instagramId: String?
    let twitterId: String?

    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
        case wikidataId = "wikidata_id"
        case facebookId = "facebook_id"
        case instagramId = "instagram_id"
        case twitterId = "twitter_id"
    }
}

struct TMDbGenre: Codable, Identifiable {
    let id: Int
    let name: String
}

struct TMDbCredits: Codable {
    let cast: [TMDbCastMember]?
    let crew: [TMDbCrewMember]?
}

struct TMDbCastMember: Codable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, character, order
        case profilePath = "profile_path"
    }
}

struct TMDbCrewMember: Codable, Identifiable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, job, department
        case profilePath = "profile_path"
    }
}

struct TMDbVideosResponse: Codable {
    let results: [TMDbVideo]?
}

struct TMDbVideo: Codable, Identifiable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String

    var youtubeURL: URL? {
        guard site == "YouTube" else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
}

// MARK: - Watch Providers API Response

struct TMDbWatchProvidersResponse: Codable {
    let results: [String: TMDbCountryWatchProviders]?
}

struct TMDbCountryWatchProviders: Codable {
    let link: String?
    let flatrate: [TMDbWatchProvider]?  // Streaming
    let rent: [TMDbWatchProvider]?
    let buy: [TMDbWatchProvider]?
}

struct TMDbWatchProvider: Codable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    let displayPriority: Int?

    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
        case displayPriority = "display_priority"
    }
}

// MARK: - App-Facing TMDb Data Model

/// App-facing watch provider info
struct WatchProvider: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let logoURL: URL?

    /// Common streaming service SF Symbols (fallback for when logo fails to load)
    var systemImageName: String {
        let lowercaseName = name.lowercased()
        if lowercaseName.contains("netflix") { return "play.tv" }
        if lowercaseName.contains("amazon") || lowercaseName.contains("prime") { return "play.tv" }
        if lowercaseName.contains("disney") { return "play.tv" }
        if lowercaseName.contains("apple") { return "apple.logo" }
        if lowercaseName.contains("hulu") { return "play.tv" }
        if lowercaseName.contains("hbo") || lowercaseName.contains("max") { return "play.tv" }
        if lowercaseName.contains("paramount") { return "play.tv" }
        if lowercaseName.contains("peacock") { return "play.tv" }
        if lowercaseName.contains("crave") { return "play.tv" }
        return "tv"
    }

    /// URL scheme to check if the streaming app is installed
    var appURLScheme: String? {
        let lowercaseName = name.lowercased()

        // Map provider names to their app URL schemes
        if lowercaseName.contains("netflix") { return "nflx://" }
        if lowercaseName.contains("amazon") || lowercaseName.contains("prime video") { return "primevideo://" }
        if lowercaseName.contains("disney") { return "disneyplus://" }
        if lowercaseName.contains("apple tv") { return "com.apple.tv://" }
        if lowercaseName.contains("hulu") { return "hulu://" }
        if lowercaseName == "max" || lowercaseName.contains("hbo max") { return "max://" }
        if lowercaseName.contains("paramount") { return "paramountplus://" }
        if lowercaseName.contains("peacock") { return "peacock://" }
        if lowercaseName.contains("crave") { return "crave://" }
        if lowercaseName.contains("plex") { return "plex://" }
        if lowercaseName.contains("criterion") { return "criterionchannel://" }
        if lowercaseName.contains("mubi") { return "mubi://" }
        if lowercaseName.contains("shudder") { return "shudder://" }
        if lowercaseName.contains("tubi") { return "tubitv://" }
        if lowercaseName.contains("kanopy") { return "kanopy://" }

        return nil
    }

    /// URL to check if app is installed
    var appURL: URL? {
        guard let scheme = appURLScheme else { return nil }
        return URL(string: scheme)
    }

    /// Generate a deep link URL to search for a specific movie in the streaming app
    /// Uses Universal Links (web URLs) that iOS will open in the app if installed
    func searchURL(for movieTitle: String) -> URL? {
        let lowercaseName = name.lowercased()
        let encodedTitle = movieTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? movieTitle

        // Web URLs that support Universal Links and include search
        if lowercaseName.contains("netflix") {
            return URL(string: "https://www.netflix.com/search?q=\(encodedTitle)")
        }
        if lowercaseName.contains("amazon") || lowercaseName.contains("prime video") {
            return URL(string: "https://www.primevideo.com/search/ref=atv_nb_sr?phrase=\(encodedTitle)")
        }
        if lowercaseName.contains("disney") {
            return URL(string: "https://www.disneyplus.com/search?q=\(encodedTitle)")
        }
        if lowercaseName.contains("apple tv") {
            return URL(string: "https://tv.apple.com/search?term=\(encodedTitle)")
        }
        if lowercaseName.contains("hulu") {
            return URL(string: "https://www.hulu.com/search?q=\(encodedTitle)")
        }
        if lowercaseName == "max" || lowercaseName.contains("hbo max") {
            return URL(string: "https://www.max.com/search?q=\(encodedTitle)")
        }
        if lowercaseName.contains("paramount") {
            return URL(string: "https://www.paramountplus.com/search/?q=\(encodedTitle)")
        }
        if lowercaseName.contains("peacock") {
            return URL(string: "https://www.peacocktv.com/search?q=\(encodedTitle)")
        }
        if lowercaseName.contains("crave") {
            return URL(string: "https://www.crave.ca/en/search?q=\(encodedTitle)")
        }
        if lowercaseName.contains("tubi") {
            return URL(string: "https://tubitv.com/search/\(encodedTitle)")
        }
        if lowercaseName.contains("mubi") {
            return URL(string: "https://mubi.com/search?query=\(encodedTitle)")
        }
        if lowercaseName.contains("criterion") {
            return URL(string: "https://www.criterionchannel.com/search?q=\(encodedTitle)")
        }
        if lowercaseName.contains("kanopy") {
            return URL(string: "https://www.kanopy.com/en/search?query=\(encodedTitle)")
        }

        return nil
    }
}

/// Watch availability for a movie
struct WatchAvailability: Codable, Equatable {
    let streaming: [WatchProvider]   // Subscription streaming (flatrate)
    let rent: [WatchProvider]
    let buy: [WatchProvider]
    let tmdbLink: URL?               // Link to TMDb page with deep links

    var isEmpty: Bool {
        streaming.isEmpty && rent.isEmpty && buy.isEmpty
    }

    var hasStreaming: Bool { !streaming.isEmpty }
    var hasRentOrBuy: Bool { !rent.isEmpty || !buy.isEmpty }

    static let empty = WatchAvailability(streaming: [], rent: [], buy: [], tmdbLink: nil)
}

/// Enriched movie data from TMDb, stored alongside the base Movie
struct TMDbMovieInfo: Codable, Equatable {
    let tmdbId: Int
    let imdbID: String?
    let overview: String?
    let tagline: String?
    let runtime: Int?
    let rating: Double?
    let voteCount: Int?
    let genres: [String]
    let director: String?
    let topCast: [String]
    let posterURL: URL?
    let backdropURL: URL?
    let trailerURL: URL?
    let releaseDate: String?
    let watchAvailability: WatchAvailability?

    /// Human-readable runtime string
    var formattedRuntime: String? {
        guard let runtime = runtime, runtime > 0 else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Rating formatted as string (e.g., "7.5")
    var formattedRating: String? {
        guard let rating = rating, rating > 0 else { return nil }
        return String(format: "%.1f", rating)
    }
}

// MARK: - Title Matching

/// Parsed title with extracted metadata
struct ParsedTitle {
    let original: String
    let normalized: String
    let year: Int?
    let isSpecialEdition: Bool
}

/// Intelligent title matching for TMDb searches
enum TitleMatcher {

    // MARK: - Title Parsing

    /// Parse a movie title to extract year and normalize the text
    static func parseTitle(_ title: String) -> ParsedTitle {
        var workingTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var extractedYear: Int?
        var isSpecialEdition = false

        // Remove cinema event markers (e.g., "Presented by...", "Q&A with...")
        removeEventMarkers(from: &workingTitle)

        // Extract year from title (e.g., "Dune (2021)" or "Dune 2021")
        extractedYear = extractYear(from: &workingTitle)

        // Check for and remove special edition markers
        isSpecialEdition = removeSpecialEditionMarkers(from: &workingTitle)

        // Normalize the title
        let normalized = normalizeTitle(workingTitle)

        return ParsedTitle(
            original: title,
            normalized: normalized,
            year: extractedYear,
            isSpecialEdition: isSpecialEdition
        )
    }

    /// Remove cinema event markers from title (e.g., "The Room – Presented by Greg Sestero" -> "The Room")
    private static func removeEventMarkers(from title: inout String) {
        // Patterns that indicate event-specific text follows
        // Using various dash types: - – —
        let eventPatterns = [
            #"\s*[–—\-]\s*[Pp]resented\s+by\s+.*$"#,      // – Presented by ...
            #"\s*[–—\-]\s*[Ii]ntroduced\s+by\s+.*$"#,    // – Introduced by ...
            #"\s*[–—\-]\s*[Hh]osted\s+by\s+.*$"#,        // – Hosted by ...
            #"\s*[–—\-]\s*[Ww]ith\s+.*$"#,               // – With ...
            #"\s*[–—\-]\s*[Ll]ive\s+.*$"#,               // – Live ...
            #"\s*[–—\-]\s*[Ss]pecial\s+.*$"#,            // – Special ...
            #"\s*\+\s*[Ss]hort[s]?.*$"#,                  // + Short / + Shorts
            #"\s*\+\s*Q&?A.*$"#,                          // + Q&A / + QA
            #"\s*[–—\-]\s*Q&?A.*$"#,                      // – Q&A
            #"\s*\([Ww]ith\s+Q&?A\)$"#,                   // (with Q&A)
            #"\s*\([Ll]ive\s+[Cc]ommentary\)$"#,         // (Live Commentary)
            #"\s*[–—\-]\s*[Ss]ing[\s\-]?[Aa]long.*$"#,   // – Sing-Along / Singalong
            #"\s*[–—\-]\s*[Dd]ouble\s+[Ff]eature.*$"#,   // – Double Feature
            #"\s*[–—\-]\s*[Mm]arathon.*$"#,              // – Marathon
            #"\s*[–—\-]\s*[Ff]ree\s+[Ss]creening.*$"#,   // – Free Screening
            #"\s*[–—\-]\s*[Ss]neak\s+[Pp]review.*$"#,    // – Sneak Preview
            #"\s*[–—\-]\s*[Aa]dvance\s+[Ss]creening.*$"#, // – Advance Screening
            #"\s*:\s*[Tt]he\s+[Ee]xperience.*$"#,        // : The Experience
        ]

        for pattern in eventPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                title = regex.stringByReplacingMatches(
                    in: title,
                    range: NSRange(title.startIndex..., in: title),
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespaces)
            }
        }
    }

    /// Extract year from title string, modifying the input to remove the year
    private static func extractYear(from title: inout String) -> Int? {
        // Pattern: (2021) or [2021] at end of title
        let bracketPattern = #"\s*[\(\[](19\d{2}|20\d{2})[\)\]]\s*$"#
        if let regex = try? NSRegularExpression(pattern: bracketPattern),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let yearRange = Range(match.range(at: 1), in: title) {
            let year = Int(title[yearRange])
            title = regex.stringByReplacingMatches(
                in: title,
                range: NSRange(title.startIndex..., in: title),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespaces)
            return year
        }

        // Pattern: standalone year at end (e.g., "Nosferatu 1922")
        let standalonePattern = #"\s+(19\d{2}|20\d{2})\s*$"#
        if let regex = try? NSRegularExpression(pattern: standalonePattern),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let yearRange = Range(match.range(at: 1), in: title) {
            let year = Int(title[yearRange])
            title = regex.stringByReplacingMatches(
                in: title,
                range: NSRange(title.startIndex..., in: title),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespaces)
            return year
        }

        return nil
    }

    /// Remove special edition markers from title
    private static func removeSpecialEditionMarkers(from title: inout String) -> Bool {
        let markers = [
            "director's cut",
            "directors cut",
            "extended cut",
            "extended edition",
            "special edition",
            "final cut",
            "theatrical cut",
            "unrated",
            "remastered",
            "restored",
            "reconstructed",
            "anniversary edition",
            "collector's edition",
            "4k restoration",
            "4k remaster",
            "criterion"
        ]

        let originalTitle = title
        for marker in markers {
            // Remove marker with various separators
            let patterns = [
                "\\s*[:\\-–—]\\s*\(marker)",
                "\\s*\\(\(marker)\\)",
                "\\s*\\[\(marker)\\]",
                "\\s+\(marker)$"
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    title = regex.stringByReplacingMatches(
                        in: title,
                        range: NSRange(title.startIndex..., in: title),
                        withTemplate: ""
                    ).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return title != originalTitle
    }

    /// Normalize a title for comparison
    static func normalizeTitle(_ title: String) -> String {
        var normalized = title.lowercased()

        // Remove leading articles for comparison
        let articles = ["the ", "a ", "an ", "le ", "la ", "les ", "el ", "los ", "das ", "der ", "die "]
        for article in articles {
            if normalized.hasPrefix(article) {
                normalized = String(normalized.dropFirst(article.count))
                break
            }
        }

        // Remove punctuation except essential characters
        let punctuationToRemove = CharacterSet.punctuationCharacters
            .subtracting(CharacterSet(charactersIn: "&"))
        normalized = normalized.components(separatedBy: punctuationToRemove).joined()

        // Normalize whitespace
        normalized = normalized.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Handle common replacements
        normalized = normalized
            .replacingOccurrences(of: " and ", with: " & ")
            .replacingOccurrences(of: "  ", with: " ")

        return normalized.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Scoring

    /// Score a candidate result against the search title
    /// Higher scores indicate better matches
    static func scoreMatch(
        searchTitle: ParsedTitle,
        candidate: TMDbSearchResult,
        currentYear: Int
    ) -> Int {
        var score = 0

        let candidateNormalized = normalizeTitle(candidate.title)
        let candidateOriginalNormalized = candidate.originalTitle.map { normalizeTitle($0) }

        // Exact match on normalized title: +100 points
        if searchTitle.normalized == candidateNormalized {
            score += 100
        }
        // Exact match on original title: +100 points
        else if let original = candidateOriginalNormalized, searchTitle.normalized == original {
            score += 100
        }
        // Title contains search or vice versa: +50 points
        else if candidateNormalized.contains(searchTitle.normalized) ||
                    searchTitle.normalized.contains(candidateNormalized) {
            score += 50
        }
        // Fuzzy match (Levenshtein distance): up to +40 points
        else {
            let distance = levenshteinDistance(searchTitle.normalized, candidateNormalized)
            let maxLen = max(searchTitle.normalized.count, candidateNormalized.count)
            if maxLen > 0 {
                let similarity = 1.0 - (Double(distance) / Double(maxLen))
                if similarity > 0.7 {
                    score += Int(similarity * 40)
                }
            }
        }

        // Year matching
        if let searchYear = searchTitle.year {
            if let candidateYear = extractReleaseYear(from: candidate.releaseDate) {
                if searchYear == candidateYear {
                    // Exact year match: +50 points
                    score += 50
                } else if abs(searchYear - candidateYear) == 1 {
                    // Off by one year (release date variations): +20 points
                    score += 20
                } else {
                    // Wrong year: -30 points
                    score -= 30
                }
            }
        } else {
            // No year specified - prefer recent releases (arthouse cinemas show new films)
            if let candidateYear = extractReleaseYear(from: candidate.releaseDate) {
                let yearsAgo = currentYear - candidateYear
                if yearsAgo <= 2 {
                    // Released in last 2 years: +25 points
                    score += 25
                } else if yearsAgo <= 5 {
                    // Released in last 5 years: +10 points
                    score += 10
                }
                // Classic films (>30 years) being re-released are also common
                else if yearsAgo > 30 {
                    score += 5
                }
            }
        }

        // Popularity bonus (films with more votes are more likely correct)
        if let voteCount = candidate.voteCount {
            if voteCount > 1000 {
                score += 15
            } else if voteCount > 100 {
                score += 10
            } else if voteCount > 10 {
                score += 5
            }
        }

        // Rating bonus (highly rated films more likely to be shown at arthouse)
        if let rating = candidate.voteAverage, rating > 7.0 {
            score += 5
        }

        return score
    }

    /// Extract year from a release date string (YYYY-MM-DD format)
    private static func extractReleaseYear(from dateString: String?) -> Int? {
        guard let dateString = dateString, dateString.count >= 4 else { return nil }
        return Int(dateString.prefix(4))
    }

    /// Calculate Levenshtein distance between two strings
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        if m == 0 { return n }
        if n == 0 { return m }

        // Use two rows instead of full matrix for memory efficiency
        var prevRow = Array(0...n)
        var currRow = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            currRow[0] = i
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                currRow[j] = min(
                    currRow[j - 1] + 1,      // insertion
                    prevRow[j] + 1,          // deletion
                    prevRow[j - 1] + cost    // substitution
                )
            }
            swap(&prevRow, &currRow)
        }

        return prevRow[n]
    }
}

// MARK: - TMDb Service

/// Errors that can occur when fetching from TMDb
enum TMDbError: LocalizedError {
    case invalidAPIKey
    case movieNotFound
    case networkError(Error)
    case decodingError(Error)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid TMDb API key. Please configure a valid API key."
        case .movieNotFound:
            return "Movie not found on TMDb."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse TMDb response: \(error.localizedDescription)"
        case .rateLimited:
            return "TMDb rate limit exceeded. Please try again later."
        }
    }
}

/// Service for fetching movie metadata from TMDb
actor TMDbService {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private let cache = TMDbCache.shared

    /// Check if TMDb API is configured
    var isConfigured: Bool {
        TMDbConfig.apiKey != "YOUR_TMDB_API_KEY" && !TMDbConfig.apiKey.isEmpty
    }

    /// Search for a movie by title
    func searchMovie(title: String) async throws -> [TMDbSearchResult] {
        guard isConfigured else {
            throw TMDbError.invalidAPIKey
        }

        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(TMDbConfig.baseURL)/search/movie?api_key=\(TMDbConfig.apiKey)&query=\(encodedTitle)") else {
            throw TMDbError.networkError(NSError(domain: "Invalid URL", code: 0))
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDbError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw TMDbError.invalidAPIKey
        case 429:
            throw TMDbError.rateLimited
        default:
            throw TMDbError.networkError(NSError(domain: "HTTP", code: httpResponse.statusCode))
        }

        do {
            let searchResponse = try decoder.decode(TMDbSearchResponse.self, from: data)
            return searchResponse.results
        } catch {
            throw TMDbError.decodingError(error)
        }
    }

    /// Get detailed movie information by TMDb ID
    func getMovieDetails(tmdbId: Int) async throws -> TMDbMovieDetail {
        guard isConfigured else {
            throw TMDbError.invalidAPIKey
        }

        guard let url = URL(string: "\(TMDbConfig.baseURL)/movie/\(tmdbId)?api_key=\(TMDbConfig.apiKey)&append_to_response=credits,videos,external_ids,watch/providers") else {
            throw TMDbError.networkError(NSError(domain: "Invalid URL", code: 0))
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDbError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw TMDbError.invalidAPIKey
        case 404:
            throw TMDbError.movieNotFound
        case 429:
            throw TMDbError.rateLimited
        default:
            throw TMDbError.networkError(NSError(domain: "HTTP", code: httpResponse.statusCode))
        }

        do {
            return try decoder.decode(TMDbMovieDetail.self, from: data)
        } catch {
            throw TMDbError.decodingError(error)
        }
    }

    /// Fetch enriched movie info for a movie title, using cache when available
    func fetchMovieInfo(for title: String) async -> TMDbMovieInfo? {
        // Check cache first
        if let cached = await cache.getInfo(for: title) {
            return cached
        }

        // Search and fetch from API
        guard let info = await fetchMovieInfoFromAPI(title: title) else {
            return nil
        }

        // Cache the result
        await cache.save(info: info, for: title)

        return info
    }

    /// Fetch movie info directly from API (no cache)
    private func fetchMovieInfoFromAPI(title: String) async -> TMDbMovieInfo? {
        do {
            // Parse the title to remove special edition markers, event text, etc.
            let parsedTitle = TitleMatcher.parseTitle(title)

            // First, try searching with the cleaned/normalized title
            var results = try await searchMovie(title: parsedTitle.normalized)

            // If no results with normalized title, try the original
            if results.isEmpty && parsedTitle.normalized != title.lowercased() {
                results = try await searchMovie(title: title)
            }

            // If still no results, try without leading article (The, A, An)
            if results.isEmpty {
                let titleWithoutArticle = parsedTitle.normalized
                    .replacingOccurrences(of: "^the ", with: "", options: [.regularExpression, .caseInsensitive])
                    .replacingOccurrences(of: "^a ", with: "", options: [.regularExpression, .caseInsensitive])
                    .replacingOccurrences(of: "^an ", with: "", options: [.regularExpression, .caseInsensitive])

                if titleWithoutArticle != parsedTitle.normalized {
                    results = try await searchMovie(title: titleWithoutArticle)
                }
            }

            // Find best match - prefer exact title match
            guard let bestMatch = findBestMatch(for: title, in: results) else {
                return nil
            }

            // Get full details
            let details = try await getMovieDetails(tmdbId: bestMatch.id)

            return createMovieInfo(from: details)
        } catch {
            print("TMDb fetch error for '\(title)': \(error.localizedDescription)")
            return nil
        }
    }

    /// Find the best matching movie from search results using intelligent scoring
    private func findBestMatch(for title: String, in results: [TMDbSearchResult]) -> TMDbSearchResult? {
        guard !results.isEmpty else { return nil }

        let parsedTitle = TitleMatcher.parseTitle(title)
        let currentYear = Calendar.current.component(.year, from: Date())

        // Score each result and find the best match
        let scoredResults = results.map { result -> (result: TMDbSearchResult, score: Int) in
            let score = TitleMatcher.scoreMatch(
                searchTitle: parsedTitle,
                candidate: result,
                currentYear: currentYear
            )
            return (result, score)
        }

        // Sort by score descending and return the best match
        let bestMatch = scoredResults
            .sorted { $0.score > $1.score }
            .first

        // Only return if we have a reasonable match (score > 0)
        if let match = bestMatch, match.score > 0 {
            return match.result
        }

        // Fall back to first result if no good match found
        return results.first
    }

    /// Convert TMDb API response to our app model
    private func createMovieInfo(from details: TMDbMovieDetail) -> TMDbMovieInfo {
        // Get director from crew
        let director = details.credits?.crew?.first(where: { $0.job == "Director" })?.name

        // Get top 5 cast members
        let topCast = details.credits?.cast?
            .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
            .prefix(5)
            .map { $0.name } ?? []

        // Get genre names
        let genres = details.genres?.map { $0.name } ?? []

        // Build poster URL
        let posterURL = details.posterPath.flatMap {
            URL(string: "\(TMDbConfig.imageBaseURL)/\(TMDbConfig.PosterSize.large.rawValue)\($0)")
        }

        // Build backdrop URL
        let backdropURL = details.backdropPath.flatMap {
            URL(string: "\(TMDbConfig.imageBaseURL)/\(TMDbConfig.BackdropSize.large.rawValue)\($0)")
        }

        // Get trailer URL (prefer official trailers, then teasers)
        let trailer = details.videos?.results?
            .filter { $0.site == "YouTube" }
            .sorted { video1, video2 in
                let priority1 = video1.type == "Trailer" ? 0 : (video1.type == "Teaser" ? 1 : 2)
                let priority2 = video2.type == "Trailer" ? 0 : (video2.type == "Teaser" ? 1 : 2)
                return priority1 < priority2
            }
            .first

        // Get watch providers for Canada (CA), fallback to US
        let watchAvailability = createWatchAvailability(from: details.watchProviders)

        return TMDbMovieInfo(
            tmdbId: details.id,
            imdbID: details.externalIds?.imdbId,
            overview: details.overview,
            tagline: details.tagline,
            runtime: details.runtime,
            rating: details.voteAverage,
            voteCount: details.voteCount,
            genres: genres,
            director: director,
            topCast: Array(topCast),
            posterURL: posterURL,
            backdropURL: backdropURL,
            trailerURL: trailer?.youtubeURL,
            releaseDate: details.releaseDate,
            watchAvailability: watchAvailability
        )
    }

    /// Extract watch availability from TMDb response
    private func createWatchAvailability(from response: TMDbWatchProvidersResponse?) -> WatchAvailability? {
        guard let results = response?.results else { return nil }

        // Try Canada first, then US as fallback
        let countryProviders = results["CA"] ?? results["US"]
        guard let providers = countryProviders else { return nil }

        func convertProviders(_ tmdbProviders: [TMDbWatchProvider]?) -> [WatchProvider] {
            guard let tmdbProviders = tmdbProviders else { return [] }
            return tmdbProviders
                .sorted { ($0.displayPriority ?? 999) < ($1.displayPriority ?? 999) }
                .map { provider in
                    let logoURL = provider.logoPath.flatMap {
                        URL(string: "\(TMDbConfig.imageBaseURL)/\(TMDbConfig.PosterSize.small.rawValue)\($0)")
                    }
                    return WatchProvider(
                        id: provider.providerId,
                        name: provider.providerName,
                        logoURL: logoURL
                    )
                }
        }

        let availability = WatchAvailability(
            streaming: convertProviders(providers.flatrate),
            rent: convertProviders(providers.rent),
            buy: convertProviders(providers.buy),
            tmdbLink: providers.link.flatMap { URL(string: $0) }
        )

        return availability.isEmpty ? nil : availability
    }
}

// MARK: - TMDb Cache

/// Cache for TMDb movie info to avoid repeated API calls
actor TMDbCache {
    static let shared = TMDbCache()

    private let cacheFileName = "tmdb_cache.json"
    private let cacheVersionKey = "tmdb_cache_version"
    /// Increment this when TMDbMovieInfo structure changes
    private let currentCacheVersion = 3  // Incremented for watchAvailability field

    private var memoryCache: [String: TMDbMovieInfo] = [:]
    private var cacheLoaded = false

    private var cacheFileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(cacheFileName)
    }

    /// Get cached info for a movie title
    func getInfo(for title: String) -> TMDbMovieInfo? {
        if !cacheLoaded {
            loadFromDisk()
        }
        return memoryCache[title.lowercased()]
    }

    /// Save movie info to cache
    func save(info: TMDbMovieInfo, for title: String) {
        memoryCache[title.lowercased()] = info
        saveToDisk()
    }

    /// Clear all cached data
    func clear() {
        memoryCache.removeAll()
        if let url = cacheFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func loadFromDisk() {
        cacheLoaded = true

        // Check cache version - clear if outdated
        let storedVersion = UserDefaults.standard.integer(forKey: cacheVersionKey)
        if storedVersion != currentCacheVersion {
            clear()
            UserDefaults.standard.set(currentCacheVersion, forKey: cacheVersionKey)
            return
        }

        guard let url = cacheFileURL,
              let data = try? Data(contentsOf: url),
              let cached = try? JSONDecoder().decode([String: TMDbMovieInfo].self, from: data) else {
            return
        }
        memoryCache = cached
    }

    private func saveToDisk() {
        guard let url = cacheFileURL,
              let data = try? JSONEncoder().encode(memoryCache) else {
            return
        }
        try? data.write(to: url)
    }
}

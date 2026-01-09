import Foundation

/// Represents a single movie showing at Cinecenta
struct Showtime: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date?

    init(id: UUID = UUID(), startDate: Date, endDate: Date? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
    }

    var formattedDate: String {
        startDate.formatted(date: .abbreviated, time: .omitted)
    }

    var formattedTime: String {
        startDate.formatted(date: .omitted, time: .shortened)
    }

    var dayOfWeek: String {
        startDate.formatted(.dateTime.weekday(.wide))
    }
}

/// Represents a movie with all its scheduled showtimes
struct Movie: Identifiable {
    let id: UUID
    let title: String
    let imageURL: URL?
    var showtimes: [Showtime]

    /// Enriched data from TMDb (optional)
    var tmdbInfo: TMDbMovieInfo?

    init(id: UUID = UUID(), title: String, imageURL: URL?, showtimes: [Showtime], tmdbInfo: TMDbMovieInfo? = nil) {
        self.id = id
        self.title = title
        self.imageURL = imageURL
        self.showtimes = showtimes
        self.tmdbInfo = tmdbInfo
    }

    /// Title with HTML entities decoded for display
    var displayTitle: String {
        title.htmlDecoded
    }

    /// Best available poster URL (TMDb preferred, fallback to scraped)
    var bestPosterURL: URL? {
        tmdbInfo?.posterURL ?? imageURL
    }

    /// Best available backdrop URL
    var backdropURL: URL? {
        tmdbInfo?.backdropURL
    }

    /// Groups showtimes by date for display
    var showtimesByDate: [(date: Date, times: [Showtime])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: showtimes) { showtime in
            calendar.startOfDay(for: showtime.startDate)
        }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, times: $0.value.sorted { $0.startDate < $1.startDate }) }
    }

    /// The next upcoming showtime
    var nextShowtime: Showtime? {
        showtimes
            .filter { $0.startDate > Date() }
            .min { $0.startDate < $1.startDate }
    }

    /// Showtimes for today only
    var tonightShowtimes: [Showtime] {
        let calendar = Calendar.current
        return showtimes.filter { calendar.isDateInToday($0.startDate) }
            .sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - JSON-LD Parsing Models

/// Schema.org Event structure from the website's JSON-LD
struct SchemaEvent {
    let type: String
    let name: String
    let startDate: String
    let endDate: String?
    let imageURL: String?

    /// Parse from a dictionary (since @graph contains mixed types)
    init?(from dict: [String: Any]) {
        guard let type = dict["@type"] as? String,
              let name = dict["name"] as? String,
              let startDate = dict["startDate"] as? String else {
            return nil
        }

        self.type = type
        self.name = name
        self.startDate = startDate
        self.endDate = dict["endDate"] as? String

        // Image can be a dict with "url" or a direct string
        if let imageDict = dict["image"] as? [String: Any] {
            self.imageURL = imageDict["url"] as? String
        } else if let imageString = dict["image"] as? String {
            self.imageURL = imageString
        } else {
            self.imageURL = nil
        }
    }
}

/// Parses JSON-LD that may contain @graph with mixed object types
struct SchemaParser {

    /// Extract Event objects from JSON-LD data
    static func parseEvents(from jsonData: Data) -> [SchemaEvent] {
        guard let json = try? JSONSerialization.jsonObject(with: jsonData) else {
            return []
        }

        var events: [SchemaEvent] = []

        // Handle @graph array
        if let dict = json as? [String: Any],
           let graph = dict["@graph"] as? [[String: Any]] {
            for item in graph {
                if let event = SchemaEvent(from: item), event.type == "Event" {
                    events.append(event)
                }
            }
        }

        // Handle direct array of events
        if let array = json as? [[String: Any]] {
            for item in array {
                if let event = SchemaEvent(from: item), event.type == "Event" {
                    events.append(event)
                }
            }
        }

        // Handle single event object
        if let dict = json as? [String: Any],
           let event = SchemaEvent(from: dict), event.type == "Event" {
            events.append(event)
        }

        return events
    }
}

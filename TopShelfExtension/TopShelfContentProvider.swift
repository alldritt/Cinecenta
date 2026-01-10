import TVServices

class TopShelfContentProvider: TVTopShelfContentProvider {

    private let service = CinecentaService()

    override func loadTopShelfContent() async -> TVTopShelfContent? {
        do {
            // Fetch movies with upcoming showtimes
            let allMovies = try await service.fetchMovies()
            let upcomingMovies = allMovies.filter { $0.nextShowtime != nil }

            // Create inset content items for the carousel
            var items: [TVTopShelfInsetContent.Item] = []

            for movie in upcomingMovies.prefix(10) {
                let item = TVTopShelfInsetContent.Item(identifier: movie.id.uuidString)
                item.title = movie.displayTitle

                // Use backdrop if available, otherwise poster
                if let backdropURL = movie.backdropURL {
                    item.setImageURL(backdropURL, for: .screenScale1x)
                    item.setImageURL(backdropURL, for: .screenScale2x)
                    item.imageShape = .hdtv
                } else if let posterURL = movie.bestPosterURL {
                    item.setImageURL(posterURL, for: .screenScale1x)
                    item.setImageURL(posterURL, for: .screenScale2x)
                    item.imageShape = .poster
                }

                // Add next showtime as secondary text if available
                if let nextShowtime = movie.nextShowtime {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .abbreviated
                    item.setTitle(movie.displayTitle, for: .primary)
                    item.setTitle(formatShowtime(nextShowtime.startDate), for: .secondary)
                }

                // Deep link to open movie detail in the app
                if let actionURL = URL(string: "cinecenta://movie/\(movie.id.uuidString)") {
                    item.displayAction = TVTopShelfAction(url: actionURL)
                    item.playAction = TVTopShelfAction(url: actionURL)
                }

                items.append(item)
            }

            guard !items.isEmpty else {
                return nil
            }

            return TVTopShelfInsetContent(items: items)

        } catch {
            print("TopShelf: Failed to load content - \(error)")
            return nil
        }
    }

    private func formatShowtime(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Tomorrow \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE h:mm a"
            return formatter.string(from: date)
        }
    }
}

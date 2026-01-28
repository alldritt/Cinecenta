import WidgetKit
import SwiftUI

/// Represents a movie with its pre-fetched image data for the widget
struct WidgetMovie: Identifiable {
    let id: UUID
    let title: String
    let showtimes: [Showtime]
    let imageData: Data?

    init(from movie: Movie, imageData: Data?) {
        self.id = movie.id
        self.title = movie.title
        self.showtimes = movie.showtimes
        self.imageData = imageData
    }

    init(title: String, showtimes: [Showtime]) {
        self.id = UUID()
        self.title = title
        self.showtimes = showtimes
        self.imageData = nil
    }

    var deepLinkURL: URL? {
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return URL(string: "cinecenta://")
        }
        return URL(string: "cinecenta://movie?title=\(encodedTitle)")
    }

    static var sample: WidgetMovie {
        let calendar = Calendar.current
        let today = Date()
        let showtime1 = Showtime(
            startDate: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today) ?? today,
            endDate: nil
        )
        let showtime2 = Showtime(
            startDate: calendar.date(bySettingHour: 19, minute: 30, second: 0, of: today) ?? today,
            endDate: nil
        )
        return WidgetMovie(title: "Double Indemnity", showtimes: [showtime1, showtime2])
    }

    static var sample2: WidgetMovie {
        let calendar = Calendar.current
        let today = Date()
        let showtime1 = Showtime(
            startDate: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: today) ?? today,
            endDate: nil
        )
        return WidgetMovie(title: "Casablanca", showtimes: [showtime1])
    }
}

/// Timeline entry for the widget
struct TonightMovieEntry: TimelineEntry {
    let date: Date
    let movies: [WidgetMovie]
    let isPlaceholder: Bool

    static var placeholder: TonightMovieEntry {
        TonightMovieEntry(date: Date(), movies: [], isPlaceholder: true)
    }

    static var noMovies: TonightMovieEntry {
        TonightMovieEntry(date: Date(), movies: [], isPlaceholder: false)
    }

    static var sample: TonightMovieEntry {
        TonightMovieEntry(
            date: Date(),
            movies: [.sample, .sample2],
            isPlaceholder: false
        )
    }
}

/// Provider that fetches tonight's movie data
struct TonightMovieProvider: TimelineProvider {
    private let service = CinecentaService()

    func placeholder(in context: Context) -> TonightMovieEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TonightMovieEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }

        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TonightMovieEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()

            let calendar = Calendar.current
            let now = Date()
            let nextRefresh = calendar.date(byAdding: .minute, value: 30, to: now) ?? now

            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
        }
    }

    private func fetchEntry() async -> TonightMovieEntry {
        do {
            let movies = try await service.fetchTonightMovies()
            guard !movies.isEmpty else {
                return .noMovies
            }

            // Fetch image data for all movies (limit to first 4 for performance)
            var widgetMovies: [WidgetMovie] = []
            for movie in movies.prefix(4) {
                var imageData: Data? = nil
                if let imageURL = movie.imageURL {
                    imageData = try? await URLSession.shared.data(from: imageURL).0
                }
                widgetMovies.append(WidgetMovie(from: movie, imageData: imageData))
            }

            return TonightMovieEntry(date: Date(), movies: widgetMovies, isPlaceholder: false)
        } catch {
            return .noMovies
        }
    }
}

// MARK: - Placeholder View

struct PlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tonight")
                .font(.caption2)
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.3))
                .frame(height: 20)

            Spacer()

            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.3))
                .frame(width: 80, height: 16)
        }
        .padding()
    }
}

// MARK: - No Movies View

struct NoMoviesView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "film")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No movies tonight")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Small Widget View

struct TonightMovieSmallView: View {
    let entry: TonightMovieEntry

    var body: some View {
        if entry.movies.isEmpty {
            NoMoviesView()
        } else if entry.movies.count == 1 {
            singleMovieView(entry.movies[0])
        } else {
            multipleMoviesView
        }
    }

    private func singleMovieView(_ movie: WidgetMovie) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tonight")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(movie.title)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer()

            if let showtime = movie.showtimes.first {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text(showtime.formattedTime)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(movie.deepLinkURL)
    }

    private var multipleMoviesView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Tonight")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.movies.count) films")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }

            ForEach(entry.movies.prefix(2)) { movie in
                HStack(spacing: 4) {
                    Text(movie.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    if let time = movie.showtimes.first {
                        Text(time.formattedTime)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget View

struct TonightMovieMediumView: View {
    let entry: TonightMovieEntry

    var body: some View {
        if entry.movies.isEmpty {
            NoMoviesView()
        } else if entry.movies.count == 1 {
            singleMovieView(entry.movies[0])
        } else {
            multipleMoviesView
        }
    }

    private func singleMovieView(_ movie: WidgetMovie) -> some View {
        HStack(spacing: 12) {
            posterImage(movie.imageData)
                .frame(width: 100)
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text("Tonight at Cinecenta")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                HStack(spacing: 6) {
                    ForEach(movie.showtimes.prefix(3)) { showtime in
                        Text(showtime.formattedTime)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(.vertical)

            Spacer()
        }
        .widgetURL(movie.deepLinkURL)
    }

    private var multipleMoviesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tonight at Cinecenta")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.movies.count) films")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }

            HStack(spacing: 12) {
                ForEach(entry.movies.prefix(2)) { movie in
                    Link(destination: movie.deepLinkURL ?? URL(string: "cinecenta://")!) {
                        VStack(alignment: .leading, spacing: 4) {
                            posterImage(movie.imageData)
                                .frame(height: 60)
                                .clipped()

                            Text(movie.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .foregroundStyle(.primary)

                            if let time = movie.showtimes.first {
                                Text(time.formattedTime)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func posterImage(_ imageData: Data?) -> some View {
        if let imageData = imageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - Large Widget View

struct TonightMovieLargeView: View {
    let entry: TonightMovieEntry

    var body: some View {
        if entry.movies.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "film")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Movies Tonight")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Check back tomorrow")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if entry.movies.count == 1 {
            singleMovieView(entry.movies[0])
        } else {
            multipleMoviesView
        }
    }

    private func singleMovieView(_ movie: WidgetMovie) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            posterImage(movie.imageData)
                .frame(height: 140)
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text("Tonight at Cinecenta")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(movie.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(2)

                Spacer()

                Text("Showtimes")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(movie.showtimes.prefix(6)) { showtime in
                        Text(showtime.formattedTime)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
        }
        .widgetURL(movie.deepLinkURL)
    }

    private var multipleMoviesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tonight at Cinecenta")
                    .font(.headline)
                Spacer()
                Text("\(entry.movies.count) films")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ForEach(entry.movies.prefix(3)) { movie in
                Link(destination: movie.deepLinkURL ?? URL(string: "cinecenta://")!) {
                    HStack(spacing: 12) {
                        posterImage(movie.imageData)
                            .frame(width: 80, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(movie.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .foregroundStyle(.primary)

                            HStack(spacing: 6) {
                                ForEach(movie.showtimes.prefix(3)) { showtime in
                                    Text(showtime.formattedTime)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func posterImage(_ imageData: Data?) -> some View {
        if let imageData = imageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - Accessory Circular View (Lock Screen)

struct AccessoryCircularView: View {
    let entry: TonightMovieEntry

    var body: some View {
        if entry.movies.isEmpty {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "film")
                    .font(.title2)
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "film.fill")
                        .font(.caption)
                    Text("\(entry.movies.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Accessory Rectangular View (Lock Screen)

struct AccessoryRectangularView: View {
    let entry: TonightMovieEntry

    var body: some View {
        if entry.movies.isEmpty {
            HStack {
                Image(systemName: "film")
                Text("No movies tonight")
            }
            .font(.caption)
        } else if let movie = entry.movies.first {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "film.fill")
                        .font(.caption2)
                    Text("Tonight")
                        .font(.caption2)
                        .textCase(.uppercase)
                }

                Text(movie.title)
                    .font(.headline)
                    .lineLimit(1)

                if let showtime = movie.showtimes.first {
                    Text(showtime.formattedTime)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(movie.deepLinkURL)
        }
    }
}

// MARK: - Accessory Inline View (Lock Screen)

struct AccessoryInlineView: View {
    let entry: TonightMovieEntry

    var body: some View {
        if entry.movies.isEmpty {
            Text("No movies tonight")
        } else if let movie = entry.movies.first {
            if let showtime = movie.showtimes.first {
                Text("\(movie.title) \(showtime.formattedTime)")
            } else {
                Text(movie.title)
            }
        }
    }
}

// MARK: - Main Widget View

struct TonightMovieWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TonightMovieEntry

    var body: some View {
        Group {
            if entry.isPlaceholder {
                PlaceholderView()
            } else {
                switch family {
                case .systemSmall:
                    TonightMovieSmallView(entry: entry)
                case .systemMedium:
                    TonightMovieMediumView(entry: entry)
                case .systemLarge:
                    TonightMovieLargeView(entry: entry)
                case .accessoryCircular:
                    AccessoryCircularView(entry: entry)
                case .accessoryRectangular:
                    AccessoryRectangularView(entry: entry)
                case .accessoryInline:
                    AccessoryInlineView(entry: entry)
                default:
                    TonightMovieSmallView(entry: entry)
                }
            }
        }
    }
}

// MARK: - Widget Configuration

struct CinecentaWidget: Widget {
    let kind: String = "CinecentaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TonightMovieProvider()) { entry in
            TonightMovieWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tonight's Movies")
        .description("Shows what's playing tonight at Cinecenta.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

@main
struct CinecentaWidgetBundle: WidgetBundle {
    var body: some Widget {
        CinecentaWidget()
    }
}

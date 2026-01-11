import SwiftUI
import UIKit

/// View model for the movie list using modern @Observable macro
@Observable
final class MovieListViewModel {
    private(set) var movies: [Movie] = []
    private(set) var isLoading = false
    private(set) var isEnrichingData = false
    private(set) var errorMessage: String?

    private let service = CinecentaService()
    private let tmdbService = TMDbService()

    @MainActor
    func loadMovies() async {
        isLoading = true
        errorMessage = nil

        do {
            let allMovies = try await service.fetchMovies()
            // Only show movies with upcoming showtimes
            movies = allMovies.filter { $0.nextShowtime != nil }

            // Enrich with TMDb data in background
            await enrichMoviesWithTMDb()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Enriches movies with TMDb data progressively
    @MainActor
    private func enrichMoviesWithTMDb() async {
        guard await tmdbService.isConfigured else { return }

        isEnrichingData = true

        // Fetch TMDb data for each movie concurrently (with some throttling)
        await withTaskGroup(of: (Int, TMDbMovieInfo?).self) { group in
            for (index, movie) in movies.enumerated() {
                group.addTask {
                    let info = await self.tmdbService.fetchMovieInfo(for: movie.title)
                    return (index, info)
                }
            }

            for await (index, info) in group {
                if let info = info, index < movies.count {
                    movies[index].tmdbInfo = info
                }
            }
        }

        isEnrichingData = false
    }

    func findMovie(byTitle title: String) -> Movie? {
        movies.first { $0.title == title }
    }
}

/// Main list view displaying all upcoming movies
struct MovieListView: View {
    @State private var viewModel = MovieListViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var currentDay = Calendar.current.startOfDay(for: Date())
    @Binding var selectedMovieTitle: String?

    init(selectedMovieTitle: Binding<String?> = .constant(nil)) {
        _selectedMovieTitle = selectedMovieTitle
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading && viewModel.movies.isEmpty {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.movies.isEmpty {
                    errorView(error)
                } else {
                    movieList
                }
            }
            .navigationTitle("Cinecenta")
            .navigationDestination(for: UUID.self) { movieId in
                if let movie = viewModel.movies.first(where: { $0.id == movieId }) {
                    MovieDetailView(movie: movie)
                }
            }
            .refreshable {
                await viewModel.loadMovies()
            }
            .task {
                if viewModel.movies.isEmpty {
                    await viewModel.loadMovies()
                }
            }
            .onChange(of: selectedMovieTitle) { _, newTitle in
                handleDeepLink(newTitle)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                currentDay = Calendar.current.startOfDay(for: Date())
            }
        }
    }

    private func handleDeepLink(_ title: String?) {
        guard let title = title,
              let movie = viewModel.findMovie(byTitle: title) else {
            return
        }
        // Clear any existing navigation and navigate to the movie
        navigationPath = NavigationPath()
        navigationPath.append(movie.id)
        // Reset the selection
        selectedMovieTitle = nil
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading schedule...")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Unable to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel.loadMovies()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var movieList: some View {
        List(viewModel.movies) { movie in
            NavigationLink(value: movie.id) {
                MovieRowView(movie: movie, currentDay: currentDay)
            }
        }
        .listStyle(.plain)
    }
}

/// Row view for a single movie in the list
struct MovieRowView: View {
    private enum Constants {
        static let posterWidth: CGFloat = 80
        static let posterHeight: CGFloat = 60
    }

    let movie: Movie
    let currentDay: Date
    private var notificationManager: NotificationManager { .shared }

    private var hasAnyReminder: Bool {
        movie.showtimes.contains { showtime in
            notificationManager.hasReminder(movieTitle: movie.title, showtime: showtime)
        }
    }

    private var hasShowtimeToday: Bool {
        let calendar = Calendar.current
        return movie.showtimes.contains { calendar.isDate($0.startDate, inSameDayAs: currentDay) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            posterImage
            movieInfo

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if hasShowtimeToday {
                    Text("TODAY")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                if hasAnyReminder {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var posterImage: some View {
        if let imageURL = movie.bestPosterURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    imagePlaceholder
                case .empty:
                    ProgressView()
                @unknown default:
                    imagePlaceholder
                }
            }
            .frame(width: Constants.posterWidth, height: Constants.posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .frame(width: Constants.posterWidth, height: Constants.posterHeight)
            .overlay {
                Image(systemName: "film")
                    .foregroundStyle(.secondary)
            }
    }

    private var movieInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(movie.displayTitle)
                .font(.headline)
                .lineLimit(2)

            // TMDb metadata row (rating, runtime, genre)
            if let tmdb = movie.tmdbInfo {
                HStack(spacing: 8) {
                    if let rating = tmdb.formattedRating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(rating)
                        }
                        .font(.caption)
                    }

                    if let runtime = tmdb.formattedRuntime {
                        Text(runtime)
                            .font(.caption)
                    }

                    if let genre = tmdb.genres.first {
                        Text(genre)
                            .font(.caption)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(showtimeRangeText)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)

            Text("\(upcomingShowtimes.count) showing\(upcomingShowtimes.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var upcomingShowtimes: [Showtime] {
        movie.showtimes.filter { $0.startDate > Date() }
    }

    private var showtimeRangeText: String {
        let upcoming = upcomingShowtimes
        guard let first = upcoming.first else { return "" }

        let calendar = Calendar.current
        let lastShowtime = upcoming.last!

        // Check if showtimes span multiple days
        let spansMultipleDays = !calendar.isDate(first.startDate, inSameDayAs: lastShowtime.startDate)

        if spansMultipleDays {
            return "\(formatShowtimeShort(first)) – \(formatShowtimeShort(lastShowtime))"
        } else {
            return formatShowtime(first)
        }
    }

    private func isMoreThanOneWeekAway(_ date: Date) -> Bool {
        let oneWeekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return date > oneWeekFromNow
    }

    private func formatShowtime(_ showtime: Showtime) -> String {
        if isMoreThanOneWeekAway(showtime.startDate) {
            // More than a week away: include month and day
            let dateFormat = showtime.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            return "\(dateFormat), \(showtime.formattedTime)"
        } else {
            // Within a week: just day of week and time
            return "\(showtime.dayOfWeek), \(showtime.formattedTime)"
        }
    }

    private func formatShowtimeShort(_ showtime: Showtime) -> String {
        if isMoreThanOneWeekAway(showtime.startDate) {
            // More than a week away: include month and day with time
            let dateFormat = showtime.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            return "\(dateFormat) \(showtime.formattedTime)"
        } else {
            // Within a week: abbreviated day of week with time
            return "\(showtime.startDate.formatted(.dateTime.weekday(.abbreviated))) \(showtime.formattedTime)"
        }
    }
}

#Preview {
    MovieListView()
}

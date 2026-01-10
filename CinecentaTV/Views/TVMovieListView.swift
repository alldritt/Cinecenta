import SwiftUI

/// View model for the tvOS movie list
@Observable
final class TVMovieListViewModel {
    private(set) var movies: [Movie] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service = CinecentaService()
    private let tmdbService = TMDbService()

    @MainActor
    func loadMovies() async {
        isLoading = true
        errorMessage = nil

        do {
            let allMovies = try await service.fetchMovies()
            movies = allMovies.filter { $0.nextShowtime != nil }
            await enrichMoviesWithTMDb()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func enrichMoviesWithTMDb() async {
        guard await tmdbService.isConfigured else { return }

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
    }
}

/// Main movie list view for tvOS with a poster grid layout
struct TVMovieListView: View {
    @State private var viewModel = TVMovieListViewModel()
    @State private var selectedMovie: Movie?

    private let columns = [
        GridItem(.flexible(), spacing: 48),
        GridItem(.flexible(), spacing: 48)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.movies.isEmpty {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.movies.isEmpty {
                    errorView(error)
                } else {
                    movieGrid
                }
            }
            .navigationTitle("Cinecenta")
            .navigationDestination(for: Movie.ID.self) { movieId in
                if let movie = viewModel.movies.first(where: { $0.id == movieId }) {
                    TVMovieDetailView(movie: movie)
                }
            }
            .task {
                if viewModel.movies.isEmpty {
                    await viewModel.loadMovies()
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)
            Text("Loading schedule...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Unable to Load")
                .font(.title2)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
            Button("Try Again") {
                Task {
                    await viewModel.loadMovies()
                }
            }
        }
    }

    private var movieGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 50) {
                ForEach(viewModel.movies) { movie in
                    NavigationLink(value: movie.id) {
                        TVMoviePosterCard(movie: movie)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(60)
        }
    }
}

/// Poster card for the tvOS grid view - horizontal layout
struct TVMoviePosterCard: View {
    let movie: Movie

    private let posterWidth: CGFloat = 200
    private let posterHeight: CGFloat = 300
    private let cardHeight: CGFloat = 300

    private var hasShowtimeToday: Bool {
        let calendar = Calendar.current
        return movie.showtimes.contains { calendar.isDateInToday($0.startDate) }
    }

    private var upcomingShowtimeCount: Int {
        movie.showtimes.filter { $0.startDate > Date() }.count
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Poster image
            posterImage
                .frame(width: posterWidth, height: posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info section
            VStack(alignment: .leading, spacing: 12) {
                // TODAY badge
                if hasShowtimeToday {
                    Text("TODAY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                // Movie title
                Text(movie.displayTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Rating and runtime
                if let tmdb = movie.tmdbInfo {
                    HStack(spacing: 16) {
                        if let rating = tmdb.formattedRating {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(rating)
                            }
                        }

                        if let runtime = tmdb.formattedRuntime {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                Text(runtime)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .font(.body)
                }

                Spacer(minLength: 0)

                // Showtime count
                HStack(spacing: 6) {
                    Image(systemName: "ticket")
                    Text("\(upcomingShowtimeCount) showing\(upcomingShowtimeCount == 1 ? "" : "s")")
                }
                .font(.body)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .frame(height: cardHeight)
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
                    posterPlaceholder
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.secondary.opacity(0.2))
                @unknown default:
                    posterPlaceholder
                }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    TVMovieListView()
}

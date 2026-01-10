import SwiftUI

/// Detail view for tvOS showing movie information
struct TVMovieDetailView: View {
    let movie: Movie
    @FocusState private var focusedSection: DetailSection?

    enum DetailSection: Hashable {
        case title
        case synopsis
        case cast
        case showtimes
        case streaming
    }

    // Cache the image URL to prevent re-evaluation
    private var heroImageURL: URL? {
        movie.backdropURL ?? movie.bestPosterURL
    }

    private var useBlurredPoster: Bool {
        movie.backdropURL == nil && movie.bestPosterURL != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero backdrop section
                TVHeroImage(
                    url: heroImageURL,
                    useBlur: useBlurredPoster
                )

                // Content section
                VStack(alignment: .leading, spacing: 40) {
                    // Title and metadata
                    titleSection
                        .focusable()
                        .focused($focusedSection, equals: .title)

                    // Synopsis
                    if let overview = movie.tmdbInfo?.overview, !overview.isEmpty {
                        synopsisSection(overview)
                            .focusable()
                            .focused($focusedSection, equals: .synopsis)
                    }

                    // Cast & Crew
                    if movie.tmdbInfo != nil {
                        castSection
                            .focusable()
                            .focused($focusedSection, equals: .cast)
                    }

                    // Showtimes
                    if !movie.showtimes.isEmpty {
                        showtimesSection
                            .focusable()
                            .focused($focusedSection, equals: .showtimes)
                    }

                    // Streaming availability
                    if let availability = movie.tmdbInfo?.watchAvailability, !availability.isEmpty {
                        streamingSection(availability)
                            .focusable()
                            .focused($focusedSection, equals: .streaming)
                    }

                    // Bottom spacer for scroll padding
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 60)
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(movie.displayTitle)
                .font(.largeTitle)
                .fontWeight(.bold)

            if let tagline = movie.tmdbInfo?.tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            // Metadata row
            if let tmdb = movie.tmdbInfo {
                HStack(spacing: 24) {
                    if let releaseDate = tmdb.releaseDate {
                        Text(String(releaseDate.prefix(4)))
                            .foregroundStyle(.secondary)
                    }

                    if let rating = tmdb.formattedRating {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(rating)
                            if let votes = tmdb.voteCount, votes > 0 {
                                Text("(\(formatVoteCount(votes)) votes)")
                                    .foregroundStyle(.secondary)
                            }
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
                .font(.title3)

                // Genre tags
                if !tmdb.genres.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(tmdb.genres, id: \.self) { genre in
                            Text(genre)
                                .font(.callout)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.2))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Synopsis Section

    private func synopsisSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Synopsis")
                .font(.title2)
                .fontWeight(.semibold)

            Text(overview)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    // MARK: - Cast Section

    @ViewBuilder
    private var castSection: some View {
        if let tmdb = movie.tmdbInfo {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cast & Crew")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 12) {
                    if let director = tmdb.director {
                        HStack(spacing: 12) {
                            Text("Director:")
                                .foregroundStyle(.secondary)
                            Text(director)
                                .fontWeight(.medium)
                        }
                        .font(.title3)
                    }

                    if !tmdb.topCast.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Text("Cast:")
                                .foregroundStyle(.secondary)
                            Text(tmdb.topCast.joined(separator: ", "))
                        }
                        .font(.title3)
                    }
                }
            }
        }
    }

    // MARK: - Showtimes Section

    private var showtimesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Showtimes at Cinecenta")
                .font(.title2)
                .fontWeight(.semibold)

            ForEach(movie.showtimesByDate, id: \.date) { dateGroup in
                TVShowtimeDateGroup(date: dateGroup.date, showtimes: dateGroup.times)
            }
        }
    }

    // MARK: - Streaming Section

    private func streamingSection(_ availability: WatchAvailability) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Also Available On")
                .font(.title2)
                .fontWeight(.semibold)

            if availability.hasStreaming {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Streaming")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        ForEach(availability.streaming) { provider in
                            TVWatchProviderBadge(provider: provider)
                        }
                    }
                }
            }

            if !availability.rent.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rent")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        ForEach(availability.rent) { provider in
                            TVWatchProviderBadge(provider: provider)
                        }
                    }
                }
            }

            if !availability.buy.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Buy")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        ForEach(availability.buy) { provider in
                            TVWatchProviderBadge(provider: provider)
                        }
                    }
                }
            }

            Text("Streaming data provided by JustWatch")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private func formatVoteCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

/// Showtime group for tvOS
struct TVShowtimeDateGroup: View {
    let date: Date
    let showtimes: [Showtime]

    private var dateLabel: String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dateLabel)
                .font(.headline)

            HStack(spacing: 16) {
                ForEach(showtimes) { showtime in
                    TVShowtimeChip(showtime: showtime)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Showtime chip for tvOS
struct TVShowtimeChip: View {
    let showtime: Showtime

    private var isPast: Bool {
        showtime.startDate < Date()
    }

    var body: some View {
        Text(showtime.formattedTime)
            .font(.title3)
            .fontWeight(.medium)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isPast ? Color.secondary.opacity(0.3) : Color.blue)
            .foregroundStyle(isPast ? Color.secondary : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Watch provider badge for tvOS
struct TVWatchProviderBadge: View {
    let provider: WatchProvider

    var body: some View {
        VStack(spacing: 8) {
            if let logoURL = provider.logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure, .empty:
                        providerPlaceholder
                    @unknown default:
                        providerPlaceholder
                    }
                }
            } else {
                providerPlaceholder
            }

            Text(provider.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var providerPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 60, height: 60)
            .overlay {
                Image(systemName: provider.systemImageName)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}

/// Hero image component that maintains its own state to prevent reload on parent re-renders
struct TVHeroImage: View {
    let url: URL?
    let useBlur: Bool

    @State private var loadedImage: Image?
    @State private var isLoading = true

    var body: some View {
        ZStack(alignment: .bottom) {
            // Image or placeholder
            if let image = loadedImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 600)
                    .clipped()
                    .blur(radius: useBlur ? 20 : 0)
                    .overlay(useBlur ? Color.black.opacity(0.3) : Color.clear)
            } else if isLoading {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 600)
                    .overlay {
                        ProgressView()
                    }
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 600)
                    .overlay {
                        Image(systemName: "film")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                    }
            }

            // Gradient overlay for text readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 600)
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = url else {
            isLoading = false
            return
        }

        isLoading = true

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            #if os(tvOS)
            if let uiImage = UIImage(data: data) {
                loadedImage = Image(uiImage: uiImage)
            }
            #endif
        } catch {
            print("Failed to load hero image: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    TVMovieDetailView(movie: Movie(
        title: "Sample Movie",
        imageURL: nil,
        showtimes: [
            Showtime(startDate: Date().addingTimeInterval(3600)),
            Showtime(startDate: Date().addingTimeInterval(7200)),
            Showtime(startDate: Date().addingTimeInterval(86400))
        ]
    ))
}

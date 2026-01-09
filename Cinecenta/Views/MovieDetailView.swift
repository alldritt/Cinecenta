import SwiftUI
import YouTubePlayerKit

/// Detail view showing all showtimes for a movie
struct MovieDetailView: View {
    let movie: Movie
    private var notificationManager: NotificationManager { .shared }
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                if movie.tmdbInfo != nil {
                    movieInfoSection
                    trailerSection
                    if movie.tmdbInfo?.overview != nil {
                        synopsisSection
                    }
                    if !(movie.tmdbInfo?.topCast.isEmpty ?? true) {
                        castSection
                    }
                }
                showtimesSection
            }
            .padding()
        }
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    private var shareText: String {
        var text = "\(movie.title) at Cinecenta\n\n"

        for dateGroup in movie.showtimesByDate {
            let dateLabel: String
            if Calendar.current.isDateInToday(dateGroup.date) {
                dateLabel = "Today"
            } else if Calendar.current.isDateInTomorrow(dateGroup.date) {
                dateLabel = "Tomorrow"
            } else {
                dateLabel = dateGroup.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            }

            let times = dateGroup.times.map { $0.formattedTime }.joined(separator: ", ")
            text += "\(dateLabel): \(times)\n"
        }

        text += "\nhttps://www.cinecenta.com"
        return text
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Use backdrop if available, otherwise poster
            if let backdropURL = movie.backdropURL {
                AsyncImage(url: backdropURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        posterFallback
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                    @unknown default:
                        posterFallback
                    }
                }
            } else {
                posterFallback
            }

            // Title and tagline
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.title)
                    .fontWeight(.bold)

                if let tagline = movie.tmdbInfo?.tagline, !tagline.isEmpty {
                    Text(tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
    }

    @ViewBuilder
    private var posterFallback: some View {
        if let imageURL = movie.bestPosterURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure:
                    headerPlaceholder
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                @unknown default:
                    headerPlaceholder
                }
            }
        } else {
            headerPlaceholder
        }
    }

    private var headerPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary)
            .frame(height: 200)
            .overlay {
                Image(systemName: "film")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Movie Info Section

    @ViewBuilder
    private var movieInfoSection: some View {
        if let tmdb = movie.tmdbInfo {
            VStack(alignment: .leading, spacing: 12) {
                // Rating, Runtime, Genres row
                HStack(spacing: 16) {
                    if let rating = tmdb.formattedRating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(rating)
                                .fontWeight(.semibold)
                            if let votes = tmdb.voteCount, votes > 0 {
                                Text("(\(formatVoteCount(votes)))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let runtime = tmdb.formattedRuntime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(runtime)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)

                // Genre tags
                if !tmdb.genres.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(tmdb.genres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Trailer Section

    @ViewBuilder
    private var trailerSection: some View {
        if let trailerURL = movie.tmdbInfo?.trailerURL,
           let videoID = YouTubeHelper.extractVideoID(from: trailerURL) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Trailer")
                    .font(.title3)
                    .fontWeight(.semibold)

                YouTubePlayerView(
                    YouTubePlayer(source: .video(id: videoID))
                )
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func formatVoteCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }

    // MARK: - Synopsis Section

    @ViewBuilder
    private var synopsisSection: some View {
        if let overview = movie.tmdbInfo?.overview, !overview.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Synopsis")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(overview)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Cast Section

    @ViewBuilder
    private var castSection: some View {
        if let tmdb = movie.tmdbInfo {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cast & Crew")
                    .font(.title3)
                    .fontWeight(.semibold)

                if let director = tmdb.director {
                    HStack {
                        Text("Director:")
                            .foregroundStyle(.secondary)
                        Text(director)
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                }

                if !tmdb.topCast.isEmpty {
                    HStack(alignment: .top) {
                        Text("Cast:")
                            .foregroundStyle(.secondary)
                        Text(tmdb.topCast.joined(separator: ", "))
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private var showtimesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Showtimes")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Image(systemName: "bell.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("Tap time to set reminder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(movie.showtimesByDate, id: \.date) { dateGroup in
                ShowtimeDateGroup(
                    movie: movie,
                    date: dateGroup.date,
                    showtimes: dateGroup.times,
                    currentTime: currentTime
                )
            }
        }
    }
}

/// Groups showtimes by date with a header
struct ShowtimeDateGroup: View {
    let movie: Movie
    let date: Date
    let showtimes: [Showtime]
    let currentTime: Date
    private var notificationManager: NotificationManager { .shared }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(date)
    }

    private var dateLabel: String {
        if isToday {
            return "Today"
        } else if isTomorrow {
            return "Tomorrow"
        } else {
            return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dateLabel)
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(showtimes) { showtime in
                    ShowtimeChip(movie: movie, showtime: showtime, currentTime: currentTime)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Individual showtime display chip with reminder functionality
struct ShowtimeChip: View {
    let movie: Movie
    let showtime: Showtime
    let currentTime: Date
    private var notificationManager: NotificationManager { .shared }
    @State private var showingReminderSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    private var isPast: Bool {
        showtime.startDate < currentTime
    }

    private var hasReminder: Bool {
        notificationManager.hasReminder(movieTitle: movie.title, showtime: showtime)
    }

    var body: some View {
        Button {
            if isPast {
                return
            }
            if hasReminder {
                // Cancel existing reminder
                notificationManager.cancelReminder(movieTitle: movie.title, showtime: showtime)
            } else {
                showingReminderSheet = true
            }
        } label: {
            HStack(spacing: 6) {
                Text(showtime.formattedTime)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if hasReminder {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(chipBackground)
            .foregroundStyle(chipForeground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(isPast)
        .sheet(isPresented: $showingReminderSheet) {
            ReminderSelectionSheet(
                movie: movie,
                showtime: showtime,
                onSelect: { reminderTime in
                    Task {
                        let success = await notificationManager.scheduleReminder(
                            for: movie,
                            showtime: showtime,
                            minutesBefore: reminderTime.rawValue
                        )
                        if !success {
                            alertMessage = "Could not set reminder. The showtime may be too soon or notifications are disabled."
                            showingAlert = true
                        }
                    }
                }
            )
            .presentationDetents([.height(280)])
        }
        .alert("Reminder Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var chipBackground: Color {
        if isPast {
            return Color.secondary.opacity(0.3)
        } else if hasReminder {
            return Color.orange
        } else {
            return Color.blue
        }
    }

    private var chipForeground: Color {
        isPast ? Color.secondary : Color.white
    }
}

/// Sheet for selecting reminder time
struct ReminderSelectionSheet: View {
    let movie: Movie
    let showtime: Showtime
    let onSelect: (ReminderTime) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header with drag indicator and close button
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(.blue)

                Spacer()

                Text("Set Reminder")
                    .font(.headline)

                Spacer()

                // Invisible button to balance the layout
                Button("Cancel") { }
                    .opacity(0)
            }
            .padding()

            // Movie info
            VStack(spacing: 4) {
                Text(movie.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(showtime.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            // Reminder options
            VStack(spacing: 10) {
                ForEach(ReminderTime.allCases) { time in
                    let reminderDate = showtime.startDate.addingTimeInterval(-Double(time.rawValue * 60))
                    let isValid = reminderDate > Date()

                    Button {
                        onSelect(time)
                        dismiss()
                    } label: {
                        HStack {
                            Text(time.displayName)
                                .fontWeight(.medium)
                            Spacer()
                            if isValid {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Too late")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.5)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}

/// A simple flow layout for wrapping content
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(movie: Movie(
            title: "Sample Movie",
            imageURL: nil,
            showtimes: [
                Showtime(startDate: Date().addingTimeInterval(3600), endDate: nil),
                Showtime(startDate: Date().addingTimeInterval(7200), endDate: nil),
                Showtime(startDate: Date().addingTimeInterval(86400), endDate: nil)
            ]
        ))
    }
}

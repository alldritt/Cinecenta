import SwiftUI

@main
struct CinecentaTVApp: App {
    @State private var selectedMovieID: UUID?

    var body: some Scene {
        WindowGroup {
            TVMovieListView(selectedMovieID: $selectedMovieID)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Handle cinecenta://movie/{uuid} URLs
        guard url.scheme == "cinecenta",
              url.host == "movie",
              let movieIDString = url.pathComponents.last,
              let movieID = UUID(uuidString: movieIDString) else {
            return
        }

        selectedMovieID = movieID
    }
}

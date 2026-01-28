import SwiftUI
import BackgroundTasks

/// App delegate for handling app lifecycle events
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
        return true
    }
}

@main
struct CinecentaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedMovieTitle: String?

    var body: some Scene {
        WindowGroup {
            MovieListView(selectedMovieTitle: $selectedMovieTitle)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Schedule background refresh when app goes to background
                BackgroundTaskManager.shared.scheduleAppRefresh()
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "cinecenta",
              url.host == "movie",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let titleItem = components.queryItems?.first(where: { $0.name == "title" }),
              let title = titleItem.value else {
            return
        }
        selectedMovieTitle = title
    }
}

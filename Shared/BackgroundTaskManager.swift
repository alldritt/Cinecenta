import Foundation
import BackgroundTasks
import WidgetKit

/// Manages background app refresh for keeping movie data current
@MainActor
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    private let backgroundTaskIdentifier = "com.latenightsw.Cinecenta.refresh"
    private let service = CinecentaService()

    private init() {}

    /// Register background task handlers - call from app delegate or app init
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    /// Schedule the next background refresh
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        // Request refresh no earlier than 30 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    /// Handle the background refresh task
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleAppRefresh()

        // Create a task to fetch data
        let fetchTask = Task {
            do {
                _ = try await service.refreshMovies()
                // Reload widget timelines to show fresh data
                WidgetCenter.shared.reloadAllTimelines()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        // Handle task expiration
        task.expirationHandler = {
            fetchTask.cancel()
        }
    }

    /// Perform a manual refresh (for pull-to-refresh or app foreground)
    func performManualRefresh() async {
        do {
            _ = try await service.refreshMovies()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Manual refresh failed: \(error)")
        }
    }
}

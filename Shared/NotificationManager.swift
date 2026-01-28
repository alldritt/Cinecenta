import Foundation
import UserNotifications

/// Manages local notifications for movie showtime reminders
@MainActor
@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    private(set) var isAuthorized = false
    private(set) var pendingReminders: Set<String> = []

    private let center = UNUserNotificationCenter.current()

    private init() {
        Task {
            await checkAuthorizationStatus()
            await loadPendingReminders()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Scheduling

    /// Schedule a reminder for a movie showtime
    /// - Parameters:
    ///   - movie: The movie to remind about
    ///   - showtime: The specific showtime
    ///   - minutesBefore: How many minutes before the showtime to send the reminder
    func scheduleReminder(for movie: Movie, showtime: Showtime, minutesBefore: Int) async -> Bool {
        if !isAuthorized {
            let granted = await requestAuthorization()
            if !granted { return false }
        }

        let identifier = reminderIdentifier(movieTitle: movie.title, showtime: showtime)

        // Calculate notification time
        let reminderDate = showtime.startDate.addingTimeInterval(-Double(minutesBefore * 60))

        // Don't schedule if the reminder time has already passed
        guard reminderDate > Date() else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Movie Reminder"
        content.body = "\(movie.title) starts in \(minutesBefore) minutes at Cinecenta"
        content.sound = .default
        content.userInfo = [
            "movieTitle": movie.title,
            "showtimeId": showtime.id.uuidString
        ]

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            pendingReminders.insert(identifier)
            return true
        } catch {
            print("Failed to schedule notification: \(error)")
            return false
        }
    }

    /// Cancel a reminder for a specific showtime
    func cancelReminder(movieTitle: String, showtime: Showtime) {
        let identifier = reminderIdentifier(movieTitle: movieTitle, showtime: showtime)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        pendingReminders.remove(identifier)
    }

    /// Cancel all reminders for a movie
    func cancelAllReminders(for movieTitle: String) {
        let identifiersToRemove = pendingReminders.filter { $0.hasPrefix("cinecenta_\(movieTitle)_") }
        center.removePendingNotificationRequests(withIdentifiers: Array(identifiersToRemove))
        pendingReminders.subtract(identifiersToRemove)
    }

    /// Check if a reminder is set for a specific showtime
    func hasReminder(movieTitle: String, showtime: Showtime) -> Bool {
        let identifier = reminderIdentifier(movieTitle: movieTitle, showtime: showtime)
        return pendingReminders.contains(identifier)
    }

    // MARK: - Private Helpers

    private func reminderIdentifier(movieTitle: String, showtime: Showtime) -> String {
        // Use date-based identifier so it's consistent across app launches
        // (showtime.id is regenerated each time data is fetched)
        let timestamp = Int(showtime.startDate.timeIntervalSince1970)
        return "cinecenta_\(movieTitle)_\(timestamp)"
    }

    private func loadPendingReminders() async {
        let requests = await center.pendingNotificationRequests()
        let cinecentaReminders = requests
            .filter { $0.identifier.hasPrefix("cinecenta_") }
            .map { $0.identifier }
        pendingReminders = Set(cinecentaReminders)
    }
}

// MARK: - Reminder Options

enum ReminderTime: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .fifteenMinutes: return "15 minutes before"
        case .thirtyMinutes: return "30 minutes before"
        case .oneHour: return "1 hour before"
        case .twoHours: return "2 hours before"
        }
    }

    var shortName: String {
        switch self {
        case .fifteenMinutes: return "15 min"
        case .thirtyMinutes: return "30 min"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        }
    }
}

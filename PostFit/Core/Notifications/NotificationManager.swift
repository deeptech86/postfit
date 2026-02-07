//
//  NotificationManager.swift
//  PostFit
//
//  Created by Claude Code
//

import Foundation
import UserNotifications
import SwiftUI

// MARK: - Notification Frequency
enum NotificationFrequency: String, CaseIterable, Codable {
    case daily = "Daily"
    case everyOtherDay = "Every Other Day"
    case threeTimesWeek = "3 Times a Week"
    case weekly = "Weekly"

    var intervalDays: Int {
        switch self {
        case .daily: return 1
        case .everyOtherDay: return 2
        case .threeTimesWeek: return 2 // Approximate
        case .weekly: return 7
        }
    }
}

// MARK: - Hydration Frequency (Hourly-based)
enum HydrationFrequency: String, CaseIterable, Codable {
    case everyHour = "Every Hour"
    case everyTwoHours = "Every 2 Hours"
    case everySixHours = "Every 6 Hours"
    case everyTwelveHours = "Every 12 Hours"

    var intervalMinutes: Int {
        switch self {
        case .everyHour: return 60
        case .everyTwoHours: return 120
        case .everySixHours: return 360
        case .everyTwelveHours: return 720
        }
    }
}

// MARK: - Notification Duration
enum NotificationDuration: String, CaseIterable, Codable {
    case oneWeek = "1 Week"
    case twoWeeks = "2 Weeks"
    case oneMonth = "1 Month"
    case threeMonths = "3 Months"
    case ongoing = "Ongoing"

    var days: Int? {
        switch self {
        case .oneWeek: return 7
        case .twoWeeks: return 14
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .ongoing: return nil
        }
    }
}

// MARK: - Notification Settings
struct NotificationSettings: Codable {
    var exerciseEnabled: Bool = false
    var exerciseTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var exerciseFrequency: NotificationFrequency = .daily
    var exerciseDuration: NotificationDuration = .ongoing

    var hydrationEnabled: Bool = false
    var hydrationTime: Date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    var hydrationFrequency: HydrationFrequency = .everyTwoHours
    var hydrationDuration: NotificationDuration = .ongoing

    var mealEnabled: Bool = false
    var mealTime: Date = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
    var mealFrequency: NotificationFrequency = .daily
    var mealDuration: NotificationDuration = .ongoing

    var sleepEnabled: Bool = false
    var sleepTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    var sleepFrequency: NotificationFrequency = .daily
    var sleepDuration: NotificationDuration = .ongoing

    var dailyCheckInEnabled: Bool = false
    var dailyCheckInTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
}

// MARK: - Notification Manager
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var settings = NotificationSettings()

    private let center = UNUserNotificationCenter.current()
    private let settingsKey = "NotificationSettings"

    private init() {
        loadSettings()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("❌ [Notifications] Authorization error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        Task {
            let settings = await center.notificationSettings()
            await MainActor.run {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    // MARK: - Settings Persistence
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            settings = decoded
        }
    }

    // MARK: - Schedule Notifications
    func scheduleAllNotifications() async {
        // Cancel all existing notifications first
        center.removeAllPendingNotificationRequests()

        // Schedule each type if enabled
        if settings.exerciseEnabled {
            await scheduleNotification(
                identifier: "exercise",
                title: "Time for Exercise! 💪",
                body: "Let's do some gentle movement today. Your body will thank you!",
                time: settings.exerciseTime,
                frequency: settings.exerciseFrequency,
                duration: settings.exerciseDuration
            )
        }

        if settings.hydrationEnabled {
            await scheduleHydrationNotifications(
                startTime: settings.hydrationTime,
                frequency: settings.hydrationFrequency,
                duration: settings.hydrationDuration
            )
        }

        if settings.mealEnabled {
            await scheduleNotification(
                identifier: "meal",
                title: "Meal Tracking Reminder 🍎",
                body: "Don't forget to log your meals today!",
                time: settings.mealTime,
                frequency: settings.mealFrequency,
                duration: settings.mealDuration
            )
        }

        if settings.sleepEnabled {
            await scheduleNotification(
                identifier: "sleep",
                title: "Wind Down Time 🌙",
                body: "Start preparing for bed. Quality sleep aids recovery!",
                time: settings.sleepTime,
                frequency: settings.sleepFrequency,
                duration: settings.sleepDuration
            )
        }

        if settings.dailyCheckInEnabled {
            await scheduleNotification(
                identifier: "dailyCheckIn",
                title: "Daily Check-in 📝",
                body: "How are you feeling today? Log your wellness check-in!",
                time: settings.dailyCheckInTime,
                frequency: .daily,
                duration: .ongoing
            )
        }
    }

    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        time: Date,
        frequency: NotificationFrequency,
        duration: NotificationDuration
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1

        // Extract hour and minute from time
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)

        // Create date components for scheduling
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        // Handle frequency
        switch frequency {
        case .daily:
            // Repeat daily
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
                print("✅ [Notifications] Scheduled \(identifier) daily at \(hour):\(minute)")
            } catch {
                print("❌ [Notifications] Error scheduling \(identifier): \(error)")
            }

        case .everyOtherDay, .threeTimesWeek:
            // Schedule for specific weekdays
            let weekdays: [Int] = frequency == .everyOtherDay
                ? [1, 3, 5, 7] // Mon, Wed, Fri, Sun
                : [1, 3, 5] // Mon, Wed, Fri

            for weekday in weekdays {
                var components = dateComponents
                components.weekday = weekday

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(identifier)_\(weekday)",
                    content: content,
                    trigger: trigger
                )

                do {
                    try await center.add(request)
                } catch {
                    print("❌ [Notifications] Error scheduling \(identifier): \(error)")
                }
            }

        case .weekly:
            // Schedule for Mondays
            dateComponents.weekday = 2 // Monday
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
                print("✅ [Notifications] Scheduled \(identifier) weekly")
            } catch {
                print("❌ [Notifications] Error scheduling \(identifier): \(error)")
            }
        }

        // Note: Duration is tracked via start date in UserDefaults
        // We'll check duration when the notification fires
        if let durationDays = duration.days {
            let startDateKey = "\(identifier)_startDate"
            if UserDefaults.standard.object(forKey: startDateKey) == nil {
                UserDefaults.standard.set(Date(), forKey: startDateKey)
            }
        }
    }

    // MARK: - Schedule Hydration Notifications (Hourly)
    private func scheduleHydrationNotifications(
        startTime: Date,
        frequency: HydrationFrequency,
        duration: NotificationDuration
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Stay Hydrated! 💧"
        content.body = "Remember to drink water. Hydration is key for recovery!"
        content.sound = .default
        content.badge = 1

        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let intervalHours = frequency.intervalMinutes / 60

        // Create notifications throughout the day based on frequency
        // Start from the chosen start time and repeat at intervals
        var notificationCount = 0

        switch frequency {
        case .everyHour:
            // Schedule 12 notifications throughout the day (e.g., 8am-8pm)
            notificationCount = 12
        case .everyTwoHours:
            // Schedule 6 notifications throughout the day
            notificationCount = 6
        case .everySixHours:
            // Schedule 4 notifications throughout the day
            notificationCount = 4
        case .everyTwelveHours:
            // Schedule 2 notifications throughout the day
            notificationCount = 2
        }

        for i in 0..<notificationCount {
            let hourOffset = i * intervalHours
            var triggerHour = (startHour + hourOffset) % 24

            var dateComponents = DateComponents()
            dateComponents.hour = triggerHour
            dateComponents.minute = startMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "hydration_\(i)",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                print("✅ [Notifications] Scheduled hydration reminder \(i + 1) at \(triggerHour):\(String(format: "%02d", startMinute))")
            } catch {
                print("❌ [Notifications] Error scheduling hydration \(i): \(error)")
            }
        }

        // Track duration
        if let durationDays = duration.days {
            let startDateKey = "hydration_startDate"
            if UserDefaults.standard.object(forKey: startDateKey) == nil {
                UserDefaults.standard.set(Date(), forKey: startDateKey)
            }
        }
    }

    // MARK: - Cancel Notifications
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Also remove weekday variants
        let weekdays = [1, 2, 3, 4, 5, 6, 7]
        let identifiers = weekdays.map { "\(identifier)_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        print("🗑️ [Notifications] Cancelled \(identifier)")
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        print("🗑️ [Notifications] Cancelled all notifications")
    }

    // MARK: - Get Pending Notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
}

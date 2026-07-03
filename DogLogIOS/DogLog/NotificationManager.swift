import Foundation
import UserNotifications
import SwiftData

// MARK: - Notification Manager
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var hasPermission = false
    @Published var morningForecastEnabled = true
    @Published var morningForecastTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @Published var useLocalAIForNotifications = true // Default to local AI (free)
    @Published var reminderNotificationsEnabled = true
    @Published var progressReportsEnabled = true
    
    private let userDefaults = UserDefaults.standard
    private let predictiveAnalyzer = PredictiveAnalyzer()
    
    // UserDefaults keys
    private let morningForecastEnabledKey = "morningForecastEnabled"
    private let morningForecastTimeKey = "morningForecastTime"
    private let useLocalAIForNotificationsKey = "useLocalAIForNotifications"
    private let reminderNotificationsEnabledKey = "reminderNotificationsEnabled"
    private let progressReportsEnabledKey = "progressReportsEnabled"
    
    init() {
        loadSettings()
        checkPermission()
    }
    
    // MARK: - Permission Management
    
    func requestPermission() async -> Bool {
        do {
            DogLogLogger.notifications.info("Requesting notification permission")
            // Request permissions in the most explicit way possible
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]  // Remove .provisional to force explicit choice
            )
            
            DogLogLogger.notifications.info("Notification permission granted: \(granted, privacy: .public)")
            
            await MainActor.run {
                self.hasPermission = granted
            }
            
            if granted {
                DogLogLogger.notifications.debug("Permission granted; checking settings and scheduling")
                await checkAndPromptForOptimalSettings()
                await scheduleAllNotifications()
            }
            
            return granted
        } catch {
            DogLogLogger.notifications.error("Error requesting notification permission: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    func checkAndPromptForOptimalSettings() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        DogLogLogger.notifications.debug("Alert style: \(settings.alertStyle.rawValue, privacy: .public); lock screen: \(settings.lockScreenSetting.rawValue, privacy: .public)")
        
        // Check if we have optimal settings
        let hasBanners = settings.alertStyle == .banner || settings.alertStyle == .alert
        let hasLockScreen = settings.lockScreenSetting == .enabled
        let hasNotificationCenter = settings.notificationCenterSetting == .enabled
        
        if !hasBanners || !hasLockScreen || !hasNotificationCenter {
            DogLogLogger.notifications.warning("Suboptimal notification settings detected")
            
            await MainActor.run {
                // Post notification to show settings prompt
                NotificationCenter.default.post(name: .showNotificationSettingsPrompt, object: nil)
            }
        } else {
            DogLogLogger.notifications.debug("Optimal notification settings detected")
        }
    }
    
    func checkPermission() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                self.hasPermission = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        // Preserve sensible defaults when keys are missing (first run)
        if userDefaults.object(forKey: morningForecastEnabledKey) != nil {
            morningForecastEnabled = userDefaults.bool(forKey: morningForecastEnabledKey)
        }
        useLocalAIForNotifications = userDefaults.object(forKey: useLocalAIForNotificationsKey) as? Bool ?? true // Default to true (local AI)
        if userDefaults.object(forKey: reminderNotificationsEnabledKey) != nil {
            reminderNotificationsEnabled = userDefaults.bool(forKey: reminderNotificationsEnabledKey)
        }
        if userDefaults.object(forKey: progressReportsEnabledKey) != nil {
            progressReportsEnabled = userDefaults.bool(forKey: progressReportsEnabledKey)
        }
        
        if let timeData = userDefaults.data(forKey: morningForecastTimeKey),
           let time = try? JSONDecoder().decode(Date.self, from: timeData) {
            morningForecastTime = time
        }
    }
    
    func saveSettings() {
        userDefaults.set(morningForecastEnabled, forKey: morningForecastEnabledKey)
        userDefaults.set(useLocalAIForNotifications, forKey: useLocalAIForNotificationsKey)
        userDefaults.set(reminderNotificationsEnabled, forKey: reminderNotificationsEnabledKey)
        userDefaults.set(progressReportsEnabled, forKey: progressReportsEnabledKey)
        
        if let timeData = try? JSONEncoder().encode(morningForecastTime) {
            userDefaults.set(timeData, forKey: morningForecastTimeKey)
        }
        
        // Notify that settings changed so ContentView can reschedule notifications
        NotificationCenter.default.post(name: .notificationSettingsChanged, object: nil)
        
        Task {
            await scheduleAllNotifications()
        }
    }
    
    // MARK: - Morning Forecast Notifications
    
    func scheduleMorningForecast(for dogs: [Dog]) async {
        guard hasPermission && morningForecastEnabled else { return }
        
        // Remove existing morning forecast notifications
        let existingIds = await getScheduledNotificationIds()
        let forecastIds = existingIds.filter { $0.hasPrefix("morning_forecast_") }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: forecastIds)
        
        // Schedule new notifications for each dog
        for dog in dogs {
            await scheduleMorningForecastForDog(dog)
        }
    }
    
    private func scheduleMorningForecastForDog(_ dog: Dog) async {
        guard let dogId = dog.id.uuidString as String? else { return }

        // Build a lightweight, generic notification that repeats daily.
        // The detailed forecast is generated when the user opens the app via userInfo.
        let content = UNMutableNotificationContent()
        content.title = String(format: "notifications.morning_forecast_sample".localized, dog.name)
        content.subtitle = ""
        content.body = "notifications.morning_forecast".localized
        content.sound = .default
        content.badge = 1

        // Minimal data for in-app handling
        content.userInfo = [
            "type": "morning_forecast",
            "dogId": dogId
        ]

        // Common actions
        let viewForecastAction = UNNotificationAction(
            identifier: "view_forecast",
            title: "notifications.action.open_full_analysis".localized,
            options: [.foreground]
        )
        let logQuickAction = UNNotificationAction(
            identifier: "quick_log",
            title: "notifications.action.quick_log_today".localized,
            options: [.foreground]
        )
        let viewDetailsAction = UNNotificationAction(
            identifier: "view_details",
            title: "notifications.action.read_full_message".localized,
            options: [.foreground]
        )
        let categoryId = "morning_forecast_generic"
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [viewForecastAction, viewDetailsAction, logQuickAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = categoryId

        // Daily repeating at selected hour/minute
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: morningForecastTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "morning_forecast_\(dogId)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            DogLogLogger.notifications.info("Scheduled daily morning forecast for \(dog.name ?? "dog", privacy: .public) at \(self.formatTime(morningForecastTime), privacy: .public)")
        } catch {
            DogLogLogger.notifications.error("Error scheduling morning forecast: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func scheduleGenericCheckIn(for dog: Dog) async {
        guard let dogId = dog.id.uuidString as String? else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🐕 Good morning from Barkley!"
        content.body = "How is \(dog.name) doing today? Let's log some activities!"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "generic_checkin",
            "dogId": dogId
        ]
        
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: morningForecastTime)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: timeComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "generic_checkin_\(dogId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            DogLogLogger.notifications.error("Error scheduling generic check-in: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Reminder Notifications
    
    func scheduleActivityReminder(for dog: Dog, delay: TimeInterval = 3600) async { // Default 1 hour
        guard hasPermission && reminderNotificationsEnabled else { return }
        guard let dogId = dog.id.uuidString as String? else { return }
        
        // Check if user has logged today
        let today = DateFormatter.dayFormatter.string(from: Date())
        let todayActivities = dog.activities.filter { activity in
            DateFormatter.dayFormatter.string(from: activity.date) == today
        }
        
        guard todayActivities.isEmpty else { return } // Already logged today
        
        let content = UNMutableNotificationContent()
        content.title = "📝 Don't forget to log!"
        content.body = "How has \(dog.name)'s day been? Quick log helps Barkley!"
        content.sound = .default
        
        content.userInfo = [
            "type": "activity_reminder",
            "dogId": dogId
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "activity_reminder_\(dogId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            DogLogLogger.notifications.error("Error scheduling activity reminder: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Progress Report Notifications
    
    func scheduleWeeklyProgressReport(for dog: Dog) async {
        guard hasPermission && progressReportsEnabled else { return }
        guard let dogId = dog.id.uuidString as String? else { return }
        
        // Check if we have enough data for a meaningful report
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentData = dog.activities.filter { $0.date >= oneWeekAgo }
        
        guard recentData.count >= 3 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📊 Weekly Progress Report"
        content.body = "Barkley found interesting patterns for \(dog.name)!"
        content.sound = .default
        
        content.userInfo = [
            "type": "progress_report",
            "dogId": dogId,
            "dataPoints": recentData.count
        ]
        
        // Schedule for Sunday evening
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 19 // 7 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "weekly_progress_\(dogId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            DogLogLogger.notifications.error("Error scheduling weekly progress report: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Test Functions
    
    func scheduleTestNotification(for dog: Dog, delay: TimeInterval = 5.0) async {
        guard hasPermission else { return }
        guard let dogId = dog.id.uuidString as String? else { return }
        
        // Generate a real forecast for testing
        if let forecast = predictiveAnalyzer.generateMorningForecast(for: dog, date: Date()) {
            let content = UNMutableNotificationContent()
            content.title = "🧪 Test: Morning Forecast for \(dog.name)"
            content.subtitle = "\(forecast.overallPrediction.displayName) - \(Int(forecast.confidenceLevel * 100))% confidence"
            content.body = forecast.personalizedMessage
            content.sound = .default
            content.badge = 1
            
            content.userInfo = [
                "type": "test_forecast",
                "dogId": dogId,
                "prediction": forecast.overallPrediction.rawValue,
                "confidence": forecast.confidenceLevel
            ]
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "test_forecast_\(dogId)_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                DogLogLogger.notifications.info("Scheduled test forecast for \(dog.name ?? "dog", privacy: .public) in \(delay, privacy: .public)s")
                #if DEBUG
                DogLogLogger.notifications.debug("Test forecast message length: \(forecast.personalizedMessage.count, privacy: .public) chars")
                #endif
            } catch {
                DogLogLogger.notifications.error("Error scheduling test notification: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            // Fallback if no forecast can be generated
            let content = UNMutableNotificationContent()
            content.title = "🧪 Test for \(dog.name)"
            content.body = "Not enough data for forecast yet. Keep logging activities! - Barkley"
            content.sound = .default
            content.badge = 1
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: "test_forecast_\(dogId)_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                DogLogLogger.notifications.info("Scheduled fallback test for \(dog.name ?? "dog", privacy: .public)")
            } catch {
                DogLogLogger.notifications.error("Error scheduling test notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func scheduleAllNotifications() async {
        // This would typically get dogs from the data context
        // For now, we'll handle this in the main app where we have access to the model context
        DogLogLogger.notifications.debug("Scheduling all notifications")
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func printScheduledNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        DogLogLogger.notifications.debug("Currently scheduled notifications: \(requests.count, privacy: .public)")
        for request in requests {
            let identifier = request.identifier
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                DogLogLogger.notifications.debug("  \(identifier, privacy: .public): calendar trigger")
            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                DogLogLogger.notifications.debug("  \(identifier, privacy: .public): in \(trigger.timeInterval, privacy: .public)s")
            } else {
                DogLogLogger.notifications.debug("  \(identifier, privacy: .public): unknown trigger")
            }
        }
    }
    
    func cancelNotificationsForDog(_ dogId: UUID) {
        Task {
            let existingIds = await getScheduledNotificationIds()
            let dogNotificationIds = existingIds.filter { $0.contains(dogId.uuidString) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: dogNotificationIds)
        }
    }
    
    private func getScheduledNotificationIds() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.map { $0.identifier }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Notification Handling
    
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "view_forecast":
            // Navigate to forecast view
            NotificationCenter.default.post(
                name: .showMorningForecast,
                object: nil,
                userInfo: userInfo
            )
            
        case "view_details":
            // Show full notification message
            NotificationCenter.default.post(
                name: .showNotificationDetails,
                object: nil,
                userInfo: ["message": response.notification.request.content.body]
            )
            
        case "quick_log":
            // Navigate to quick logging
            NotificationCenter.default.post(
                name: .showQuickLog,
                object: nil,
                userInfo: userInfo
            )
            
        case UNNotificationDefaultActionIdentifier:
            // Default tap - navigate to appropriate screen based on type
            if let type = userInfo["type"] as? String {
                switch type {
                case "morning_forecast", "generic_checkin", "test_forecast":
                    NotificationCenter.default.post(
                        name: .showMorningForecast,
                        object: nil,
                        userInfo: userInfo
                    )
                case "activity_reminder":
                    NotificationCenter.default.post(
                        name: .showDailyLog,
                        object: nil,
                        userInfo: userInfo
                    )
                case "progress_report":
                    NotificationCenter.default.post(
                        name: .showProgressReport,
                        object: nil,
                        userInfo: userInfo
                    )
                default:
                    break
                }
            }
            
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showMorningForecast = Notification.Name("showMorningForecast")
    static let showQuickLog = Notification.Name("showQuickLog")
    static let showDailyLog = Notification.Name("showDailyLog")
    static let showProgressReport = Notification.Name("showProgressReport")
    static let notificationSettingsChanged = Notification.Name("notificationSettingsChanged")
    static let showNotificationSettingsPrompt = Notification.Name("showNotificationSettingsPrompt")
    static let showNotificationDetails = Notification.Name("showNotificationDetails")
    static let showChatGPTSettings = Notification.Name("showChatGPTSettings")
    static let chatGPTAPIKeyChanged = Notification.Name("chatGPTAPIKeyChanged")
}


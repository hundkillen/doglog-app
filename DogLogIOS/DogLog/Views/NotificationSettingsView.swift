import SwiftUI
import SwiftData
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Dog.name) private var dogs: [Dog]
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Permission status section
                Section {
                    PermissionStatusView(
                        hasPermission: notificationManager.hasPermission,
                        onRequestPermission: requestPermission
                    )
                }
                
                if notificationManager.hasPermission {
                    // Morning forecast settings
                    Section {
                        MorningForecastSettingsView()
                    } header: {
                        Label("notifications.morning_forecasts".localized, systemImage: "sunrise.fill")
                    } footer: {
                        Text("notifications.morning_forecast".localized)
                    }
                    
                    // Reminder settings
                    Section {
                        ReminderSettingsView()
                    } header: {
                        Label("notifications.activity_reminders".localized, systemImage: "bell.fill")
                    } footer: {
                        Text("notifications.activity_reminders".localized)
                    }
                    
                    // Progress report settings
                    Section {
                        ProgressReportSettingsView()
                    } header: {
                        Label("notifications.progress_reports".localized, systemImage: "chart.bar.fill")
                    } footer: {
                        Text("notifications.weekly_summaries".localized)
                    }
                    
                    // Testing section (hidden for production)
                    // Toggle back on when needed for development
                    /*
                    Section {
                        QuickActionsView(dogs: dogs)
                    } header: {
                        Label("notifications.testing".localized, systemImage: "hammer.fill")
                    } footer: {
                        Text("notifications.test_note".localized)
                    }
                    */
                    
                    // ChatGPT API Settings
                    Section {
                        ChatGPTSettingsView()
                    } header: {
                        Label("notifications.chatgpt_integration".localized, systemImage: "brain.head.profile")
                    } footer: {
                        Text("notifications.chatgpt_note".localized)
                    }
                }
            }
            .navigationTitle("settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        notificationManager.saveSettings()
                        dismiss()
                    }
                }
            })
        }
        .alert("notifications.disabled".localized, isPresented: $showingPermissionAlert) {
            Button("settings.title".localized) {
                openSystemSettings()
            }
            Button("common.cancel".localized, role: .cancel) { }
        } message: {
            Text("notifications.enable_message".localized)
        }
    }
    
    private func requestPermission() {
        Task {
            let granted = await notificationManager.requestPermission()
            if !granted {
                await MainActor.run {
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func openSystemSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Permission Status View

struct PermissionStatusView: View {
    let hasPermission: Bool
    let onRequestPermission: () -> Void
    @State private var showingOptimizationInfo = true  // Start expanded
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("notifications.permission".localized)
                        .font(.headline)
                    
                    Text(hasPermission ? "common.enabled".localized : "common.disabled".localized)
                    .font(.subheadline)
                    .foregroundColor(hasPermission ? .green : .red)
            }
            
            Spacer()
            
            if hasPermission {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("common.enable".localized) {
                    onRequestPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            }
            
            if hasPermission {
                VStack(spacing: 8) {
                    Divider()
                    
                    Button(action: { showingOptimizationInfo.toggle() }) {
                        HStack {
                            Text("notifications.optimize_title".localized)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Image(systemName: showingOptimizationInfo ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if showingOptimizationInfo {
                        OptimizationInfoView()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AI Source Selection View

struct AISourceSelectionView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var chatGPTService = ChatGPTService.shared
    @State private var refreshTrigger = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("notifications.ai_analysis_title".localized)
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                // Local AI Option
                Button(action: {
                    notificationManager.useLocalAIForNotifications = true
                    notificationManager.saveSettings()
                }) {
                    HStack {
                        Image(systemName: notificationManager.useLocalAIForNotifications ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(notificationManager.useLocalAIForNotifications ? .green : .gray)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("notifications.local_ai_free".localized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("notifications.local_ai_description".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("common.free".localized)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
                
                // ChatGPT Option
                Button(action: {
                    notificationManager.useLocalAIForNotifications = false
                    notificationManager.saveSettings()
                }) {
                    HStack {
                        Image(systemName: !notificationManager.useLocalAIForNotifications ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(!notificationManager.useLocalAIForNotifications ? .green : .gray)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("notifications.chatgpt_ai".localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                if !chatGPTService.hasValidAPIKey {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                            }
                            
                            Text("notifications.chatgpt_ai_description".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("common.paid".localized)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!chatGPTService.hasValidAPIKey)
                .opacity(chatGPTService.hasValidAPIKey ? 1.0 : 0.6)
            }
            
            // Warning for ChatGPT costs
            if !notificationManager.useLocalAIForNotifications {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.orange)
                        
                        Text("notifications.cost_warning".localized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    
                    Text("notifications.daily_cost_note".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // API Key Status
            if !chatGPTService.hasValidAPIKey {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    
                    Text("notifications.configure_api_key".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .id(refreshTrigger) // Force view refresh when this changes
        .onReceive(NotificationCenter.default.publisher(for: .chatGPTAPIKeyChanged)) { _ in
            // Refresh the view when API key changes
            refreshTrigger.toggle()
        }
    }
}

// MARK: - Optimization Info View

struct OptimizationInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("notifications.best_experience".localized)
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 8) {
                OptimizationRowView(
                    icon: "bell.badge", 
                    title: "notifications.banners".localized, 
                    description: "notifications.banners_description".localized
                )
                
                OptimizationRowView(
                    icon: "list.bullet.rectangle", 
                    title: "notifications.notification_center".localized, 
                    description: "notifications.notification_center_description".localized
                )
                
                OptimizationRowView(
                    icon: "lock.shield", 
                    title: "notifications.lock_screen".localized, 
                    description: "notifications.lock_screen_description".localized
                )
            }
            
            Button("settings.open_ios_settings".localized) {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct OptimizationRowView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Morning Forecast Settings

struct MorningForecastSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // Enable/disable toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("notifications.daily_forecasts".localized)
                        .font(.headline)
                    Text("notifications.dr_elias_prediction".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $notificationManager.morningForecastEnabled)
            }
            
            if notificationManager.morningForecastEnabled {
                Divider()
                
                // Time picker
                HStack {
                    Text("notifications.notification_time".localized)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    DatePicker(
                        "common.time".localized,
                        selection: $notificationManager.morningForecastTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .onChange(of: notificationManager.morningForecastTime) { _, newTime in
                        let timeFormatter = DateFormatter()
                        timeFormatter.timeStyle = .short
                        print("⏰ Time changed to: \(timeFormatter.string(from: newTime))")
                        notificationManager.saveSettings()
                    }
                }
                
                Divider()
                
                // AI Source Selection
                AISourceSelectionView()
                
                // Preview message
                ForecastPreviewView()
            }
        }
    }
}

struct ForecastPreviewView: View {
    @Query(sort: \Dog.name) private var dogs: [Dog]
    
    private var firstDogName: String {
        dogs.first?.name ?? "common.your_dog".localized
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("common.preview".localized)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                // App icon placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("🐕")
                            .font(.title2)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "notifications.morning_forecast_sample".localized, firstDogName))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(String(format: "notifications.good_morning_sample".localized, firstDogName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Reminder Settings

struct ReminderSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("notifications.activity_reminders_title".localized)
                        .font(.headline)
                    Text("notifications.gentle_nudges".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $notificationManager.reminderNotificationsEnabled)
            }
            
            if notificationManager.reminderNotificationsEnabled {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("notifications.reminder_types".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Label("notifications.no_logging_6_hours".localized, systemImage: "clock")
                        .font(.caption)
                    Label("notifications.end_of_day_checkin".localized, systemImage: "moon")
                        .font(.caption)
                    Label("notifications.weekly_pattern_breaks".localized, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                }
                .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Progress Report Settings

struct ProgressReportSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("notifications.weekly_reports".localized)
                        .font(.headline)
                    Text("notifications.dr_elias_analyzes".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $notificationManager.progressReportsEnabled)
            }
            
            if notificationManager.progressReportsEnabled {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("notifications.delivery_schedule".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("notifications.sundays_7pm".localized)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Text("notifications.reports_description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Quick Actions Section

struct QuickActionsView: View {
    let dogs: [Dog]
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: testBasicNotification) {
                Label("notifications.test_basic".localized, systemImage: "bell.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: testBackgroundNotification) {
                Label("notifications.test_background_5s".localized, systemImage: "moon.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: testMorningForecast) {
                Label("notifications.test_morning_forecast".localized, systemImage: "sunrise.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: testRealMorningForecast) {
                Label("notifications.test_real_forecast".localized, systemImage: "pawprint")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: scheduleTestForecast) {
                Label("notifications.schedule_test_1min".localized, systemImage: "clock.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: scheduleSimpleDelayTest) {
                Label("notifications.simple_10s_test".localized, systemImage: "timer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: testProgressReport) {
                Label("notifications.test_progress_report".localized, systemImage: "chart.bar.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: showScheduledNotifications) {
                Label("notifications.show_scheduled".localized, systemImage: "list.bullet")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: checkNotificationSettings) {
                Label("notifications.check_ios_settings".localized, systemImage: "gear")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: clearAllNotifications) {
                Label("notifications.clear_all".localized, systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private func testBasicNotification() {
        print("🔔 Testing basic notification...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("🔔 Permission: \(granted), Error: \(String(describing: error))")
            
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "notifications.test".localized
                content.body = "notifications.test_body".localized
                content.sound = .default
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(identifier: "basic_test", content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ Error: \(error)")
                    } else {
                        print("✅ Basic notification scheduled!")
                    }
                }
            }
        }
    }
    
    private func testBackgroundNotification() {
        print("🌙 Testing background notification in 5 seconds...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "notifications.background_test_title".localized
                content.body = "notifications.background_test_body".localized
                content.sound = .default
                content.badge = 1
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                let request = UNNotificationRequest(identifier: "background_test", content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ Error: \(error)")
                    } else {
                        print("✅ Background notification scheduled! Minimize app now!")
                    }
                }
            }
        }
    }
    
    private func scheduleTestForecast() {
        print("⏰ Scheduling test forecast for current time + 1 minute...")
        
        // Set the time to current time + 1 minute
        let testTime = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date()
        
        // Update notification manager time
        notificationManager.morningForecastTime = testTime
        notificationManager.morningForecastEnabled = true
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        print("⏰ Set morning forecast time to: \(timeFormatter.string(from: testTime))")
        
        // Save settings (this will trigger rescheduling)
        notificationManager.saveSettings()
        
        print("🎯 Now minimize the app and wait 1 minute for the morning forecast!")
    }
    
    private func scheduleSimpleDelayTest() {
        print("⏱️ Scheduling simple 10-second delay test...")
        
        let content = UNMutableNotificationContent()
        content.title = "notifications.doglog_test_title".localized
        content.body = "notifications.doglog_test_body".localized
        content.sound = .default
        content.badge = 1
        
        // Add custom category to make it stand out
        content.categoryIdentifier = "TEST_NOTIFICATION"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "simple_delay_test_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling simple test: \(error)")
            } else {
                print("✅ Simple 10s test scheduled! MINIMIZE APP NOW!")
            }
        }
    }
    
    private func testRealMorningForecast() {
        print("🐕 Testing real morning forecast for \(dogs.count) dogs...")
        
        guard !dogs.isEmpty else {
            print("❌ No dogs found for testing")
            return
        }
        
        Task {
            for dog in dogs {
                // Use the actual notification manager to create real forecast
                await notificationManager.scheduleTestNotification(for: dog, delay: 3.0)
                print("✅ Scheduled test forecast for: \(dog.name)")
            }
            print("🎯 Real forecasts scheduled! Check in 3 seconds.")
        }
    }
    
    private func testMorningForecast() {
        Task {
            print("🧪 Testing morning forecast notification...")
            
            // Check permission first
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            print("🔔 Notification settings: \(settings.authorizationStatus.rawValue)")
            
            let content = UNMutableNotificationContent()
            content.title = "notifications.test_morning_forecast_title".localized
            content.subtitle = "notifications.test_morning_forecast_subtitle".localized
            content.body = "notifications.test_morning_forecast_body".localized
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request = UNNotificationRequest(identifier: "test_forecast", content: content, trigger: trigger)
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("✅ Test notification scheduled successfully!")
            } catch {
                print("❌ Error scheduling test notification: \(error)")
            }
        }
    }
    
    private func testProgressReport() {
        Task {
            let content = UNMutableNotificationContent()
            content.title = "notifications.test_progress_report_title".localized
            content.body = "notifications.test_progress_report_body".localized
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request = UNNotificationRequest(identifier: "test_report", content: content, trigger: trigger)
            
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func showScheduledNotifications() {
        Task {
            await notificationManager.printScheduledNotifications()
        }
    }
    
    private func checkNotificationSettings() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            print("📱 iOS Notification Settings Debug:")
            print("   Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("   Alert Setting: \(settings.alertSetting.rawValue)")
            print("   Badge Setting: \(settings.badgeSetting.rawValue)")
            print("   Sound Setting: \(settings.soundSetting.rawValue)")
            print("   Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
            print("   Lock Screen Setting: \(settings.lockScreenSetting.rawValue)")
            print("   Car Play Setting: \(settings.carPlaySetting.rawValue)")
            print("   Alert Style: \(settings.alertStyle.rawValue)")
            print("   Show Previews Setting: \(settings.showPreviewsSetting.rawValue)")
            print("   Critical Alert Setting: \(settings.criticalAlertSetting.rawValue)")
            print("   Provides App Notification Settings: \(settings.providesAppNotificationSettings)")
            print("   Announcement Setting: \(settings.announcementSetting.rawValue)")
            print("   Scheduled Delivery Setting: \(settings.scheduledDeliverySetting.rawValue)")
            print("   Direct Messages Setting: \(settings.directMessagesSetting.rawValue)")
            print("   Time Sensitive Setting: \(settings.timeSensitiveSetting.rawValue)")
        }
    }
    
    private func clearAllNotifications() {
        notificationManager.cancelAllNotifications()
    }
}

// MARK: - Preview

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
    }
}
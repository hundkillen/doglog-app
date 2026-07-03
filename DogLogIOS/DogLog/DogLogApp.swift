import SwiftUI
import SwiftData
import UserNotifications

@main
struct DogLogApp: App {
    @State private var showSplash = true
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashScreenView(onTapToContinue: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showSplash = false
                        }
                    })
                } else {
                    ContentView()
                        .environmentObject(notificationManager)
                        .onAppear {
                            setupNotifications()
                        }
                }
            }
            // Rebuild the whole view hierarchy when the in-app language
            // changes, so every ".localized" string re-resolves immediately
            // instead of requiring an app restart.
            .id(localizationManager.currentLanguage)
            .environment(\.locale, localizationManager.getLocale())
        }
        .modelContainer(for: [Dog.self, Activity.self, CustomActivity.self, ActivityDefinition.self, DailyRating.self, DogPhoto.self, TrainingExercise.self])
    }
    
    private func setupNotifications() {
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Check permission on app launch
        notificationManager.checkPermission()
        
        // Request permission if not already asked before
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            
            // Only request permission if we haven't asked before
            if settings.authorizationStatus == .notDetermined {
                print("🔔 First time user - requesting notification permission...")
                await notificationManager.requestPermission()
            } else if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                print("🔔 Permission already granted - checking settings...")
                await notificationManager.checkAndPromptForOptimalSettings()
            }
        }
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationDelegate()
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("🔔 Notification received in foreground: \(notification.request.content.title)")
        print("🔔 Body: \(notification.request.content.body)")
        
        // Clear badge when notification is received
        UNUserNotificationCenter.current().setBadgeCount(0)
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }
    
    // Handle notification response (tap, action buttons)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Clear badge when user taps notification
        UNUserNotificationCenter.current().setBadgeCount(0)
        
        NotificationManager.shared.handleNotificationResponse(response)
        completionHandler()
    }
}
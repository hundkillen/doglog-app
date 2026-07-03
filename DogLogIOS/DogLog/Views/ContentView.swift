import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Dog.name) private var dogs: [Dog]
    @EnvironmentObject private var notificationManager: NotificationManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var showingAddDog = false
    @State private var selectedDog: Dog?
    @State private var showingTutorial = false
    @State private var showingSettings = false
    @State private var showingNotificationPrompt = false
    @State private var showingMorningForecastFromNotification = false
    @State private var selectedDogForForecast: Dog?
    @State private var notificationDog: Dog?
    
    // Demo dog instance
    private let demoDog = DemoDog()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Manual header with buttons
                HStack {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text("main.title".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: { showingAddDog = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Main content
                DogGalleryView(dogs: dogs, selectedDog: $selectedDog, onShowTutorial: {
                    showingTutorial = true
                })
            }
                .sheet(isPresented: $showingAddDog) {
                    AddEditDogView(dog: nil)
                }
                .sheet(item: $selectedDog) { dog in
                    DogDetailView(dog: dog)
                }
                .sheet(isPresented: $showingTutorial) {
                    TutorialView()
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
                .onChange(of: dogs) { _, newDogs in
                    // Schedule notifications when dogs are added/updated
                    print("🐕 Dogs changed, scheduling notifications for \(newDogs.count) dogs")
                    Task {
                        await notificationManager.scheduleMorningForecast(for: newDogs)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .notificationSettingsChanged)) { _ in
                    // Reschedule notifications when settings change
                    print("⚙️ Notification settings changed, rescheduling for \(dogs.count) dogs")
                    Task {
                        await notificationManager.scheduleMorningForecast(for: dogs)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .showNotificationSettingsPrompt)) { _ in
                    showingNotificationPrompt = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .showMorningForecast)) { notification in
                    print("📱 Received showMorningForecast notification")
                    print("📱 Notification userInfo: \(notification.userInfo ?? [:])")
                    print("📱 Available dogs: \(dogs.map { "\($0.name) - \($0.id)" })")
                    
                    // Handle morning forecast notification tap
                    if let userInfo = notification.userInfo,
                       let dogIdString = userInfo["dogId"] as? String {
                        print("🔍 Found dogId string: \(dogIdString)")
                        
                        if let dogId = UUID(uuidString: dogIdString) {
                            print("🔍 Parsed UUID: \(dogId)")
                            
                            if let dog = dogs.first(where: { $0.id == dogId }) {
                                print("🐕 Found dog: \(dog.name) for forecast")
                                // Close any open sheets first
                                showingSettings = false
                                showingAddDog = false
                                showingTutorial = false
                                selectedDog = nil
                                
                                // Small delay to ensure sheets are closed
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    print("🔄 Setting notificationDog to: \(dog.name)")
                                    notificationDog = dog
                                    selectedDogForForecast = dog
                                    print("🔄 Setting showingMorningForecastFromNotification to true")
                                    showingMorningForecastFromNotification = true
                                    print("🔄 notificationDog is now: \(notificationDog?.name ?? "nil")")
                                }
                            } else {
                                print("❌ Dog with ID \(dogId) not found in dogs list")
                                // Show with first dog as fallback
                                if let firstDog = dogs.first {
                                    print("🔄 Using first available dog: \(firstDog.name)")
                                    // Close any open sheets first
                                    showingSettings = false
                                    showingAddDog = false
                                    showingTutorial = false
                                    selectedDog = nil
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        selectedDogForForecast = firstDog
                                        showingMorningForecastFromNotification = true
                                    }
                                }
                            }
                        } else {
                            print("❌ Could not parse UUID from: \(dogIdString)")
                        }
                    } else {
                        print("❌ No dogId found in notification userInfo")
                        // Show with first dog as fallback
                        if let firstDog = dogs.first {
                            print("🔄 Using first available dog as fallback: \(firstDog.name)")
                            // Close any open sheets first
                            showingSettings = false
                            showingAddDog = false
                            showingTutorial = false
                            selectedDog = nil
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                selectedDogForForecast = firstDog
                                showingMorningForecastFromNotification = true
                            }
                        }
                    }
                }
                .onAppear {
                    // One-shot data migration to stable activity keys + catalog refresh
                    ActivityCatalog.shared.migrateIfNeeded(context: modelContext)
                    // One-shot dedup of same-day duplicate ratings
                    DailyRatingDeduplicator.runIfNeeded(context: modelContext)
                    // Flag legacy training weeks (no language tag) for regeneration
                    TrainingWeekCache.migrateLegacyCachesIfNeeded()
                    // Clear badge when app opens
                    UNUserNotificationCenter.current().setBadgeCount(0)
                    // Schedule or reschedule morning forecasts at app start
                    Task {
                        await notificationManager.scheduleMorningForecast(for: dogs)
                    }
                    // Lazy exercise-library refresh if the configured interval elapsed
                    ExerciseLibraryRefresher.refreshIfDue(context: modelContext)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    ExerciseLibraryRefresher.refreshIfDue(context: modelContext)
                }
                .alert("notifications.improve_title".localized, isPresented: $showingNotificationPrompt) {
                    Button("notifications.open_settings".localized) {
                        openNotificationSettings()
                    }
                    Button("notifications.later".localized, role: .cancel) { }
                } message: {
                    Text("notifications.improve_message".localized)
                }
                .sheet(isPresented: $showingMorningForecastFromNotification) {
                    if let dog = notificationDog ?? selectedDogForForecast ?? dogs.first {
                        MorningForecastView(dog: dog)
                            .onAppear {
                                print("📊 Opening MorningForecastView for: \(dog.name)")
                                print("🎭 Used notificationDog: \(notificationDog?.name ?? "nil")")
                                print("🎭 Used selectedDogForForecast: \(selectedDogForForecast?.name ?? "nil")")
                            }
                    } else {
                        Text("notifications.error_no_dogs".localized)
                            .padding()
                            .onAppear {
                                print("❌ No dogs available at all!")
                            }
                    }
                }
        }
        .onLanguageChange {
            // Reschedule notifications to apply new language to content
            Task {
                await notificationManager.scheduleMorningForecast(for: dogs)
            }
        }
    }
    
    private func openNotificationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// Demo dog for tutorial purposes
struct DemoDog {
    let name = "tutorial.demo_dog_name".localized
    let breed = "tutorial.demo_dog_description".localized
    let isDemo = true
}

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    
    private let tutorialPages = [
        TutorialPage(
            title: "tutorial.welcome_title".localized,
            description: "tutorial.welcome_description".localized,
            imageName: "pawprint.circle.fill",
            color: .blue
        ),
        TutorialPage(
            title: "tutorial.add_dog_title".localized,
            description: "tutorial.add_dog_description".localized,
            imageName: "plus.circle.fill",
            color: .green
        ),
        TutorialPage(
            title: "tutorial.daily_activities_title".localized,
            description: "tutorial.daily_activities_description".localized,
            imageName: "calendar.circle.fill",
            color: .orange
        ),
        TutorialPage(
            title: "tutorial.rate_days_title".localized,
            description: "tutorial.rate_days_description".localized,
            imageName: "heart.circle.fill",
            color: .red
        ),
        TutorialPage(
            title: "tutorial.lagged_patterns_title".localized,
            description: "tutorial.lagged_patterns_description".localized,
            imageName: "arrow.triangle.branch",
            color: .cyan
        ),
        TutorialPage(
            title: "tutorial.context_tags_title".localized,
            description: "tutorial.context_tags_description".localized,
            imageName: "tag.fill",
            color: .brown
        ),
        TutorialPage(
            title: "tutorial.ai_sources_title".localized,
            description: "tutorial.ai_sources_description".localized,
            imageName: "brain.head.profile",
            color: .purple
        ),
        TutorialPage(
            title: "tutorial.training_week_title".localized,
            description: "tutorial.training_week_description".localized,
            imageName: "list.bullet.rectangle.portrait",
            color: .teal
        ),
        TutorialPage(
            title: "tutorial.morning_forecast_title".localized,
            description: "tutorial.morning_forecast_description".localized,
            imageName: "sunrise.fill",
            color: .yellow
        ),
        TutorialPage(
            title: "tutorial.exercise_library_title".localized,
            description: "tutorial.exercise_library_description".localized,
            imageName: "books.vertical",
            color: .indigo
        ),
        TutorialPage(
            title: "tutorial.regeneration_title".localized,
            description: "tutorial.regeneration_description".localized,
            imageName: "arrow.clockwise.circle.fill",
            color: .orange
        ),
        TutorialPage(
            title: "tutorial.ready_title".localized,
            description: "tutorial.ready_description".localized,
            imageName: "checkmark.circle.fill",
            color: .mint
        )
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<tutorialPages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? .blue : .gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
                
                // Tutorial content
                TabView(selection: $currentPage) {
                    ForEach(Array(tutorialPages.enumerated()), id: \.offset) { index, page in
                        TutorialPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button("nav.previous".localized) {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    if currentPage < tutorialPages.count - 1 {
                        Button("nav.next".localized) {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                    } else {
                        Button("nav.get_started".localized) {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.blue)
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            .navigationTitle("nav.how_to_use".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("nav.skip".localized) {
                dismiss()
            })
        }
    }
}

struct TutorialPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct TutorialPageView: View {
    let page: TutorialPage
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(page.color)
                .padding(.top, 40)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding()
    }
}
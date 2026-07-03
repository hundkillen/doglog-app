import SwiftUI
import SwiftData

struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct DogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let dog: Dog
    
    // Debug-only features (e.g. test data generation); excluded from release builds
    #if DEBUG
    private let showDebugFeatures = true
    #else
    private let showDebugFeatures = false
    #endif
    @State private var showingEditDog = false
    @State private var showingDeleteAlert = false
    @State private var selectedDate = Date()
    @State private var showingDailyActivity = false
    @State private var dateForDailyActivity: IdentifiableDate?
    @State private var showingAIInsights = false
    @State private var showingMorningForecast = false
    @State private var currentMonth = Date()
    @State private var showingSuggestedTrainingWeek = false
    @State private var showTrainingWeekPrompt = false
    @State private var hasTrainingWeek = false
    @State private var needsTrainingWeekRegeneration = false
    
    @ObservedObject private var chatGPTService = ChatGPTService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Dog header
                DogHeaderView(dog: dog)
                    .padding()
                
                // Suggested Training Week Section
                if hasTrainingWeek && !needsTrainingWeekRegeneration {
                    // Show "View Training Week" button when training week exists  
                    Button(action: {
                        showingSuggestedTrainingWeek = true
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.title2)
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("training.week.ready".localized)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("training.week.description".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.green.opacity(0.1), .blue.opacity(0.1)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.green.opacity(0.3), .blue.opacity(0.3)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button("training.week.regenerate".localized) {
                            regenerateTrainingWeek()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                } else if needsTrainingWeekRegeneration {
                    // Show regeneration prompt when there is existing training week but data changed
                    SuggestedTrainingWeekPromptView(
                        dogName: dog.name,
                        onCreateTrainingWeek: {
                            needsTrainingWeekRegeneration = false
                            showingSuggestedTrainingWeek = true
                        },
                        onDismiss: {
                            needsTrainingWeekRegeneration = false
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom)
                } else if showTrainingWeekPrompt {
                    // Show creation prompt when no training week exists
                    SuggestedTrainingWeekPromptView(
                        dogName: dog.name,
                        onCreateTrainingWeek: {
                            showTrainingWeekPrompt = false
                            showingSuggestedTrainingWeek = true
                        },
                        onDismiss: {
                            showTrainingWeekPrompt = false
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                
                // AI Insights button
                Button(action: {
                    showingAIInsights = true
                }) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ai.title".localized)
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("insights.discover_patterns".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                // Morning Forecast button
                Button(action: {
                    showingMorningForecast = true
                }) {
                    HStack {
                        Text("🌅")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("forecast.title".localized)
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("forecast.description".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.orange.opacity(0.1), .yellow.opacity(0.1)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.orange.opacity(0.3), .yellow.opacity(0.3)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                .padding(.bottom)
                
                // Calendar view
                CalendarView(
                    dog: dog,
                    selectedDate: $selectedDate,
                    showingDailyActivity: $showingDailyActivity,
                    currentMonth: $currentMonth,
                    onDateSelected: { date in
                        let day = Calendar.current.component(.day, from: date)
                        print("DogDetailView: Calendar callback with day \(day), date: \(date)")
                        dateForDailyActivity = IdentifiableDate(date: date)
                        print("DogDetailView: Set dateForDailyActivity to day \(Calendar.current.component(.day, from: date))")
                    }
                )
            }
            .navigationTitle(dog.name ?? "dog.unknown_dog".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button("common.done".localized) {
                    dismiss()
                },
                trailing: Menu {
                    if showDebugFeatures {
                        Button("test.generate_data".localized) {
                            generateTestData()
                        }
                        
                        Divider()
                    }
                    
                    Button("dog.edit_dog".localized) {
                        showingEditDog = true
                    }
                    
                    Button("dog.delete_dog".localized, role: .destructive) {
                        showingDeleteAlert = true
                    }
                    
                    if hasTrainingWeek {
                        Button("training.week.regenerate".localized) {
                            regenerateTrainingWeek()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            )
        }
        .sheet(isPresented: $showingEditDog) {
            AddEditDogView(dog: dog)
        }
        .sheet(item: $dateForDailyActivity) { identifiableDate in
            let date = identifiableDate.date
            let day = Calendar.current.component(.day, from: date)
            let _ = print("DogDetailView: Showing DailyActivityView for day \(day), date: \(date)")
            DailyActivityView(dog: dog, date: date)
        }
        .sheet(isPresented: $showingAIInsights) {
            AIInsightsView(dog: dog, currentMonth: currentMonth)
        }
        .sheet(isPresented: $showingMorningForecast) {
            MorningForecastView(dog: dog)
        }
        .sheet(isPresented: $showingSuggestedTrainingWeek) {
            SuggestedTrainingWeekView(dog: dog, analysis: nil)
        }
        .onChange(of: showingSuggestedTrainingWeek) { _, isShowing in
            if !isShowing {
                // When training week view closes, check if a training week was created
                checkForTrainingWeekPrompt()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("trainingWeekUpdated"))) { _ in
            // Sync immediately when week saved/updated
            DispatchQueue.main.async { checkForTrainingWeekPrompt() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("trainingWeekNeedsRegeneration"))) { _ in
            // New data arrived via manual edit – force UI to show regeneration prompt
            DispatchQueue.main.async { checkForTrainingWeekPrompt() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            // Any defaults change (e.g., regen flag) should refresh prompt state
            DispatchQueue.main.async { checkForTrainingWeekPrompt() }
        }
        .alert("dog.delete_dog".localized, isPresented: $showingDeleteAlert) {
            Button("common.delete".localized, role: .destructive) {
                deleteDog()
            }
            Button("common.cancel".localized, role: .cancel) { }
        } message: {
            Text(String(format: "dog.delete_confirmation".localized, dog.name ?? "this dog"))
        }
        .onAppear {
            checkForTrainingWeekPrompt()
        }
    }
    
    private func checkForTrainingWeekPrompt() {
        // Check if training week already exists for this dog
        let hasCachedTrainingWeek = TrainingWeekCache.hasCachedWeek(dogId: dog.id)
        
        hasTrainingWeek = hasCachedTrainingWeek
        
        // Regenerate when dog data changed OR the app language no longer matches
        // the language the week was generated in.
        let regenKey = TrainingWeekCache.regenKey(dogId: dog.id)
        if hasCachedTrainingWeek && !TrainingWeekCache.isCacheLanguageCurrent(dogId: dog.id) {
            TrainingWeekCache.markNeedsRegeneration(dogId: dog.id)
        }
        needsTrainingWeekRegeneration = UserDefaults.standard.bool(forKey: regenKey)
        
        // Force UI refresh of the section by toggling a tiny state if needed
        // When regeneration is needed, ensure the ready button is hidden immediately
        if hasTrainingWeek && needsTrainingWeekRegeneration {
            hasTrainingWeek = true
        }
        
        // Only show prompt if ChatGPT is available and no training week exists
        if chatGPTService.hasValidAPIKey && !hasCachedTrainingWeek {
            // Delay prompt slightly to let the view settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showTrainingWeekPrompt = true
            }
        }
    }
    
    private func regenerateTrainingWeek() {
        // Remove existing training week from cache
        let cacheKey = TrainingWeekCache.cacheKey(dogId: dog.id)
        UserDefaults.standard.removeObject(forKey: cacheKey)
        TrainingWeekCache.removeLanguage(dogId: dog.id)
        
        // Clear regeneration flag if present
        let regenKey = TrainingWeekCache.regenKey(dogId: dog.id)
        UserDefaults.standard.removeObject(forKey: regenKey)
        
        // Update state and open training week view to regenerate
        hasTrainingWeek = false
        needsTrainingWeekRegeneration = false
        showingSuggestedTrainingWeek = true
    }
    
    private func deleteDog() {
        modelContext.delete(dog)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error deleting dog: \(error)")
        }
    }
    
    private func generateTestData() {
        // Store stable keys, matching what the activity picker now saves.
        let activities = ActivityCatalog.defaultSeed.map { $0.key }
        
        // Store RAW codes for outcomes/ratings so UI logic works ("good|okay|bad")
        let outcomeCodes = ["good", "okay", "bad"]
        let dayRatingCodes = ["good", "okay", "bad"]
        
        // Generate data for the currently selected month
        let calendar = Calendar.current
        
        // Get the first and last day of the current month
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return }
        let firstOfMonth = monthInterval.start
        let lastOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth)!
        
        // Get all days in the current month
        let numberOfDaysInMonth = calendar.component(.day, from: lastOfMonth)
        
        // Plant a deterministic lagged pattern: "doggy daycare" every 4th day,
        // always followed by a bad day, so the day-after pattern detector has
        // something real to find in test data.
        let daycareDays = Set(stride(from: 2, to: numberOfDaysInMonth, by: 4))
        
        for day in 1...numberOfDaysInMonth {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) else { continue }
            
            // Random number of activities (0-4)
            let numActivities = Int.random(in: 0...4)
            
            for j in 0..<numActivities {
                let randomActivity = activities.randomElement() ?? "activity.walk"
                // Weighted randomness: good 50%, okay 30%, bad 20%
                let roll = Int.random(in: 1...100)
                let randomOutcome = roll <= 50 ? "good" : roll <= 80 ? "okay" : "bad"
                
                let activity = Activity(
                    date: date,
                    activityType: randomActivity,
                    outcome: randomOutcome,
                    notes: Bool.random() ? String(format: "test.activity_note".localized, randomActivity.localized) : nil
                )
                // Append to the relationship (not just insert into the context)
                // so the calendar UI observes the change immediately.
                modelContext.insert(activity)
                dog.activities.append(activity)
            }
            
            if daycareDays.contains(day) {
                let daycare = Activity(
                    date: date,
                    activityType: "test.daycare",
                    outcome: "okay",
                    notes: nil
                )
                modelContext.insert(daycare)
                dog.activities.append(daycare)
            }
            
            // Add daily rating
            // Weighted randomness: good 45%, okay 35%, bad 20%
            // Days after a planted daycare day are always bad.
            let r = Int.random(in: 1...100)
            let randomDayRating = daycareDays.contains(day - 1)
                ? "bad"
                : (r <= 45 ? "good" : r <= 80 ? "okay" : "bad")
            let dailyRating = DailyRating(
                date: date,
                rating: randomDayRating,
                notes: String(format: "test.daily_note".localized, day, dog.name ?? "dog.unknown_dog".localized)
            )
            modelContext.insert(dailyRating)
            dog.dailyRatings.append(dailyRating)
        }
        
        do {
            try modelContext.save()
            
            // Invalidate ChatGPT cache when data changes
            ChatGPTService.shared.invalidateCache(for: dog.id)
        } catch {
            print("Error generating test data: \(error)")
        }
    }
}

struct DogHeaderView: View {
    let dog: Dog
    
    var body: some View {
        HStack(spacing: 16) {
            // Dog photo
            if let profilePhoto = dog.profilePhoto,
               let uiImage = UIImage(data: profilePhoto.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(16)
            } else if let photoData = dog.photoData, let uiImage = UIImage(data: photoData) {
                // Fallback to legacy photo
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(16)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "pawprint.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dog.name ?? "dog.unknown_name".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let breed = dog.breed, !breed.isEmpty {
                    Text(breed)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let dateOfBirth = dog.dateOfBirth {
                    Text(String(format: "age.years_old".localized, ageFromDate(dateOfBirth)))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let gender = dog.gender {
                    Text(gender)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    private func ageFromDate(_ date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
    }
}

// MARK: - Suggested Training Week Prompt View
struct SuggestedTrainingWeekPromptView: View {
    let dogName: String
    let onCreateTrainingWeek: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("training.week.prompt.title".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(String(format: "training.week.prompt.description".localized, dogName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            
            HStack(spacing: 12) {
                Button("training.week.maybe_later".localized) {
                    onDismiss()
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("training.week.create_week".localized) {
                    onCreateTrainingWeek()
                }
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.green, .blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.green.opacity(0.1), .blue.opacity(0.1)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [.green.opacity(0.3), .blue.opacity(0.3)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct DogDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDog = Dog(name: "Buddy", breed: "Golden Retriever")
        
        return DogDetailView(dog: sampleDog)
    }
}
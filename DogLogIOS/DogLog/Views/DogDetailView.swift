import SwiftUI
import SwiftData

struct DogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let dog: Dog
    @State private var showingEditDog = false
    @State private var showingDeleteAlert = false
    @State private var selectedDate = Date()
    @State private var showingDailyActivity = false
    @State private var showingAIInsights = false
    @State private var currentMonth = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Dog header
                DogHeaderView(dog: dog)
                    .padding()
                
                // AI Insights button
                Button(action: {
                    showingAIInsights = true
                }) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("🧠 AI Insights")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Discover patterns in your dog's behavior")
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
                .padding(.bottom)
                
                // Calendar view
                CalendarView(
                    dog: dog,
                    selectedDate: $selectedDate,
                    showingDailyActivity: $showingDailyActivity,
                    currentMonth: $currentMonth
                )
            }
            .navigationTitle(dog.name ?? "Dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("🎲 Generate Test Data") {
                            generateTestData()
                        }
                        
                        Divider()
                        
                        Button("Edit Dog") {
                            showingEditDog = true
                        }
                        
                        Button("Delete Dog", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            })
        }
        .sheet(isPresented: $showingEditDog) {
            AddEditDogView(dog: dog)
        }
        .sheet(isPresented: $showingDailyActivity) {
            DailyActivityView(dog: dog, date: selectedDate)
        }
        .sheet(isPresented: $showingAIInsights) {
            AIInsightsView(dog: dog, currentMonth: currentMonth)
        }
        .alert("Delete Dog", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteDog()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(dog.name ?? "this dog")? This action cannot be undone.")
        }
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
        let activities = [
            "Walk", "Training", "Playtime", "Feeding", "Grooming",
            "Vet Visit", "Socialization", "Rest", "Exercise", "Bath"
        ]
        
        let outcomes = ["good", "okay", "bad"]
        let dayRatings = ["good", "okay", "bad"]
        
        // Generate data for the currently selected month
        let calendar = Calendar.current
        
        // Get the first and last day of the current month
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return }
        let firstOfMonth = monthInterval.start
        let lastOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstOfMonth)!
        
        // Get all days in the current month
        let numberOfDaysInMonth = calendar.component(.day, from: lastOfMonth)
        
        for day in 1...numberOfDaysInMonth {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) else { continue }
            
            // Random number of activities (1-4)
            let numActivities = Int.random(in: 1...4)
            
            for j in 0..<numActivities {
                let randomActivity = activities.randomElement() ?? "Walk"
                let randomOutcome = outcomes.randomElement() ?? "okay"
                
                let activity = Activity(
                    date: date,
                    activityType: randomActivity,
                    outcome: randomOutcome,
                    notes: Bool.random() ? "Test note for \(randomActivity)" : nil
                )
                activity.dog = dog
                modelContext.insert(activity)
            }
            
            // Add daily rating
            let randomDayRating = dayRatings.randomElement() ?? "okay"
            let dailyRating = DailyRating(
                date: date,
                rating: randomDayRating,
                notes: "Test day \(day) - Random daily notes for \(dog.name ?? "dog")"
            )
            dailyRating.dog = dog
            modelContext.insert(dailyRating)
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
            if let photoData = dog.photoData, let uiImage = UIImage(data: photoData) {
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
                Text(dog.name ?? "Unknown")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let breed = dog.breed, !breed.isEmpty {
                    Text(breed)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let dateOfBirth = dog.dateOfBirth {
                    Text("\(ageFromDate(dateOfBirth)) years old")
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

struct DogDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDog = Dog(name: "Buddy", breed: "Golden Retriever")
        
        return DogDetailView(dog: sampleDog)
    }
}
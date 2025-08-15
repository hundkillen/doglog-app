import SwiftUI
import SwiftData

struct DailyActivityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let dog: Dog
    let date: Date
    
    @State private var activities: [ActivityEntry] = []
    @State private var showingAddActivity = false
    @State private var dailyNotes = ""
    @State private var dailyRating: String = ""
    @State private var showingDailyRatingSheet = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Date header
                VStack(spacing: 8) {
                    Text(dateFormatter.string(from: date))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Activities for \(dog.name ?? "Dog")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // Activities list
                List {
                    Section("Activities") {
                        ForEach(activities.indices, id: \.self) { index in
                            ActivityRowView(activity: $activities[index])
                        }
                        .onDelete(perform: deleteActivity)
                        
                        Button(action: { showingAddActivity = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add Activity")
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                    }
                    
                    Section("Daily Notes") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("How was the day overall?")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingDailyRatingSheet = true
                                }) {
                                    HStack(spacing: 4) {
                                        if dailyRating.isEmpty {
                                            Text("Rate Day")
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                        } else {
                                            Circle()
                                                .fill(getDayRatingColor(dailyRating))
                                                .frame(width: 12, height: 12)
                                            Text(getDayRatingDisplayName(dailyRating))
                                                .font(.subheadline)
                                                .foregroundColor(getDayRatingColor(dailyRating))
                                        }
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(getDayRatingColor(dailyRating).opacity(0.1))
                                    .cornerRadius(16)
                                }
                            }
                            
                            TextField("Additional notes about the day...", text: $dailyNotes, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                }
            }
            .navigationTitle("Daily Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveActivities()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddActivity) {
            AddActivityView { activityType in
                let newActivity = ActivityEntry(
                    type: activityType,
                    outcome: .okay,
                    notes: ""
                )
                activities.append(newActivity)
            }
        }
        .sheet(isPresented: $showingDailyRatingSheet) {
            DailyRatingView(selectedRating: $dailyRating)
        }
        .onAppear {
            loadExistingActivities()
        }
    }
    
    private func deleteActivity(at offsets: IndexSet) {
        activities.remove(atOffsets: offsets)
    }
    
    private func loadExistingActivities() {
        let dateString = DateFormatter.dayFormatter.string(from: date)
        
        let dayActivities = dog.activities.filter { activity in
            return DateFormatter.dayFormatter.string(from: activity.date) == dateString
        }
        
        activities = dayActivities.map { activity in
            ActivityEntry(
                type: activity.activityType,
                outcome: ActivityOutcome(rawValue: activity.outcome) ?? .okay,
                notes: activity.notes ?? ""
            )
        }
        
        // Load daily rating
        let dailyRatingEntry = dog.dailyRatings.first { rating in
            return DateFormatter.dayFormatter.string(from: rating.date) == dateString
        }
        
        dailyRating = dailyRatingEntry?.rating ?? ""
        dailyNotes = dailyRatingEntry?.notes ?? ""
    }
    
    private func saveActivities() {
        let dateString = DateFormatter.dayFormatter.string(from: date)
        
        // Delete existing activities for this date
        let dayActivities = dog.activities.filter { activity in
            return DateFormatter.dayFormatter.string(from: activity.date) == dateString
        }
        
        for activity in dayActivities {
            modelContext.delete(activity)
        }
        
        // Delete existing daily rating for this date
        let existingDailyRating = dog.dailyRatings.first { rating in
            return DateFormatter.dayFormatter.string(from: rating.date) == dateString
        }
        
        if let existingRating = existingDailyRating {
            modelContext.delete(existingRating)
        }
        
        // Create new activities
        for activityEntry in activities {
            let activity = Activity(
                date: date,
                activityType: activityEntry.type,
                outcome: activityEntry.outcome.rawValue,
                notes: activityEntry.notes
            )
            activity.dog = dog
            modelContext.insert(activity)
        }
        
        // Create daily rating if provided
        if !dailyRating.isEmpty || !dailyNotes.isEmpty {
            let rating = DailyRating(
                date: date,
                rating: dailyRating,
                notes: dailyNotes
            )
            rating.dog = dog
            modelContext.insert(rating)
        }
        
        do {
            try modelContext.save()
            
            // Invalidate ChatGPT cache when data changes
            ChatGPTService.shared.invalidateCache(for: dog.id)
            
            dismiss()
        } catch {
            print("Error saving activities: \(error)")
        }
    }
    
    private func getDayRatingColor(_ rating: String) -> Color {
        switch rating {
        case "good":
            return .green
        case "okay":
            return .orange
        case "bad":
            return .red
        default:
            return .gray
        }
    }
    
    private func getDayRatingDisplayName(_ rating: String) -> String {
        switch rating {
        case "good":
            return "Good Day"
        case "okay":
            return "Okay Day"
        case "bad":
            return "Bad Day"
        default:
            return "Rate Day"
        }
    }
}

struct ActivityEntry {
    var type: String
    var outcome: ActivityOutcome
    var notes: String
}

enum ActivityOutcome: String, CaseIterable {
    case good = "good"
    case okay = "okay"
    case bad = "bad"
    
    var color: Color {
        switch self {
        case .good:
            return .green
        case .okay:
            return .orange
        case .bad:
            return .red
        }
    }
    
    var displayName: String {
        switch self {
        case .good:
            return "Good"
        case .okay:
            return "Okay"
        case .bad:
            return "Bad"
        }
    }
}

struct ActivityRowView: View {
    @Binding var activity: ActivityEntry
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(activity.type)
                    .font(.headline)
                
                Spacer()
                
                // Outcome picker
                Menu {
                    ForEach(ActivityOutcome.allCases, id: \.self) { outcome in
                        Button(action: {
                            activity.outcome = outcome
                        }) {
                            HStack {
                                Text(outcome.displayName)
                                if activity.outcome == outcome {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(activity.outcome.color)
                            .frame(width: 12, height: 12)
                        Text(activity.outcome.displayName)
                            .font(.subheadline)
                            .foregroundColor(activity.outcome.color)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(activity.outcome.color.opacity(0.1))
                    .cornerRadius(16)
                }
            }
            
            TextField("Notes about this activity...", text: $activity.notes, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(2...4)
        }
        .padding(.vertical, 4)
    }
}

struct DailyRatingView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRating: String
    
    private let ratings = [
        ("good", "😊 Good Day", Color.green),
        ("okay", "😐 Okay Day", Color.orange),
        ("bad", "😞 Bad Day", Color.red)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("How was the day overall?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    ForEach(ratings, id: \.0) { rating, displayName, color in
                        Button(action: {
                            selectedRating = rating
                            dismiss()
                        }) {
                            HStack {
                                Text(displayName)
                                    .font(.headline)
                                    .foregroundColor(color)
                                Spacer()
                                if selectedRating == rating {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(color)
                                }
                            }
                            .padding()
                            .background(color.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(color, lineWidth: selectedRating == rating ? 2 : 1)
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Rate the Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let onAdd: (String) -> Void
    
    @State private var customActivity = ""
    @State private var customActivities: [CustomActivity] = []
    
    private let predefinedActivities = [
        "Walk", "Training", "Playtime", "Feeding", "Grooming",
        "Vet Visit", "Socialization", "Rest", "Exercise", "Bath"
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Quick Add") {
                    ForEach(predefinedActivities, id: \.self) { activity in
                        Button(action: {
                            onAdd(activity)
                            dismiss()
                        }) {
                            HStack {
                                Text(activity)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                if !customActivities.isEmpty {
                    Section("Custom Activities") {
                        ForEach(customActivities, id: \.id) { activity in
                            Button(action: {
                                onAdd(activity.name)
                                dismiss()
                            }) {
                                HStack {
                                    Text(activity.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("Custom Activity") {
                    HStack {
                        TextField("Enter activity name", text: $customActivity)
                        
                        Button("Add") {
                            if !customActivity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let activityName = customActivity.trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                // Save as custom activity if not already exists
                                if !customActivities.contains(where: { $0.name == activityName }) {
                                    let newCustomActivity = CustomActivity(name: activityName)
                                    modelContext.insert(newCustomActivity)
                                    try? modelContext.save()
                                }
                                
                                onAdd(activityName)
                                dismiss()
                            }
                        }
                        .disabled(customActivity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCustomActivities()
        }
    }
    
    private func loadCustomActivities() {
        let descriptor = FetchDescriptor<CustomActivity>(
            sortBy: [SortDescriptor(\.dateCreated, order: .forward)]
        )
        customActivities = (try? modelContext.fetch(descriptor)) ?? []
    }
}

struct DailyActivityView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDog = Dog(name: "Buddy")
        
        return DailyActivityView(dog: sampleDog, date: Date())
    }
}
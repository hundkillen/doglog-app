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
    @State private var contextTags: [String] = []
    @State private var showingDailyRatingSheet = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date header
                VStack(spacing: 8) {
                    Text(dateFormatter.string(from: date))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(String(format: "daily.activities_for_dog".localized, dog.name ?? "Dog"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // Activities list
                List {
                    Section("activity.activities".localized) {
                        ForEach(activities.indices, id: \.self) { index in
                            ActivityRowView(activity: $activities[index])
                        }
                        .onDelete(perform: deleteActivity)
                        
                        Button(action: { showingAddActivity = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("activity.add_activity".localized)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                    }
                    
                    Section("daily.daily_notes".localized) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("rating.how_was_day".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingDailyRatingSheet = true
                                }) {
                                    HStack(spacing: 4) {
                                        if dailyRating.isEmpty {
                                            Text("rating.rate_day".localized)
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
                            
                            TextField("daily.additional_notes".localized, text: $dailyNotes, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                    
                    Section("context.section_title".localized) {
                        ContextTagPickerView(selectedTags: $contextTags)
                    }
                }
            }
            .navigationTitle("daily.daily_log".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) {
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
        // Clear activities first
        activities = []
        
        // Use the same date formatter as the calendar for consistency
        let dateString = DateFormatter.dayFormatter.string(from: date)
        
        print("Loading activities for date: \(date)")
        print("Target date string: \(dateString)")
        print("Total dog activities: \(dog.activities.count)")
        
        let dayActivities = dog.activities.filter { activity in
            let activityDateString = DateFormatter.dayFormatter.string(from: activity.date)
            let matches = activityDateString == dateString
            print("Activity date: \(activity.date) -> \(activityDateString), matches: \(matches)")
            return matches
        }
        
        print("Found \(dayActivities.count) activities for this day")
        
        activities = dayActivities.map { activity in
            ActivityEntry(
                type: activity.activityType,
                outcome: ActivityOutcome(rawValue: activity.outcome) ?? .okay,
                notes: activity.notes ?? ""
            )
        }
        
        // Load daily rating
        let dailyRatingEntry = dog.dailyRatings.first { rating in
            let ratingDateString = DateFormatter.dayFormatter.string(from: rating.date)
            return ratingDateString == dateString
        }
        
        dailyRating = dailyRatingEntry?.rating ?? ""
        dailyNotes = dailyRatingEntry?.notes ?? ""
        contextTags = dailyRatingEntry?.contextTags ?? []
        
        print("Final activities count: \(activities.count)")
    }
    
    private func saveActivities() {
        let dateString = DateFormatter.dayFormatter.string(from: date)
        
        // Mutate dog.activities / dog.dailyRatings directly (not just
        // modelContext.insert/delete) so SwiftUI views observing these
        // relationships refresh immediately instead of after an app restart.
        
        // Delete existing activities for this date
        let dayActivities = dog.activities.filter { activity in
            return DateFormatter.dayFormatter.string(from: activity.date) == dateString
        }
        
        for activity in dayActivities {
            dog.activities.removeAll { $0.id == activity.id }
            modelContext.delete(activity)
        }
        
        // Create new activities
        for activityEntry in activities {
            let activity = Activity(
                date: date,
                activityType: activityEntry.type,
                outcome: activityEntry.outcome.rawValue,
                notes: activityEntry.notes
            )
            modelContext.insert(activity)
            dog.activities.append(activity)
        }
        
        // Duplicate-day guard: UPDATE the existing rating for this day
        // instead of inserting a second row for the same dog+day.
        let existingDailyRating = dog.dailyRatings.first { rating in
            return DateFormatter.dayFormatter.string(from: rating.date) == dateString
        }
        let hasRatingContent = !dailyRating.isEmpty || !dailyNotes.isEmpty || !contextTags.isEmpty
        
        if let existingRating = existingDailyRating {
            if hasRatingContent {
                existingRating.rating = dailyRating
                existingRating.notes = dailyNotes
                existingRating.contextTags = contextTags
            } else {
                dog.dailyRatings.removeAll { $0.id == existingRating.id }
                modelContext.delete(existingRating)
            }
        } else if hasRatingContent {
            let rating = DailyRating(
                date: date,
                rating: dailyRating,
                notes: dailyNotes,
                contextTags: contextTags
            )
            modelContext.insert(rating)
            dog.dailyRatings.append(rating)
        }
        
        do {
            try modelContext.save()
            
            // Invalidate ChatGPT cache when data changes
            ChatGPTService.shared.invalidateCache(for: dog.id)
            // Mark that a refreshed Suggested Training Week is recommended
            let regenKey = "suggested_training_week_needs_regeneration_\(dog.id)"
            UserDefaults.standard.set(true, forKey: regenKey)
            // Notify listeners immediately so UI updates without reopening views
            NotificationCenter.default.post(name: Notification.Name("trainingWeekNeedsRegeneration"), object: dog.id)
            
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
            return "rating.good_day".localized
        case "okay":
            return "rating.okay_day".localized
        case "bad":
            return "rating.bad_day".localized
        default:
            return "rating.rate_day".localized
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
            return "outcome.good".localized
        case .okay:
            return "outcome.okay".localized
        case .bad:
            return "outcome.bad".localized
        }
    }
}

struct ActivityRowView: View {
    @Binding var activity: ActivityEntry
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: ActivityCatalog.shared.iconName(forStoredType: activity.type))
                    .foregroundColor(.blue)
                Text(ActivityCatalog.shared.displayName(forStoredType: activity.type))
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
            
            TextField("activity.notes_about_activity".localized, text: $activity.notes, axis: .vertical)
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
        ("good", "rating.good_day_emoji".localized, Color.green),
        ("okay", "rating.okay_day_emoji".localized, Color.orange),
        ("bad", "rating.bad_day_emoji".localized, Color.red)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("rating.how_was_day".localized)
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
            .navigationTitle("rating.rate_day".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
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
    
    /// Called with the stable key of the chosen activity (stored in
    /// Activity.activityType).
    let onAdd: (String) -> Void
    
    @State private var customActivity = ""
    @Query(filter: #Predicate<ActivityDefinition> { !$0.isArchived },
           sort: \ActivityDefinition.sortOrder)
    private var definitions: [ActivityDefinition]
    
    private var defaultDefinitions: [ActivityDefinition] { definitions.filter { $0.isDefault } }
    private var customDefinitions: [ActivityDefinition] { definitions.filter { !$0.isDefault } }
    
    var body: some View {
        NavigationStack {
            List {
                Section("activity.quick_add".localized) {
                    ForEach(defaultDefinitions, id: \.id) { definition in
                        ActivityDefinitionRow(
                            definition: definition,
                            onAdd: {
                                onAdd(definition.key)
                                dismiss()
                            },
                            onEdit: nil, // defaults keep their localized names
                            onArchive: { archive(definition) }
                        )
                    }
                }
                
                if !customDefinitions.isEmpty {
                    Section("activity.custom_activities".localized) {
                        ForEach(customDefinitions, id: \.id) { definition in
                            ActivityDefinitionRow(
                                definition: definition,
                                onAdd: {
                                    onAdd(definition.key)
                                    dismiss()
                                },
                                onEdit: { newName in
                                    definition.customName = newName
                                    saveAndRefresh()
                                },
                                onArchive: { archive(definition) }
                            )
                        }
                    }
                }
                
                Section("activity.custom_activity".localized) {
                    HStack {
                        TextField("activity.enter_activity_name".localized, text: $customActivity)
                        
                        Button("common.add".localized) {
                            let activityName = customActivity.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !activityName.isEmpty else { return }
                            
                            let key: String
                            if let existing = definitions.first(where: { $0.displayName == activityName }) {
                                key = existing.key
                            } else {
                                let definition = ActivityDefinition(
                                    key: "custom_\(UUID().uuidString)",
                                    customName: activityName,
                                    iconName: ActivityCatalog.customIcon,
                                    isDefault: false,
                                    sortOrder: (definitions.map { $0.sortOrder }.max() ?? 0) + 1
                                )
                                modelContext.insert(definition)
                                saveAndRefresh()
                                key = definition.key
                            }
                            
                            onAdd(key)
                            dismiss()
                        }
                        .disabled(customActivity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("activity.add_activity".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    /// Archiving hides an activity from the picker without touching history.
    private func archive(_ definition: ActivityDefinition) {
        definition.isArchived = true
        saveAndRefresh()
    }
    
    private func saveAndRefresh() {
        try? modelContext.save()
        if let all = try? modelContext.fetch(FetchDescriptor<ActivityDefinition>()) {
            ActivityCatalog.shared.refresh(from: all)
        }
    }
}

// MARK: - Activity Definition Row
struct ActivityDefinitionRow: View {
    let definition: ActivityDefinition
    let onAdd: () -> Void
    let onEdit: ((String) -> Void)?
    let onArchive: () -> Void
    
    @State private var showingEditAlert = false
    @State private var showingArchiveAlert = false
    @State private var editedName = ""
    
    var body: some View {
        HStack {
            Image(systemName: definition.iconName)
                .foregroundColor(.blue)
                .frame(width: 28)
            
            Text(definition.displayName)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                if let onEdit = onEdit {
                    Button(action: {
                        editedName = definition.displayName
                        showingEditAlert = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.orange)
                            .font(.title3)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .alert("activity.edit_activity".localized, isPresented: $showingEditAlert) {
                        TextField("activity.activity_name".localized, text: $editedName)
                        Button("common.save".localized) {
                            let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { onEdit(trimmed) }
                        }
                        Button("common.cancel".localized, role: .cancel) { }
                    } message: {
                        Text("activity.enter_new_name".localized)
                    }
                }
                
                Button(action: { showingArchiveAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.title3)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .confirmationDialog("activity.delete_activity".localized, isPresented: $showingArchiveAlert, titleVisibility: .visible) {
            Button("common.delete".localized, role: .destructive) {
                onArchive()
            }
            Button("common.cancel".localized, role: .cancel) { }
        } message: {
            Text(String(format: "activity.delete_activity_confirmation".localized, definition.displayName))
        }
    }
}


// MARK: - Context Tag Picker

/// Wrap of toggle chips for day context (thunder, guests, heat cycle, ...).
/// Zero typing, all optional; stores stable keys in DailyRating.contextTags.
struct ContextTagPickerView: View {
    @Binding var selectedTags: [String]
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(ContextTag.all, id: \.key) { tag in
                ContextTagChip(
                    key: tag.key,
                    icon: tag.icon,
                    isSelected: selectedTags.contains(tag.key)
                ) {
                    if let index = selectedTags.firstIndex(of: tag.key) {
                        selectedTags.remove(at: index)
                    } else {
                        selectedTags.append(tag.key)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContextTagChip: View {
    let key: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(key.localized)
                    .font(.subheadline)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

/// Minimal left-to-right wrapping layout for the tag chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.map { $0.width }.max() ?? 0
        return CGSize(width: width, height: rows.map { $0.height }.reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1)))
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }
    
    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var current = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth && !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.indices.append(index)
            current.width = current.indices.count == 1 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

struct DailyActivityView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDog = Dog(name: "Buddy")
        
        return DailyActivityView(dog: sampleDog, date: Date())
    }
}
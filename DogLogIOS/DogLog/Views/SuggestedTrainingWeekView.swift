import SwiftUI
import SwiftData
import EventKit

struct SuggestedTrainingWeekView: View {
    let dog: Dog
    let analysis: ChatGPTAnalysis?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var suggestedTrainingWeek: SuggestedTrainingWeek?
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedDay: TrainingDay?
    @State private var selectedDayIndex: Int?
    @State private var showingDayDetail = false
    @State private var showingActivityPicker = false
    @State private var isExportingWeek = false
    @State private var weekExportProgress = 0
    @State private var weekExportTotal = 0
    @State private var showingWeekExportAlert = false
    @State private var weekExportMessage = ""
    @State private var alertTitle = ""
    // Progress
    @State private var generationProgress: Double = 0.0
    @State private var generationStatus: String = ""
    // PDF export
    @State private var showingPDFShare = false
    @State private var exportedPDFURL: URL?
    @State private var languageMismatch = false
    @State private var needsRegeneration = false
    @ObservedObject private var chatGPTService = ChatGPTService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    if isLoading {
                        VStack(spacing: 12) {
                            DrEliasThinkingView(analysis == nil ? "training.analyzing_creating".localized : "training.creating_week".localized)
                            ProgressView(value: generationProgress)
                                .progressViewStyle(.linear)
                                .tint(.blue)
                            Text(String(format: "training.week.progress_label".localized, Int(generationProgress * 100)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !generationStatus.isEmpty {
                                Text(generationStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else if let suggestedTrainingWeek = suggestedTrainingWeek {
                        // Week Title and Goal (centered)
                        VStack(alignment: .center, spacing: 12) {
                            Text(suggestedTrainingWeek.weekTitle)
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text(suggestedTrainingWeek.weekGoal)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Export buttons
                        HStack(spacing: 12) {
                            Button(action: { exportEntireWeekToCalendar() }) {
                                HStack {
                                    if isExportingWeek {
                                        ProgressView().scaleEffect(0.8)
                                        Text("training.week.exporting_progress".localized + " (\(weekExportProgress)/\(weekExportTotal))")
                                    } else {
                                        Image(systemName: "calendar.badge.plus")
                                        Text("training.week.export_entire_week".localized)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(isExportingWeek)

                            Button(action: { exportWeekToPDF() }) {
                                HStack {
                                    Image(systemName: "doc.richtext")
                                    Text("training.week.export_pdf".localized)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        
                        // Days
                        ForEach(Array(suggestedTrainingWeek.days.enumerated()), id: \.element.dayName) { dayIndex, day in
                            DayCardView(
                                day: day,
                                onEdit: {
                                    selectedDay = day
                                    selectedDayIndex = dayIndex
                                    showingDayDetail = true
                                }
                            )
                        }
                    } else {
                        VStack(spacing: 16) {
                            if let error = error {
                                VStack(spacing: 8) {
                                    Text("❌ " + "common.error".localized)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                    
                                    Text(error)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .background(Color(.systemRed).opacity(0.1))
                                .cornerRadius(12)
                            } else if analysis == nil {
                                TWIntroCardView(dogName: dog.name)
                            }
                            
                            if languageMismatch {
                                Text("training.week.language_mismatch".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            Button(needsRegeneration || languageMismatch
                                   ? "training.week.regenerate".localized
                                   : (analysis == nil ? "training.week.create".localized : "training.week.generate_week".localized)) {
                                generateSuggestedTrainingWeek()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                print("🕐 User prefers \(TimeParser.getPreferredTimeFormat()) time format")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDayDetail) {
            if let selectedDay = selectedDay, let dayIndex = selectedDayIndex {
                TrainingDayDetailView(
                    day: selectedDay,
                    onSave: { updatedDay in
                        suggestedTrainingWeek?.days[dayIndex] = updatedDay
                        // Save updated week to cache
                        if let week = suggestedTrainingWeek {
                            // Save user edits to cache and DO NOT trigger regeneration from inside training week edits
                            saveSuggestedTrainingWeekToCache(week, clearRegenerationFlag: false, postUpdateNotification: false)
                        }
                    }
                )
            }
        }
        .onAppear {
            loadSuggestedTrainingWeekFromCache()
        }
        .sheet(isPresented: $showingPDFShare) {
            if let url = exportedPDFURL {
                ActivityView(activityItems: [url])
            }
        }
        .alert(alertTitle, isPresented: $showingWeekExportAlert) {
            Button("common.ok".localized) { }
        } message: {
            Text(weekExportMessage)
        }
    }
    
    private func generateSuggestedTrainingWeek() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let analysisToUse: ChatGPTAnalysis
                
                // If no analysis provided, generate one first
                if let existingAnalysis = analysis {
                    analysisToUse = existingAnalysis
                } else {
                    // First generate AI insights
                    let analyzer = AIPatternAnalyzer()
                    let localInsights = analyzer.analyzeDog(dog, timeRange: .allTime)
                    
                    analysisToUse = try await chatGPTService.analyzeWithChatGPT(
                        dog: dog,
                        timeRange: .allTime,
                        localInsights: localInsights
                    )
                }
                
                // Now generate the training week using the analysis
                // Simulate stepped progress while waiting for ChatGPT (7 steps ~14% each)
                generationProgress = 0.02
                let step: Double = 1.0 / 7.0
                // Lightweight timer to animate progress while the network call runs
                var stepIndex = 0
                let hints = [
                    "training.week.status.fetching_exercises".localized,
                    "training.week.status.planning_monday".localized,
                    "training.week.status.planning_tuesday".localized,
                    "training.week.status.planning_wednesday".localized,
                    "training.week.status.planning_thursday".localized,
                    "training.week.status.planning_friday".localized,
                    "training.week.status.planning_weekend".localized
                ]
                generationStatus = hints.first ?? ""
                let timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
                    withAnimation { generationProgress = min(generationProgress + step * 0.75, 0.92) }
                    stepIndex = min(stepIndex + 1, hints.count - 1)
                    generationStatus = hints[stepIndex]
                }
                // Build a compact exercise catalog summary to bias the plan
                let catalog = await prepareExerciseCatalogSummary()
                let week = try await chatGPTService.generateSuggestedTrainingWeek(
                    dog: dog,
                    analysis: analysisToUse,
                    exerciseCatalogSummary: catalog
                )
                timer.invalidate()
                
                await MainActor.run {
                    withAnimation { generationProgress = 1.0 }
                    suggestedTrainingWeek = week
                    saveSuggestedTrainingWeekToCache(week)
                    isLoading = false
                    print("📋 Generated and saved Suggested Training Week for \(dog.name)")
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                    generationProgress = 0
                }
            }
        }
    }
    
    private func saveSuggestedTrainingWeekToCache(_ week: SuggestedTrainingWeek, clearRegenerationFlag: Bool = true, postUpdateNotification: Bool = true) {
        let cacheKey = TrainingWeekCache.cacheKey(dogId: dog.id)
        if let data = try? JSONEncoder().encode(week) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            TrainingWeekCache.saveLanguage(dogId: dog.id)
            print("💾 Saved Suggested Training Week to cache with key: \(cacheKey)")
        }
        if clearRegenerationFlag {
            let regenKey = TrainingWeekCache.regenKey(dogId: dog.id)
            UserDefaults.standard.removeObject(forKey: regenKey)
            print("✅ Cleared regeneration flag: \(regenKey)")
        }

        if postUpdateNotification {
            NotificationCenter.default.post(name: Notification.Name("trainingWeekUpdated"), object: dog.id)
        }
    }
    
    private func loadSuggestedTrainingWeekFromCache() {
        let regenKey = TrainingWeekCache.regenKey(dogId: dog.id)
        if UserDefaults.standard.bool(forKey: regenKey) || !TrainingWeekCache.isCacheLanguageCurrent(dogId: dog.id) {
            print("📋 Training week needs regeneration for \(dog.name) — not loading stale cache")
            needsRegeneration = true
            languageMismatch = !TrainingWeekCache.isCacheLanguageCurrent(dogId: dog.id)
            return
        }
        let cacheKey = TrainingWeekCache.cacheKey(dogId: dog.id)
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let week = try? JSONDecoder().decode(SuggestedTrainingWeek.self, from: data) else {
            print("📋 No cached Suggested Training Week found for \(dog.name)")
            return
        }
        
        suggestedTrainingWeek = week
        print("📋 Loaded Suggested Training Week from cache for \(dog.name)")
    }
    
    private func exportEntireWeekToCalendar() {
        guard let week = suggestedTrainingWeek else { return }
        
        isExportingWeek = true
        weekExportProgress = 0
        weekExportTotal = week.days.reduce(0) { $0 + $1.activities.count }
        
        let exportGroup = DispatchGroup()
        var successCount = 0
        var failureCount = 0
        
        for (dayIndex, day) in week.days.enumerated() {
            for activity in day.activities {
                exportGroup.enter()
                
                CalendarManager.shared.exportActivityWithDayIndex(activity, dayName: day.dayName, dayIndex: dayIndex) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            successCount += 1
                        } else {
                            failureCount += 1
                        }
                        weekExportProgress += 1
                    }
                    exportGroup.leave()
                }
            }
        }
        
        exportGroup.notify(queue: .main) {
            isExportingWeek = false
            
            if failureCount == 0 {
                alertTitle = "training.week.export_success".localized
                weekExportMessage = String(format: "training.week.week_export_complete".localized, successCount)
            } else {
                alertTitle = "training.week.export_partial".localized
                weekExportMessage = String(format: "training.week.week_export_partial_message".localized, successCount, failureCount)
            }
            showingWeekExportAlert = true
        }
    }

    // MARK: - PDF Export
    private func exportWeekToPDF() {
        guard let week = suggestedTrainingWeek else { return }
        let pageSize = CGSize(width: 595, height: 842) // A4 at 72 DPI
        let format = UIGraphicsPDFRendererFormat()
        let meta: [String: Any] = [kCGPDFContextTitle as String: week.weekTitle]
        format.documentInfo = meta as [String: Any]
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("DogLog_TrainingWeek_\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        do {
            try renderer.writePDF(to: tempURL, withActions: { context in
                let margin: CGFloat = 32
                let titleFont = UIFont.preferredFont(forTextStyle: .title1)
                let subtitleFont = UIFont.preferredFont(forTextStyle: .subheadline)
                let headerFont = UIFont.preferredFont(forTextStyle: .headline)
                let bodyFont = UIFont.preferredFont(forTextStyle: .body)
                var y: CGFloat = margin
                func drawText(_ text: String, font: UIFont, color: UIColor = .label) {
                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                    let rect = CGRect(x: margin, y: y, width: pageSize.width - 2*margin, height: .greatestFiniteMagnitude)
                    let h = (text as NSString).boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attrs, context: nil).height
                    (text as NSString).draw(with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: h), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
                    y += h + 8
                }
                context.beginPage()
                drawText(week.weekTitle, font: titleFont)
                drawText(week.weekGoal, font: subtitleFont, color: .secondaryLabel)
                for (index, day) in week.days.enumerated() {
                    let dayHeader = "\(index+1). \(day.dayName) – \(day.theme)"
                    drawText(dayHeader, font: headerFont)
                    drawText("\("training.week.daily_schedule".localized)", font: subtitleFont)
                    for activity in day.activities {
                        let line1 = "\(activity.time)  •  \(activity.activity)  (\(activity.duration))"
                        drawText(line1, font: bodyFont)
                        let line2 = "\("training.week.focus_label".localized.replacingOccurrences(of: "%@", with: activity.focus))\n\("training.week.goal_label".localized.replacingOccurrences(of: "%@", with: activity.trainingGoal))"
                        drawText(line2, font: UIFont.preferredFont(forTextStyle: .footnote), color: .secondaryLabel)
                    }
                    y += 8
                    if y > pageSize.height - 120 {
                        context.beginPage(); y = margin
                    }
                }
            })
            exportedPDFURL = tempURL
            showingPDFShare = true
        } catch {
            print("❌ PDF export failed: \(error)")
        }
    }

    // MARK: - Exercise Catalog Summary
    private func prepareExerciseCatalogSummary() async -> String {
        // Fetch the activity catalog and favorite exercises from SwiftData
        var lines: [String] = []
        // Activity definitions are the single source of truth (see task 3a);
        // legacy CustomActivity / "PredefinedActivities" stores are read
        // only by the one-shot migration.
        if let definitions = try? modelContext.fetch(
            FetchDescriptor<ActivityDefinition>(sortBy: [SortDescriptor(\.sortOrder)])
        ) {
            let active = definitions.filter { !$0.isArchived }
            let defaults = active.filter { $0.isDefault }.map { $0.displayName }
            let customs = active.filter { !$0.isDefault }.map { $0.displayName }
            if !defaults.isEmpty {
                lines.append("Predefined: " + defaults.joined(separator: ", "))
            }
            if !customs.isEmpty {
                lines.append("Custom: " + customs.joined(separator: ", "))
            }
        }
        // Favorites from TrainingExercise model, if any
        let descriptor = FetchDescriptor<TrainingExercise>(predicate: #Predicate { $0.isFavorite == true })
        if let favorites = try? modelContext.fetch(descriptor), !favorites.isEmpty {
            for ex in favorites {
                let tagString = ex.tags.joined(separator: ", ")
                lines.append("⭐️ \(ex.name) | tags: [\(tagString)] | instructions: \(ex.instructions)")
            }
        }
        // If still small catalog, try to augment via ChatGPT one-time and cache to SwiftData
        if lines.count < 5 {
            if let fetched = try? await ChatGPTService.shared.fetchExerciseCatalog(dog: dog, analysis: analysis) {
                for dto in fetched.prefix(20) {
                    // Save into SwiftData if not exists
                    let predicate = #Predicate<TrainingExercise> { $0.name == dto.name }
                    let existing = try? modelContext.fetch(FetchDescriptor<TrainingExercise>(predicate: predicate))
                    if (existing?.isEmpty ?? true) {
                        let ex = TrainingExercise(
                            name: dto.name,
                            category: dto.category,
                            difficulty: dto.difficulty,
                            equipment: dto.equipment,
                            instructions: dto.instructions,
                            tags: dto.tags ?? [],
                            source: dto.source,
                            isFavorite: false
                        )
                        modelContext.insert(ex)
                    }
                }
                try? modelContext.save()
                // Rebuild lines from favorites (unchanged) plus a few top items
                let more = fetched.prefix(10).map { dto in
                    let tagString = (dto.tags ?? []).joined(separator: ", ")
                    return "• \(dto.name) | tags: [\(tagString)] | instructions: \(dto.instructions)"
                }
                lines.append(contentsOf: more)
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Day Card View
struct DayCardView: View {
    let day: TrainingDay
    let onEdit: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - clickable to expand/collapse
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(day.dayName)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text(day.theme)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                        .foregroundColor(.blue)
                }
                
                Text(day.dailyGoal)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    if day.isRestDay == true || day.activities.isEmpty {
                        Text("training.week.rest_day".localized)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    } else {
                        Text(String(format: "training.week.activities_count".localized, day.activities.count))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("common.edit".localized)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded activities section
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if day.isRestDay == true || day.activities.isEmpty {
                        Text("training.week.rest_day_detail".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(day.activities.enumerated()), id: \.element.id) { index, activity in
                            TrainingActivityRowView(activity: activity, dayIndex: index, dayName: day.dayName)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Polished Header & Intro Card

struct TrainingWeekHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("training.week.title".localized)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(.top, 4)
    }
}

struct TWIntroCardView: View {
    let dogName: String?
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("🧠")
                .font(.title2)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text("training.week.ai_analysis_plan".localized)
                    .font(.headline)
                Text(String(format: "training.week.dr_elias_description".localized, dogName ?? "dog.unknown_dog".localized))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// UIKit share sheet wrapper for PDF export
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Training Activity Row View
struct TrainingActivityRowView: View {
    let activity: TrainingActivity
    let dayIndex: Int
    let dayName: String
    @Environment(\.modelContext) private var modelContext
    @State private var showingExportOptions = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isFavorite = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(activity.time)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(activity.duration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(activity.activity)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(activity.focus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Spacer()
                
                Button(action: { toggleFavorite() }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)

                Button(action: {
                    showingExportOptions = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.green)
                            .font(.title3)
                        
                        // Show checkmark if already exported (simplified check)
                        if CalendarManager.shared.activityMightBeExported(activity, dayName: dayName) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
            }
            
            Text(activity.trainingGoal)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            if !activity.instructions.isEmpty {
                Text(String(format: "training.week.instructions_label".localized, activity.instructions))
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .onAppear { loadFavoriteStatus() }
        .confirmationDialog("training.week.export_calendar".localized, isPresented: $showingExportOptions) {
            Button("training.week.add_calendar".localized) {
                exportToCalendar()
            }
            
            Button("common.cancel".localized, role: .cancel) { }
        } message: {
            Text(String(format: "training.week.export_confirm".localized, activity.activity))
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("common.ok".localized) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func loadFavoriteStatus() {
        let predicate = #Predicate<TrainingExercise> { $0.name == activity.activity && $0.isFavorite == true }
        if let existing = try? modelContext.fetch(FetchDescriptor<TrainingExercise>(predicate: predicate)), let first = existing.first {
            isFavorite = first.isFavorite
        } else {
            isFavorite = false
        }
    }
    
    private func toggleFavorite() {
        let predicate = #Predicate<TrainingExercise> { $0.name == activity.activity }
        if let existing = try? modelContext.fetch(FetchDescriptor<TrainingExercise>(predicate: predicate)), let ex = existing.first {
            ex.isFavorite.toggle()
            isFavorite = ex.isFavorite
            try? modelContext.save()
            return
        }
        let newEx = TrainingExercise(
            name: activity.activity,
            category: nil,
            difficulty: nil,
            equipment: nil,
            instructions: activity.instructions,
            tags: activity.focus.isEmpty ? [] : [activity.focus],
            source: "plan",
            isFavorite: true
        )
        modelContext.insert(newEx)
        try? modelContext.save()
        isFavorite = true
    }
    
    private func exportToCalendar() {
        // For individual activity export, we need to find which day index this is in the training week
        // For now, we'll use the old method since we don't have access to the day index here
        CalendarManager.shared.exportActivity(activity, dayName: dayName, completion: { success, error in
            DispatchQueue.main.async {
                if success {
                    alertTitle = "training.week.export_success".localized
                    alertMessage = String(format: "training.week.export_message".localized, activity.activity, dayName, activity.time)
                    showingAlert = true
                    print("📅 Successfully exported \(activity.activity) to calendar for \(dayName)")
                } else {
                    let errorMessage = error?.localizedDescription ?? "common.error.unknown".localized
                    print("❌ Failed to export to calendar: \(errorMessage)")
                    
                    // Show user-friendly error messages
                    if errorMessage.contains("already exists") {
                        alertTitle = "training.week.already_exists".localized
                        alertMessage = String(format: "training.week.already_exists_message".localized, dayName, activity.time)
                    } else if errorMessage.contains("access denied") {
                        alertTitle = "training.week.calendar_access_required".localized
                        alertMessage = "training.week.calendar_access_message".localized
                    } else {
                        alertTitle = "training.week.export_failed".localized
                        alertMessage = String(format: "training.week.export_failed_message".localized, errorMessage)
                    }
                    showingAlert = true
                }
            }
        })
    }
}

// MARK: - Training Day Detail View
struct TrainingDayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let day: TrainingDay
    let onSave: (TrainingDay) -> Void
    
    @State private var editableDay: TrainingDay
    @State private var hasChanges = false
    
    init(day: TrainingDay, onSave: @escaping (TrainingDay) -> Void) {
        self.day = day
        self.onSave = onSave
        self._editableDay = State(initialValue: day)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Day Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(editableDay.dayName)
                                .font(.title)
                                .fontWeight(.bold)
                            Spacer()
                            Text(editableDay.theme)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.blue)
                        }
                        
                        Text(editableDay.dailyGoal)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Activities
                    VStack(alignment: .leading, spacing: 12) {
                        Text("training.week.daily_schedule".localized)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(Array(editableDay.activities.enumerated()), id: \.element.id) { index, activity in
                            TrainingActivityView(
                                activity: activity,
                                onUpdate: { updatedActivity in
                                    editableDay.activities[index] = updatedActivity
                                    hasChanges = true
                                }
                            )
                        }
                        .onDelete { indexSet in
                            editableDay.activities.remove(atOffsets: indexSet)
                            hasChanges = true
                        }
                        
                        // Add New Activity Button
                        Button(action: addNewActivity) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("training.week.add_activity".localized)
                            }
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(editableDay.dayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) {
                        onSave(editableDay)
                        dismiss()
                    }
                    .fontWeight(hasChanges ? .bold : .regular)
                }
            }
        }
    }
    
    private func addNewActivity() {
        let newActivity = TrainingActivity(
            time: "training.week.default_time".localized,
            activity: "training.week.new_activity".localized,
            duration: "training.week.default_duration".localized,
            focus: "training.week.default_focus".localized,
            instructions: "training.week.default_instructions".localized,
            trainingGoal: "training.week.default_goal".localized
        )
        editableDay.activities.append(newActivity)
        hasChanges = true
    }
}

// MARK: - Training Activity View
struct TrainingActivityView: View {
    let activity: TrainingActivity
    let onUpdate: (TrainingActivity) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var editableActivity: TrainingActivity
    @State private var isEditing = false
    @State private var editedTime: String = ""
    @State private var isFavorite = false
    @State private var showingExercisePicker = false
    
    init(activity: TrainingActivity, onUpdate: @escaping (TrainingActivity) -> Void) {
        self.activity = activity
        self.onUpdate = onUpdate
        self._editableActivity = State(initialValue: activity)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isEditing {
                    TextField("training.time".localized, text: $editableActivity.time)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 90)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            // Normalize and validate time using TimeParser
                            if let (h,m) = TimeParser.parseTime(editableActivity.time) {
                                let calendar = Calendar.current
                                var comps = DateComponents()
                                comps.hour = h; comps.minute = m
                                let df = DateFormatter();
                                df.locale = LocalizationManager.shared.getLocale()
                                df.dateStyle = .none; df.timeStyle = .short
                                if let date = calendar.date(from: comps) {
                                    editableActivity.time = df.string(from: date)
                                }
                            }
                        }
                } else {
                    Text(editableActivity.time)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                        .foregroundColor(.green)
                }
                
                if isEditing {
                    TextField("training.activity".localized, text: $editableActivity.activity)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    Text(editableActivity.activity)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Button(action: { toggleFavorite() }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .secondary)
                }
                .buttonStyle(.plain)
                
                Button(isEditing ? "common.save".localized : "common.edit".localized) {
                    withAnimation {
                        if isEditing {
                            onUpdate(editableActivity)
                        }
                        isEditing.toggle()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if isEditing {
                VStack(spacing: 8) {
                    HStack {
                        Button(action: { showingExercisePicker = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "books.vertical")
                                Text("exercise.library.choose".localized)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Spacer()
                    }
                    HStack {
                        Text("training.duration".localized)
                            .font(.caption)
                        Spacer()
                        Menu(editableActivity.duration.isEmpty ? "15 min" : editableActivity.duration) {
                            ForEach([5,10,15,20,30,45,60], id: \.self) { m in
                                Button("\(m) min") { editableActivity.duration = "\(m) minuter" }
                            }
                        }
                    }
                    HStack {
                        Text("training.focus".localized)
                            .font(.caption)
                        Spacer()
                        Menu(editableActivity.focus.isEmpty ? "-" : editableActivity.focus) {
                            ForEach(["Fysisk träning","Mental träning","Socialisering","Vila"], id: \.self) { f in
                                Button(f) { editableActivity.focus = f }
                            }
                        }
                    }
                    TextField("training.goal".localized, text: $editableActivity.trainingGoal)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("training.instructions".localized, text: $editableActivity.instructions, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "training.week.duration_label".localized, editableActivity.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "training.week.focus_label".localized, editableActivity.focus))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .italic()
                    Text(String(format: "training.week.goal_label".localized, editableActivity.trainingGoal))
                        .font(.caption)
                        .foregroundColor(.purple)
                        .italic()
                    Text(editableActivity.instructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isEditing ? Color.blue : Color.clear, lineWidth: 1)
        )
        .onAppear { loadFavoriteStatus() }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet { selected in
                // Apply selection to current activity fields
                editableActivity = TrainingActivity(
                    time: editableActivity.time,
                    activity: selected.name,
                    duration: editableActivity.duration,
                    focus: selected.category ?? (selected.tags.first ?? editableActivity.focus),
                    instructions: selected.instructions.isEmpty ? editableActivity.instructions : selected.instructions,
                    trainingGoal: editableActivity.trainingGoal
                )
            }
        }
    }

    private func loadFavoriteStatus() {
        let predicate = #Predicate<TrainingExercise> { $0.name == editableActivity.activity && $0.isFavorite == true }
        if let existing = try? modelContext.fetch(FetchDescriptor<TrainingExercise>(predicate: predicate)), let first = existing.first {
            isFavorite = first.isFavorite
        } else {
            isFavorite = false
        }
    }
    
    private func toggleFavorite() {
        // Try find an existing entry
        let predicate = #Predicate<TrainingExercise> { $0.name == editableActivity.activity }
        if let existing = try? modelContext.fetch(FetchDescriptor<TrainingExercise>(predicate: predicate)), let ex = existing.first {
            ex.isFavorite.toggle()
            isFavorite = ex.isFavorite
            try? modelContext.save()
            return
        }
        // Create new favorite entry from this activity
        let tags = editableActivity.focus.isEmpty ? [] : [editableActivity.focus]
        let newEx = TrainingExercise(
            name: editableActivity.activity,
            category: nil,
            difficulty: nil,
            equipment: nil,
            instructions: editableActivity.instructions,
            tags: tags,
            source: "plan",
            isFavorite: true
        )
        modelContext.insert(newEx)
        try? modelContext.save()
        isFavorite = true
    }
}

// MARK: - Exercise Picker Sheet
private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var searchText: String = ""
    @State private var items: [TrainingExercise] = []
    let onPick: (TrainingExercise) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered(), id: \.id) { ex in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(ex.name)
                                .font(.body)
                            Spacer()
                            if ex.isFavorite { Image(systemName: "heart.fill").foregroundColor(.red) }
                        }
                        if !ex.tags.isEmpty {
                            Text(ex.tags.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(ex.instructions)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onPick(ex); dismiss() }
                }
            }
            .navigationTitle("exercise.library.choose".localized)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("common.cancel".localized) { dismiss() } } }
            .onAppear { load() }
        }
    }

    private func load() {
        let descriptor = FetchDescriptor<TrainingExercise>()
        items = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func filtered() -> [TrainingExercise] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return items }
        let q = searchText.lowercased()
        return items.filter { ex in
            ex.name.lowercased().contains(q) || (ex.category?.lowercased().contains(q) ?? false) || ex.instructions.lowercased().contains(q) || ex.tags.joined(separator: ", ").lowercased().contains(q)
        }
    }
}


struct SuggestedTrainingWeekView_Previews: PreviewProvider {
    static var previews: some View {
        let mockDog = Dog(name: "Buddy")
        let mockAnalysis = ChatGPTAnalysis(
            summary: "Sample analysis",
            breedAnalysis: BreedAnalysis(
                breedTraits: ["Sample trait"],
                exerciseNeeds: "High",
                mentalStimulationNeeds: "High",
                commonIssues: ["Sample issue"]
            ),
            ageConsiderations: AgeConsiderations(
                developmentalStage: "adult",
                ageAppropriateExpectations: "Sample expectations",
                trainingReadiness: "High"
            ),
            behaviorAssessment: BehaviorAssessment(
                strengths: ["Sample strength"],
                concerns: ["Sample concern"],
                overallScore: 85,
                progressTrend: "improving"
            ),
            trainingRecommendations: [],
            keyInsights: ["Sample insight"],
            healthIndicators: HealthIndicators(
                exerciseLevel: "good",
                mentalStimulation: "good",
                routineConsistency: "good"
            ),
            generatedAt: Date()
        )
        
        SuggestedTrainingWeekView(dog: mockDog, analysis: mockAnalysis)
    }
}

// MARK: - Calendar Manager
class CalendarManager {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    
    private init() {}
    
    func exportActivityWithDayIndex(_ activity: TrainingActivity, dayName: String, dayIndex: Int, completion: @escaping (Bool, Error?) -> Void) {
        // Request calendar access
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            guard granted, error == nil else {
                completion(false, error ?? NSError(domain: "CalendarError", code: 1, userInfo: [NSLocalizedDescriptionKey: "training.week.calendar_access_denied".localized]))
                return
            }
            
            self?.createEventWithDayIndex(for: activity, dayName: dayName, dayIndex: dayIndex, completion: completion)
        }
    }
    
    func exportActivity(_ activity: TrainingActivity, dayName: String, completion: @escaping (Bool, Error?) -> Void) {
        // Request calendar access
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            guard granted, error == nil else {
                completion(false, error ?? NSError(domain: "CalendarError", code: 1, userInfo: [NSLocalizedDescriptionKey: "training.week.calendar_access_denied".localized]))
                return
            }
            
            self?.createEvent(for: activity, dayName: dayName, completion: completion)
        }
    }
    
    private func createEventWithDayIndex(for activity: TrainingActivity, dayName: String, dayIndex: Int, completion: @escaping (Bool, Error?) -> Void) {
        let eventTitle = "🐕 \(activity.activity)"
        
        // Use day index to calculate target date - this ensures proper mapping
        let calendar = Calendar.current
        let today = Date()
        guard let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: today) else {
            completion(false, NSError(domain: "CalendarError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not calculate target date"]))
            return
        }
        
        // Parse time with locale-aware formatting
        var startDate: Date
        let parsedTime = TimeParser.parseTime(activity.time)
        
        if let (hour, minute) = parsedTime {
            print("📅 Parsing time '\(activity.time)' -> hour: \(hour), minute: \(minute)")
            startDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDate) ?? targetDate
            print("📅 Final startDate: \(startDate)")
        } else {
            print("❌ Failed to parse time '\(activity.time)', using 9 AM fallback")
            startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: targetDate) ?? targetDate
        }
        
        // Parse duration (e.g., "20 minutes")
        var duration: TimeInterval = 1800 // Default 30 minutes
        let durationString = activity.duration.lowercased()
        if let minutes = Int(durationString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
            duration = TimeInterval(minutes * 60)
        }
        
        let endDate = startDate.addingTimeInterval(duration)
        
        // Check for duplicate events
        if eventExists(title: eventTitle, startDate: startDate, endDate: endDate) {
            completion(false, NSError(domain: "CalendarError", code: 2, userInfo: [NSLocalizedDescriptionKey: "training.week.event_already_exists".localized]))
            return
        }
        
        // Create the event
        let event = EKEvent(eventStore: eventStore)
        event.title = eventTitle
        event.notes = """
        \("training.duration".localized): \(activity.duration)
        \("training.focus".localized): \(activity.focus)
        \("training.goal".localized): \(activity.trainingGoal)
        
        \("training.instructions".localized): \(activity.instructions)
        
        \("training.week.created_by".localized)
        """
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
    
    private func createEvent(for activity: TrainingActivity, dayName: String, completion: @escaping (Bool, Error?) -> Void) {
        let eventTitle = "🐕 \(activity.activity)"
        
        // Calculate the target date for the specific weekday
        let calendar = Calendar.current
        let today = Date()
        
        // Find the next occurrence of the specified weekday
        let targetDate = getNextWeekday(dayName: dayName, from: today) ?? today
        
        // Parse time with locale-aware formatting
        var startDate: Date
        let parsedTime = TimeParser.parseTime(activity.time)
        
        if let (hour, minute) = parsedTime {
            print("📅 Parsing time '\(activity.time)' -> hour: \(hour), minute: \(minute)")
            startDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDate) ?? targetDate
            print("📅 Final startDate: \(startDate)")
        } else {
            print("❌ Failed to parse time '\(activity.time)', using 9 AM fallback")
            startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: targetDate) ?? targetDate
        }
        
        // Parse duration (e.g., "20 minutes")
        var duration: TimeInterval = 1800 // Default 30 minutes
        let durationString = activity.duration.lowercased()
        if let minutes = Int(durationString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
            duration = TimeInterval(minutes * 60)
        }
        
        let endDate = startDate.addingTimeInterval(duration)
        
        // Check for duplicate events
        if eventExists(title: eventTitle, startDate: startDate, endDate: endDate) {
            completion(false, NSError(domain: "CalendarError", code: 2, userInfo: [NSLocalizedDescriptionKey: "training.week.event_already_exists".localized]))
            return
        }
        
        // Create the event
        let event = EKEvent(eventStore: eventStore)
        event.title = eventTitle
        event.notes = """
        \("training.duration".localized): \(activity.duration)
        \("training.focus".localized): \(activity.focus)
        \("training.goal".localized): \(activity.trainingGoal)
        
        \("training.instructions".localized): \(activity.instructions)
        
        \("training.week.created_by".localized)
        """
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
    
    private func getDateForTrainingWeekDay(dayName: String, dayIndex: Int) -> Date? {
        // Map the training week day to the correct calendar date
        // The training week should start from today and continue for 7 days
        let calendar = Calendar.current
        let today = Date()
        
        // Simply add the day index to today to get the correct date
        // Day 0 = today, Day 1 = tomorrow, etc.
        return calendar.date(byAdding: .day, value: dayIndex, to: today)
    }
    
    private func getNextWeekday(dayName: String, from date: Date) -> Date? {
        let calendar = Calendar.current
        let weekdays = ["Sunday": 1, "Monday": 2, "Tuesday": 3, "Wednesday": 4, "Thursday": 5, "Friday": 6, "Saturday": 7]
        
        guard let targetWeekday = weekdays[dayName] else { return nil }
        
        // For training week activities, we want to map them to the current week starting from today
        // Get today's weekday
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        
        // Calculate the position of the target day relative to today
        // This ensures activities are scheduled starting from today
        var daysFromToday = targetWeekday - todayWeekday
        
        // If the day already passed this week, add it to next week
        if daysFromToday < 0 {
            daysFromToday += 7
        }
        
        return calendar.date(byAdding: .day, value: daysFromToday, to: today)
    }
    
    private func eventExists(title: String, startDate: Date, endDate: Date) -> Bool {
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let existingEvents = eventStore.events(matching: predicate)
        
        return existingEvents.contains { event in
            event.title == title && 
            abs(event.startDate.timeIntervalSince(startDate)) < 60 // Within 1 minute
        }
    }
    
    func activityMightBeExportedWithDayIndex(_ activity: TrainingActivity, dayName: String, dayIndex: Int) -> Bool {
        // Quick check without full calendar access - simplified for UI
        let eventTitle = "🐕 \(activity.activity)"
        let calendar = Calendar.current
        let today = Date()
        
        guard let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: today) else { return false }
        
        // Parse time with locale-aware formatting
        var startDate: Date
        let parsedTime = TimeParser.parseTime(activity.time)
        
        if let (hour, minute) = parsedTime {
            startDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDate) ?? targetDate
        } else {
            startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: targetDate) ?? targetDate
        }
        
        let endDate = startDate.addingTimeInterval(1800) // 30 min default
        
        return eventExists(title: eventTitle, startDate: startDate, endDate: endDate)
    }
    
    func activityMightBeExported(_ activity: TrainingActivity, dayName: String) -> Bool {
        // Quick check without full calendar access - simplified for UI
        let eventTitle = "🐕 \(activity.activity)"
        let calendar = Calendar.current
        let today = Date()
        
        guard let targetDate = getNextWeekday(dayName: dayName, from: today) else { return false }
        
        // Parse time with locale-aware formatting
        var startDate: Date
        let parsedTime = TimeParser.parseTime(activity.time)
        
        if let (hour, minute) = parsedTime {
            startDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: targetDate) ?? targetDate
        } else {
            startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: targetDate) ?? targetDate
        }
        
        let endDate = startDate.addingTimeInterval(1800) // 30 min default
        
        return eventExists(title: eventTitle, startDate: startDate, endDate: endDate)
    }
}

// MARK: - Time Parser
class TimeParser {
    static func parseTime(_ timeString: String) -> (hour: Int, minute: Int)? {
        let currentLocale = Locale.current
        let userTimeZone = TimeZone.current
        
        // Check if user is likely in a 12-hour format region
        let uses12HourFormat = uses12HourClock(locale: currentLocale, timeZone: userTimeZone)
        
        print("🌍 User locale: \(currentLocale.identifier), TimeZone: \(userTimeZone.identifier)")
        print("🕐 Uses 12-hour format: \(uses12HourFormat)")
        
        if uses12HourFormat {
            // Try 12-hour formats first (US, Canada, etc.)
            if let time = parse12HourFormat(timeString) {
                return time
            }
            // Fallback to 24-hour
            return parse24HourFormat(timeString)
        } else {
            // Try 24-hour formats first (Europe, most of world)
            if let time = parse24HourFormat(timeString) {
                return time
            }
            // Fallback to 12-hour
            return parse12HourFormat(timeString)
        }
    }
    
    private static func uses12HourClock(locale: Locale, timeZone: TimeZone) -> Bool {
        // Check locale preferences
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.timeStyle = .short
        
        let sampleTime = Date()
        let formattedTime = dateFormatter.string(from: sampleTime)
        
        // If formatted time contains AM/PM, user prefers 12-hour
        let contains12HourIndicators = formattedTime.uppercased().contains("AM") || 
                                      formattedTime.uppercased().contains("PM") ||
                                      formattedTime.contains("上午") || // Chinese AM
                                      formattedTime.contains("下午")    // Chinese PM
        
        print("🕐 Sample formatted time: '\(formattedTime)' -> 12h format: \(contains12HourIndicators)")
        
        return contains12HourIndicators
    }
    
    private static func parse12HourFormat(_ timeString: String) -> (hour: Int, minute: Int)? {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try various 12-hour formats
        let formats = ["h:mm a", "h:mma", "h a", "ha", "h:mm A", "h:mmA", "h A", "hA"]
        
        for format in formats {
            timeFormatter.dateFormat = format
            if let time = timeFormatter.date(from: timeString) {
                let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                if let hour = components.hour, let minute = components.minute {
                    print("✅ Parsed '\(timeString)' as 12h format '\(format)' -> \(hour):\(minute)")
                    return (hour, minute)
                }
            }
        }
        
        print("❌ Failed to parse '\(timeString)' as 12-hour format")
        return nil
    }
    
    private static func parse24HourFormat(_ timeString: String) -> (hour: Int, minute: Int)? {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale.current
        
        // Try various 24-hour formats
        let formats = ["HH:mm", "H:mm", "HH.mm", "H.mm", "HH", "H"]
        
        for format in formats {
            timeFormatter.dateFormat = format
            if let time = timeFormatter.date(from: timeString) {
                let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                if let hour = components.hour, let minute = components.minute {
                    print("✅ Parsed '\(timeString)' as 24h format '\(format)' -> \(hour):\(minute)")
                    return (hour, minute)
                }
            }
        }
        
        print("❌ Failed to parse '\(timeString)' as 24-hour format")
        return nil
    }
    
    static func getPreferredTimeFormat() -> String {
        let currentLocale = Locale.current
        let userTimeZone = TimeZone.current
        let uses12Hour = uses12HourClock(locale: currentLocale, timeZone: userTimeZone)
        return uses12Hour ? "12-hour" : "24-hour"
    }
}
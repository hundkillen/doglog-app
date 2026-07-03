import SwiftUI

struct AIInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    let dog: Dog
    let currentMonth: Date
    @State private var insights: AIPatternAnalyzer.DogInsights?
    @State private var laggedPatterns: [LaggedPattern] = []
    @State private var chatGPTAnalysis: ChatGPTAnalysis?
    @State private var chatGPTNoteTips: [String] = []
    @State private var isLoading = true
    @State private var isChatGPTLoading = false
    @State private var showingInfoPopup = false
    @State private var selectedInfo: InfoPopupContent?
    @State private var analysisTimeRange: AIPatternAnalyzer.AnalysisTimeRange = .allTime
    @State private var showingChatGPTSettings = false
    @State private var chatGPTError: String?
    @State private var selectedAISource: AISource = .local
    private let aiSourceDefaultsKey = "ai_insights_selected_source"
    
    private let analyzer = AIPatternAnalyzer()
    @ObservedObject private var chatGPTService = ChatGPTService.shared
    
    enum AISource: String, CaseIterable {
        case local = "ai.source.local"
        case chatgpt = "ai.source.chatgpt"
        
        var icon: String {
            switch self {
            case .local: return "brain.head.profile"
            case .chatgpt: return "brain.filled.head.profile"
            }
        }
        
        var color: Color {
            switch self {
            case .local: return .blue
            case .chatgpt: return .purple
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        VStack(spacing: 20) {
                            DrEliasAvatarView(isThinking: true, size: .large, showName: false)
                            
                            VStack(spacing: 8) {
                                Text("dr.dr_elias".localized)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("ai.analyzing".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let insights = insights {
                        // Confidence indicator
                        ConfidenceIndicatorView(confidence: insights.confidence) { showInfoPopup(InfoPopupContent.confidence(insights.confidence)) }
                        
                        // AI Source Selector
                        AISourceSelectorView(selectedSource: $selectedAISource)
                        
                        // Show selected AI analysis
                        if selectedAISource == .local {
                            // Lagged (day-after) patterns — the core product insight
                            LaggedPatternsView(patterns: laggedPatterns)

                            // Local AI Analysis
                            LocalAIAnalysisView(insights: insights)
                        } else {
                                // ChatGPT Analysis Section
                            ChatGPTAnalysisView(
                                dog: dog,
                                analysis: chatGPTAnalysis,
                                isLoading: isChatGPTLoading,
                                error: chatGPTError,
                                hasAPIKey: chatGPTService.hasValidAPIKey,
                                hasCachedAnalysis: chatGPTService.hasCachedAnalysis(dogId: dog.id, timeRange: analysisTimeRange),
                                onAnalyze: { generateChatGPTAnalysis(); generateChatGPTNoteTips() },
                                onSettings: { showingChatGPTSettings = true }
                            )
                            if !chatGPTNoteTips.isEmpty {
                                NoteRecommendationsView(tips: chatGPTNoteTips)
                            }
                        }
                        
                        // Overall mood section
                        MoodTrendView(moodTrend: insights.overallMood) { showInfoPopup(InfoPopupContent.moodTrend(insights.overallMood)) }
                        
                        // Activity patterns
                        if !insights.activityPatterns.isEmpty {
                            ActivityPatternsView(patterns: insights.activityPatterns) { pattern in 
                                showInfoPopup(InfoPopupContent.activityPattern(pattern))
                            }
                        }
                        
                        // Weekly trends
                        WeeklyTrendsView(weeklyTrends: insights.weeklyTrends) { showInfoPopup(InfoPopupContent.weeklyTrends(insights.weeklyTrends)) }
                        
                        // Behavior insights
                        if !insights.behaviorInsights.isEmpty {
                            BehaviorInsightsView(insights: insights.behaviorInsights) { insight in
                                showInfoPopup(InfoPopupContent.behaviorInsight(insight))
                            }
                        }
                        
                        // Recommendations
                        if !insights.recommendations.isEmpty {
                            RecommendationsView(recommendations: insights.recommendations) { recommendation in
                                showInfoPopup(InfoPopupContent.recommendation(recommendation))
                            }
                        }

                        // Note-based tips (local) – show only when Local AI is selected
                        if selectedAISource == .local && !insights.noteRecommendations.isEmpty {
                            NoteRecommendationsView(tips: insights.noteRecommendations)
                        }
                    } else {
                        Text("error.no_data".localized)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding()
            }
            .navigationTitle("ai.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Time range picker
                    Picker("ai.time_range".localized, selection: $analysisTimeRange) {
                        Text("time.all_time".localized).tag(AIPatternAnalyzer.AnalysisTimeRange.allTime)
                        Text("time.this_month".localized).tag(AIPatternAnalyzer.AnalysisTimeRange.thisMonth(currentMonth))
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 160)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingInfoPopup) {
            if let info = selectedInfo {
                InfoPopupView(content: info)
            }
        }
        .sheet(isPresented: $showingChatGPTSettings) {
            ChatGPTSettingsView()
        }
        .onAppear {
            // Load last selected AI source
            if let raw = UserDefaults.standard.string(forKey: aiSourceDefaultsKey), let saved = AISource(rawValue: raw) {
                selectedAISource = saved
            }
            generateInsights()
        }
        .onChange(of: analysisTimeRange) { _ in
            generateInsights()
            chatGPTAnalysis = nil // Reset ChatGPT analysis when time range changes
            chatGPTNoteTips = []
        }
        .onChange(of: selectedAISource) { _, newSource in
            // Persist selection
            UserDefaults.standard.set(newSource.rawValue, forKey: aiSourceDefaultsKey)
            if newSource == .chatgpt && chatGPTService.hasValidAPIKey && chatGPTService.hasCachedAnalysis(dogId: dog.id, timeRange: analysisTimeRange) && chatGPTAnalysis == nil {
                generateChatGPTAnalysis()
                generateChatGPTNoteTips()
            }
        }
    }
    
    private func generateInsights() {
        isLoading = true
        
        // Simulate AI processing time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            insights = analyzer.analyzeDog(dog, timeRange: analysisTimeRange)
            laggedPatterns = LaggedPatternAnalyzer().analyze(dog: dog)
            isLoading = false
        }
    }
    
    private func showInfoPopup(_ content: InfoPopupContent) {
        selectedInfo = content
        showingInfoPopup = true
    }
    
    private func generateChatGPTAnalysis() {
        guard let localInsights = insights else { return }
        
        isChatGPTLoading = true
        chatGPTError = nil
        
        Task {
            do {
                let analysis = try await chatGPTService.analyzeWithChatGPT(
                    dog: dog,
                    timeRange: analysisTimeRange,
                    localInsights: localInsights
                )
                
                await MainActor.run {
                    chatGPTAnalysis = analysis
                    isChatGPTLoading = false
                }
            } catch {
                await MainActor.run {
                    chatGPTError = error.localizedDescription
                    isChatGPTLoading = false
                }
            }
        }
    }

    private func generateChatGPTNoteTips() {
        Task {
            do {
                // Pass local tips to exclude duplicates from Barkley
                let localTips = insights?.noteRecommendations ?? []
                let tips = try await chatGPTService.generateNoteGuidance(dog: dog, timeRange: analysisTimeRange, excludeTips: localTips)
                await MainActor.run { chatGPTNoteTips = tips }
            } catch {
                // Silent fail for tips; don't block UI
            }
        }
    }
}

// MARK: - Lagged Patterns View
struct LaggedPatternsView: View {
    let patterns: [LaggedPattern]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.indigo)
                Text("lagged.section_title".localized)
                    .font(.headline)
                Spacer()
            }

            if patterns.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.secondary)
                        .font(.title3)
                    Text("lagged.empty_state".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(patterns.enumerated()), id: \.offset) { _, pattern in
                        LaggedPatternRowView(pattern: pattern)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct LaggedPatternRowView: View {
    let pattern: LaggedPattern

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: pattern.direction == .negative ? "arrow.down.right.circle" : "arrow.up.right.circle")
                .foregroundColor(pattern.direction == .negative ? .red : .green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(pattern.localizedDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(String(format: "lagged.sample_caption".localized, pattern.sampleCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            (pattern.direction == .negative ? Color.red : Color.green).opacity(0.08)
        )
        .cornerRadius(8)
    }
}

// MARK: - Confidence Indicator
struct ConfidenceIndicatorView: View {
    let confidence: Double
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("ai.confidence".localized)
                    .font(.headline)
                Spacer()
                Text("\(Int(confidence * 100))%")
                    .font(.headline)
                    .foregroundColor(confidenceColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(confidenceColor)
                        .frame(width: geometry.size.width * confidence, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Text(confidenceDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
    
    private var confidenceColor: Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.5 { return .orange }
        return .red
    }
    
    private var confidenceDescription: String {
        if confidence >= 0.8 { return "ai.high_confidence".localized }
        if confidence >= 0.5 { return "ai.moderate_confidence".localized }
        return "ai.low_confidence".localized
    }
}

// MARK: - Mood Trend View
struct MoodTrendView: View {
    let moodTrend: AIPatternAnalyzer.MoodTrend
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: moodIcon)
                    .foregroundColor(moodColor)
                Text("ai.overall_mood".localized)
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text(String(format: "insights.current".localized, moodTrend.current.capitalized))
                        .font(.subheadline)
                        .foregroundColor(moodColor)
                    
                    Text(String(format: "insights.trend".localized, trendDescription))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(Int(moodTrend.improvement.isFinite ? moodTrend.improvement : 0))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(moodTrend.improvement >= 0 ? .green : .red)
                    
                    Text("ai.change".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
    }
    
    private var moodIcon: String {
        switch moodTrend.current {
        case "good": return "face.smiling"
        case "bad": return "face.dashed"
        default: return "minus.circle"
        }
    }
    
    private var moodColor: Color {
        switch moodTrend.current {
        case "good": return .green
        case "bad": return .red
        default: return .orange
        }
    }
    
    private var trendDescription: String {
        switch moodTrend.direction {
        case .up: return "ai.improving_trend".localized
        case .down: return "ai.declining_trend".localized
        case .stable: return "ai.stable_trend".localized
        }
    }
}

// MARK: - Activity Patterns View
struct ActivityPatternsView: View {
    let patterns: [AIPatternAnalyzer.ActivityPattern]
    let onPatternTap: (AIPatternAnalyzer.ActivityPattern) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("ai.activity_patterns".localized)
                    .font(.headline)
                Spacer()
            }
            
            LazyVStack(spacing: 8) {
                ForEach(Array(patterns.enumerated()), id: \.offset) { index, pattern in
                    ActivityPatternRowView(pattern: pattern)
                        .onTapGesture {
                            onPatternTap(pattern)
                        }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ActivityPatternRowView: View {
    let pattern: AIPatternAnalyzer.ActivityPattern
    
    var body: some View {
        HStack {
            Image(systemName: ActivityCatalog.shared.iconName(forStoredType: pattern.activityType))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ActivityCatalog.shared.displayName(forStoredType: pattern.activityType))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(String(format: "insights.success_rate_frequency".localized, pattern.frequency, Int(pattern.successRate * 100)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(outcomeColor(pattern.averageOutcome))
                    .frame(width: 12, height: 12)
                
                Image(systemName: trendIcon(pattern.trend))
                    .foregroundColor(trendColor(pattern.trend))
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func outcomeColor(_ outcome: String) -> Color {
        switch outcome {
        case "good": return .green
        case "bad": return .red
        default: return .orange
        }
    }
    
    private func trendIcon(_ trend: AIPatternAnalyzer.PatternTrend) -> String {
        switch trend {
        case .improving: return "arrow.up"
        case .declining: return "arrow.down"
        case .stable: return "minus"
        case .insufficient_data: return "questionmark"
        }
    }
    
    private func trendColor(_ trend: AIPatternAnalyzer.PatternTrend) -> Color {
        switch trend {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .blue
        case .insufficient_data: return .gray
        }
    }
}

// MARK: - Weekly Trends View
struct WeeklyTrendsView: View {
    let weeklyTrends: AIPatternAnalyzer.WeeklyTrend
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.purple)
                Text("ai.weekly_patterns".localized)
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ai.best_days".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(weeklyTrends.bestDays, id: \.self) { day in
                        Text("• \(day)")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ai.avg_activities".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", weeklyTrends.averageActivitiesPerDay))" + "ai.per_day".localized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Behavior Insights View
struct BehaviorInsightsView: View {
    let insights: [AIPatternAnalyzer.BehaviorInsight]
    let onInsightTap: (AIPatternAnalyzer.BehaviorInsight) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("ai.key_insights".localized)
                    .font(.headline)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                    InsightRowView(insight: insight)
                        .onTapGesture {
                            onInsightTap(insight)
                        }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct InsightRowView: View {
    let insight: AIPatternAnalyzer.BehaviorInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(insight.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(insight.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .padding(12)
        .background(categoryColor(insight.category).opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(categoryColor(insight.category), lineWidth: 1)
        )
    }
    
    private func categoryColor(_ category: AIPatternAnalyzer.InsightCategory) -> Color {
        switch category {
        case .behavior: return .blue
        case .health: return .red
        case .activity: return .green
        case .mood: return .orange
        case .routine: return .purple
        }
    }
}

// MARK: - Recommendations View
struct RecommendationsView: View {
    let recommendations: [AIPatternAnalyzer.Recommendation]
    let onRecommendationTap: (AIPatternAnalyzer.Recommendation) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.green)
                Text("ai.recommendations".localized)
                    .font(.headline)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                    RecommendationRowView(recommendation: recommendation)
                        .onTapGesture {
                            onRecommendationTap(recommendation)
                        }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct RecommendationRowView: View {
    let recommendation: AIPatternAnalyzer.Recommendation
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Circle()
                    .fill(priorityColor(recommendation.priority))
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(priorityColor(recommendation.priority).opacity(0.3))
                    .frame(width: 2)
            }
            .frame(height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(priorityText(recommendation.priority))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor(recommendation.priority).opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(priorityColor(recommendation.priority))
                }
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func priorityColor(_ priority: AIPatternAnalyzer.RecommendationPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
    
    private func priorityText(_ priority: AIPatternAnalyzer.RecommendationPriority) -> String {
        switch priority {
        case .high: return "priority.high".localized
        case .medium: return "priority.medium".localized
        case .low: return "priority.low".localized
        }
    }
}

struct NoteRecommendationsView: View {
    let tips: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "highlighter")
                    .foregroundColor(.orange)
                Text("insights.note_recommendations".localized)
                    .font(.headline)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundColor(.orange)
                        Text(tip).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Info Popup Content
enum InfoPopupContent {
    case confidence(Double)
    case moodTrend(AIPatternAnalyzer.MoodTrend)
    case activityPattern(AIPatternAnalyzer.ActivityPattern)
    case weeklyTrends(AIPatternAnalyzer.WeeklyTrend)
    case behaviorInsight(AIPatternAnalyzer.BehaviorInsight)
    case recommendation(AIPatternAnalyzer.Recommendation)
    
    var title: String {
        switch self {
        case .confidence: return "ai.confidence".localized
        case .moodTrend: return "insights.mood_trend_analysis".localized
        case .activityPattern: return "insights.activity_pattern".localized
        case .weeklyTrends: return "ai.weekly_patterns".localized
        case .behaviorInsight: return "insights.behavior_insight".localized
        case .recommendation: return "insights.ai_recommendation".localized
        }
    }
    
    var description: String {
        switch self {
        case .confidence(let confidence):
            let percentage = Int(confidence * 100)
            return """
            \("insights.confidence_explanation".localized)
            
            \("ai.current".localized): \(percentage)%
            
            • \("insights.high_confidence_desc".localized)
            • \("insights.medium_confidence_desc".localized)
            • \("insights.low_confidence_desc".localized)
            
            \("insights.more_data_explanation".localized)
            """
            
        case .moodTrend(let trend):
            return """
            \("insights.mood_trend_explanation".localized)
            
            \("ai.current".localized): \(trend.current.capitalized)
            \("ai.trend".localized): \(trend.direction == .up ? "ai.improving".localized : trend.direction == .down ? "ai.declining".localized : "ai.stable".localized)
            \("insights.improvement".localized): \(Int(trend.improvement.isFinite ? trend.improvement : 0))%
            
            • \("insights.good_days_desc".localized)
            • \("insights.okay_days_desc".localized)
            • \("insights.bad_days_desc".localized)
            
            \("insights.ai_analysis_explanation".localized)
            """
            
        case .activityPattern(let pattern):
            return """
            \("insights.activity_pattern_explanation".localized)
            
            \("training.activity".localized): \(ActivityCatalog.shared.displayName(forStoredType: pattern.activityType))
            \("insights.success_rate".localized): \(Int(pattern.successRate * 100))%
            \("ai.frequency".localized): \(pattern.frequency) \("insights.times_per_week".localized)
            
            • \("insights.success_rate_explanation".localized)
            • \("insights.frequency_explanation".localized)
            • \("insights.trend_explanation".localized)
            
            \("insights.activity_recommendation".localized)
            """
            
        case .weeklyTrends(let trends):
            return """
            \("insights.weekly_pattern_explanation".localized)
            
            \("ai.avg_activities".localized): \(String(format: "%.1f", trends.averageActivitiesPerDay))
            
            • \("insights.best_days_explanation".localized)
            • \("insights.worst_days_explanation".localized)
            • \("insights.activity_distribution".localized)
            
            \("insights.scheduling_recommendation".localized)
            """
            
        case .behaviorInsight(let insight):
            return """
            \(insight.description)
            
            \("ai.confidence".localized): \(Int(insight.confidence * 100))%
            \("insights.category".localized): \(insight.category)
            
            \("insights.insight_generation_explanation".localized)
            """
            
        case .recommendation(let recommendation):
            return """
            \(recommendation.description)
            
            \("insights.priority".localized): \(recommendation.priority)
            \("insights.category".localized): \(recommendation.category)
            
            \("insights.recommendation_explanation".localized)
            
            • \("insights.high_priority_desc".localized)
            • \("insights.medium_priority_desc".localized)
            • \("insights.low_priority_desc".localized)
            """
        }
    }
}

// MARK: - Info Popup View
struct InfoPopupView: View {
    @Environment(\.dismiss) private var dismiss
    let content: InfoPopupContent
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(content.description)
                        .font(.body)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                }
                .padding()
            }
            .navigationTitle(content.title)
            .navigationBarTitleDisplayMode(.large)
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

// MARK: - ChatGPT Analysis View
struct ChatGPTAnalysisView: View {
    let dog: Dog
    let analysis: ChatGPTAnalysis?
    let isLoading: Bool
    let error: String?
    let hasAPIKey: Bool
    let hasCachedAnalysis: Bool
    let onAnalyze: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.filled.head.profile")
                    .foregroundColor(.purple)
                Text("chatgpt.title".localized)
                    .font(.headline)
                Spacer()
                
                if !hasAPIKey {
                    Button("chatgpt.setup".localized) {
                        onSettings()
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(6)
                } else {
                    Button(action: onSettings) {
                        Image(systemName: "gear")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !hasAPIKey {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ai.professional_insights_available".localized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("chatgpt.description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("chatgpt.add_api_key".localized) {
                        onSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else if let analysis = analysis {
                ChatGPTResultView(dog: dog, analysis: analysis)
            } else if isLoading {
                DrEliasThinkingView("ai.getting_professional_analysis".localized)
                    .padding(.vertical, 8)
            } else if let error = error {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("chatgpt.analysis_failed".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("chatgpt.try_again".localized) {
                        onAnalyze()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if hasCachedAnalysis {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("chatgpt.previous_analysis".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("chatgpt.professional_description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !hasCachedAnalysis {
                        Button("chatgpt.generate_analysis".localized) {
                            onAnalyze()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("chatgpt.analysis_complete".localized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - ChatGPT Result View
struct ChatGPTResultView: View {
    let dog: Dog
    let analysis: ChatGPTAnalysis
    @State private var showingSuggestedTrainingWeek = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Barkley header
            DrEliasResultHeaderView(profileStyle: true)
                .padding(.bottom, 8)
            
            // Summary
            summarySection
            
            // Breed Analysis  
            breedAnalysisSection
            
            // Age Development
            ageDevelopmentSection
            
            // Behavior Assessment
            behaviorAssessmentSection
            
            // Lagged (day-after) patterns found by the AI
            laggedPatternsSection
            
            // Training Recommendations
            trainingRecommendationsSection
            
            // Key Insights
            keyInsightsSection
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("chatgpt.professional_summary".localized)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(analysis.summary)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var breedAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("chatgpt.breed_analysis".localized)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("chatgpt.breed_traits".localized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                ForEach(analysis.breedAnalysis.breedTraits, id: \.self) { trait in
                    Text("• \(trait)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if !analysis.breedAnalysis.commonIssues.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("chatgpt.common_issues".localized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    ForEach(analysis.breedAnalysis.commonIssues, id: \.self) { issue in
                        Text("• \(issue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var ageDevelopmentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("chatgpt.age_development".localized)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(String(format: "insights.stage".localized, analysis.ageConsiderations.developmentalStage.capitalized))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.purple)
            
            Text(analysis.ageConsiderations.ageAppropriateExpectations)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var behaviorAssessmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("chatgpt.behavior_assessment".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(analysis.behaviorAssessment.overallScore)/100")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(analysis.behaviorAssessment.overallScore))
            }
            
            HStack {
                Text(String(format: "insights.score_trend".localized, analysis.behaviorAssessment.progressTrend.capitalized))
                    .font(.caption)
                    .foregroundColor(trendColor(analysis.behaviorAssessment.progressTrend))
                Spacer()
            }
            
            if !analysis.behaviorAssessment.strengths.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("chatgpt.strengths".localized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    ForEach(analysis.behaviorAssessment.strengths, id: \.self) { strength in
                        Text("• \(strength)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !analysis.behaviorAssessment.concerns.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("chatgpt.areas_for_improvement".localized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    ForEach(analysis.behaviorAssessment.concerns, id: \.self) { concern in
                        Text("• \(concern)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var laggedPatternsSection: some View {
        if let patterns = analysis.laggedPatterns, !patterns.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("lagged.section_title".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(Array(patterns.enumerated()), id: \.offset) { _, pattern in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "arrow.down.right.circle")
                                .foregroundColor(.indigo)
                                .font(.caption)
                            Text("\(pattern.cause) → \(pattern.effect)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Text(pattern.evidence)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(pattern.recommendation)
                            .font(.caption2)
                            .foregroundColor(.indigo)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.indigo.opacity(0.08))
                    .cornerRadius(6)
                }
            }
        }
    }
    
    private var trainingRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !analysis.trainingRecommendations.isEmpty {
                Text("chatgpt.training_recommendations".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(Array(analysis.trainingRecommendations.prefix(3)), id: \.issue) { recommendation in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(recommendation.technique)
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Text(recommendation.priority.uppercased())
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(priorityColor(recommendation.priority).opacity(0.2))
                                .cornerRadius(3)
                                .foregroundColor(priorityColor(recommendation.priority))
                        }
                        
                        Text(String(format: "insights.issue".localized, recommendation.issue))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "insights.duration_frequency".localized, recommendation.duration, recommendation.frequency))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                        
                        if !recommendation.steps.isEmpty {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("chatgpt.steps".localized)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                ForEach(Array(recommendation.steps.enumerated()), id: \.offset) { index, step in
                                    Text("\(index + 1). \(step)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
            }
            
            // Suggested Training Week Button
            Button(action: {
                showingSuggestedTrainingWeek = true
            }) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                    Text("insights.view_training_week".localized)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.green.opacity(0.1), .blue.opacity(0.1)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
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
        }
    }
    
    private var keyInsightsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !analysis.keyInsights.isEmpty {
                Text("chatgpt.key_insights".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ForEach(analysis.keyInsights, id: \.self) { insight in
                    Text("• \(insight)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Generated timestamp
            HStack {
                Spacer()
                Text("\("insights.generated_relative".localized) \(analysis.generatedAt, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingSuggestedTrainingWeek) {
            SuggestedTrainingWeekView(dog: dog, analysis: analysis)
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }
    
    private func trendColor(_ trend: String) -> Color {
        switch trend.lowercased() {
        case "improving": return .green
        case "declining": return .red
        case "stable": return .blue
        default: return .gray
        }
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .blue
        default: return .gray
        }
    }
}

struct AIAnalysisTypesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("insights.analysis_types".localized)
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                // Local AI Analysis
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("insights.local_analysis".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("insights.local_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // ChatGPT Analysis  
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "brain.filled.head.profile")
                        .foregroundColor(.purple)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("insights.expert_analysis".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("insights.expert_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - AI Source Selector View
struct AISourceSelectorView: View {
    @Binding var selectedSource: AIInsightsView.AISource
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ai.source.title".localized)
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                ForEach(AIInsightsView.AISource.allCases, id: \.self) { source in
                    Button(action: {
                        selectedSource = source
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: source.icon)
                                .foregroundColor(source.color)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.rawValue.localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text(source == .local ? "ai.source.local.description".localized : "ai.source.chatgpt.description".localized)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedSource == source {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(source.color)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(selectedSource == source ? source.color.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedSource == source ? source.color : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Local AI Analysis View  
struct LocalAIAnalysisView: View {
    let insights: AIPatternAnalyzer.DogInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("ai.source.local.full".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Text("ai.source.local.always_available".localized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
                    .foregroundColor(.blue)
            }
            
            // Quick insights
            VStack(alignment: .leading, spacing: 8) {
                Text("ai.key_insights".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(Array(insights.behaviorInsights.prefix(3).enumerated()), id: \.offset) { index, insight in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.blue)
                        Text(insight.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text("ai.source.local.explanation".localized)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct AIInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDog = Dog(name: "ui.sample_dog_name".localized)
        AIInsightsView(dog: sampleDog, currentMonth: Date())
    }
}
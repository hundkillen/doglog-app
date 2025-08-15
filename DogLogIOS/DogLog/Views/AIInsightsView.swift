import SwiftUI

struct AIInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    let dog: Dog
    let currentMonth: Date
    @State private var insights: AIPatternAnalyzer.DogInsights?
    @State private var chatGPTAnalysis: ChatGPTAnalysis?
    @State private var isLoading = true
    @State private var isChatGPTLoading = false
    @State private var showingInfoPopup = false
    @State private var selectedInfo: InfoPopupContent?
    @State private var analysisTimeRange: AIPatternAnalyzer.AnalysisTimeRange = .allTime
    @State private var showingChatGPTSettings = false
    @State private var chatGPTError: String?
    
    private let analyzer = AIPatternAnalyzer()
    @ObservedObject private var chatGPTService = ChatGPTService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Analyzing patterns...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let insights = insights {
                        // Confidence indicator
                        ConfidenceIndicatorView(confidence: insights.confidence) { showInfoPopup(InfoPopupContent.confidence(insights.confidence)) }
                        
                        // ChatGPT Analysis Section
                        ChatGPTAnalysisView(
                            analysis: chatGPTAnalysis,
                            isLoading: isChatGPTLoading,
                            error: chatGPTError,
                            hasAPIKey: chatGPTService.hasValidAPIKey,
                            hasCachedAnalysis: chatGPTService.hasCachedAnalysis(dogId: dog.id, timeRange: analysisTimeRange),
                            onAnalyze: { generateChatGPTAnalysis() },
                            onSettings: { showingChatGPTSettings = true }
                        )
                        
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
                    } else {
                        Text("Unable to generate insights")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding()
            }
            .navigationTitle("🧠 AI Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Time range picker
                    Picker("Time Range", selection: $analysisTimeRange) {
                        Text("All Time").tag(AIPatternAnalyzer.AnalysisTimeRange.allTime)
                        Text("This Month").tag(AIPatternAnalyzer.AnalysisTimeRange.thisMonth(currentMonth))
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 160)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
            generateInsights()
        }
        .onChange(of: analysisTimeRange) { _ in
            generateInsights()
            chatGPTAnalysis = nil // Reset ChatGPT analysis when time range changes
        }
    }
    
    private func generateInsights() {
        isLoading = true
        
        // Simulate AI processing time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            insights = analyzer.analyzeDog(dog, timeRange: analysisTimeRange)
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
                Text("AI Confidence")
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
        if confidence >= 0.8 { return "High confidence - based on substantial data" }
        if confidence >= 0.5 { return "Moderate confidence - more data will improve accuracy" }
        return "Low confidence - keep logging to unlock better insights"
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
                Text("Overall Mood")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Current: \(moodTrend.current.capitalized)")
                        .font(.subheadline)
                        .foregroundColor(moodColor)
                    
                    Text("Trend: \(trendDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(Int(moodTrend.improvement))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(moodTrend.improvement >= 0 ? .green : .red)
                    
                    Text("change")
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
        default: return "face.neutral"
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
        case .up: return "Improving ↗"
        case .down: return "Declining ↘"
        case .stable: return "Stable →"
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
                Text("Activity Patterns")
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
            VStack(alignment: .leading, spacing: 4) {
                Text(pattern.activityType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(pattern.frequency)x/week • \(Int(pattern.successRate * 100))% success")
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
                Text("Weekly Patterns")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best Days")
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
                    Text("Avg Activities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", weeklyTrends.averageActivitiesPerDay))/day")
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
                Text("Key Insights")
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
                Text("Recommendations")
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
        case .high: return "HIGH"
        case .medium: return "MED"
        case .low: return "LOW"
        }
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
        case .confidence: return "AI Confidence"
        case .moodTrend: return "Mood Trend Analysis"
        case .activityPattern: return "Activity Pattern"
        case .weeklyTrends: return "Weekly Patterns"
        case .behaviorInsight: return "Behavior Insight"
        case .recommendation: return "AI Recommendation"
        }
    }
    
    var description: String {
        switch self {
        case .confidence(let confidence):
            let percentage = Int(confidence * 100)
            return """
            The AI confidence level indicates how reliable these insights are based on the amount of data available.
            
            Current confidence: \(percentage)%
            
            • High (80%+): Based on substantial data, insights are very reliable
            • Medium (50-79%): Moderate reliability, more data will improve accuracy
            • Low (<50%): Limited data available, keep logging for better insights
            
            The more activities and daily ratings you log, the more accurate and personalized the AI insights become.
            """
            
        case .moodTrend(let trend):
            return """
            Mood trend analysis tracks your dog's overall emotional state over time.
            
            Current mood: \(trend.current.capitalized)
            Trend: \(trend.direction == .up ? "Improving" : trend.direction == .down ? "Declining" : "Stable")
            Improvement: \(Int(trend.improvement))%
            
            • Good days: Positive activities and high energy
            • Okay days: Normal behavior, some mixed outcomes
            • Bad days: Challenging behaviors or low energy
            
            The AI looks at daily ratings and activity outcomes to identify patterns and predict trends.
            """
            
        case .activityPattern(let pattern):
            return """
            Activity pattern analysis shows how well specific activities work for your dog.
            
            Activity: \(pattern.activityType)
            Success rate: \(Int(pattern.successRate * 100))%
            Frequency: \(pattern.frequency) times per week
            
            • Success rate: Percentage of "good" outcomes for this activity
            • Frequency: How often you do this activity
            • Trend: Whether outcomes are improving, declining, or stable
            
            Activities with high success rates should be done more often, while low-success activities might need adjustment.
            """
            
        case .weeklyTrends(let trends):
            return """
            Weekly pattern analysis identifies which days work best for your dog.
            
            Average activities per day: \(String(format: "%.1f", trends.averageActivitiesPerDay))
            
            • Best days: Days when your dog typically has good outcomes
            • Worst days: Days that tend to be more challenging
            • Activity distribution: How activities are spread across the week
            
            Use this information to schedule important activities on your dog's best days.
            """
            
        case .behaviorInsight(let insight):
            return """
            \(insight.description)
            
            Confidence: \(Int(insight.confidence * 100))%
            Category: \(insight.category)
            
            This insight was generated by analyzing patterns in your dog's activity data and daily ratings. The AI looks for correlations, trends, and anomalies to provide personalized observations about your dog's behavior.
            """
            
        case .recommendation(let recommendation):
            return """
            \(recommendation.description)
            
            Priority: \(recommendation.priority)
            Category: \(recommendation.category)
            
            This recommendation is based on patterns the AI identified in your dog's data. Recommendations are prioritized by potential impact on your dog's wellbeing and behavior.
            
            • High priority: Important for health or behavior improvement
            • Medium priority: Beneficial for optimization
            • Low priority: Nice-to-have improvements
            """
        }
    }
}

// MARK: - Info Popup View
struct InfoPopupView: View {
    @Environment(\.dismiss) private var dismiss
    let content: InfoPopupContent
    
    var body: some View {
        NavigationView {
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
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ChatGPT Analysis View
struct ChatGPTAnalysisView: View {
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
                Text("ChatGPT Professional Analysis")
                    .font(.headline)
                Spacer()
                
                if !hasAPIKey {
                    Button("Setup") {
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
                    Text("Professional AI Insights Available")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Get expert dog behaviorist analysis powered by ChatGPT. Add your OpenAI API key to unlock professional insights and recommendations.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Add API Key") {
                        onSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else if let analysis = analysis {
                ChatGPTResultView(analysis: analysis)
            } else if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Getting professional analysis...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if let error = error {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Analysis Failed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Try Again") {
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
                            Text("Previous analysis available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Get professional dog behaviorist insights based on your data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button(hasCachedAnalysis ? "Refresh Analysis" : "Analyze with ChatGPT") {
                            onAnalyze()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        if hasCachedAnalysis {
                            Text("• Uses cached result to save tokens")
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
    let analysis: ChatGPTAnalysis
    @State private var showingExampleWeek = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Summary
            VStack(alignment: .leading, spacing: 4) {
                Text("Professional Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(analysis.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Breed Analysis
            VStack(alignment: .leading, spacing: 8) {
                Text("Breed-Specific Analysis")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Breed Traits:")
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
                        Text("Common Breed Issues:")
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
            
            // Age Considerations
            VStack(alignment: .leading, spacing: 4) {
                Text("Age & Development")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Stage: \(analysis.ageConsiderations.developmentalStage.capitalized)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                
                Text(analysis.ageConsiderations.ageAppropriateExpectations)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Behavior Assessment
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Behavior Assessment")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(analysis.behaviorAssessment.overallScore)/100")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(analysis.behaviorAssessment.overallScore))
                }
                
                HStack {
                    Text("Trend: \(analysis.behaviorAssessment.progressTrend.capitalized)")
                        .font(.caption)
                        .foregroundColor(trendColor(analysis.behaviorAssessment.progressTrend))
                    Spacer()
                }
                
                if !analysis.behaviorAssessment.strengths.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strengths:")
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
                        Text("Areas for Improvement:")
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
            
            // Training Recommendations
            if !analysis.trainingRecommendations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Training Recommendations")
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
                            
                            Text("Issue: \(recommendation.issue)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("Duration: \(recommendation.duration) | Frequency: \(recommendation.frequency)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                            
                            if !recommendation.steps.isEmpty {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Steps:")
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
            }
            
            // Example Week Button
            Button(action: {
                showingExampleWeek = true
            }) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                    Text("View Example Training Week")
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
            
            // Key Insights
            if !analysis.keyInsights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Professional Insights")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    ForEach(analysis.keyInsights, id: \.self) { insight in
                        Text("• \(insight)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Generated timestamp
            HStack {
                Spacer()
                Text("Generated: \(analysis.generatedAt, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingExampleWeek) {
            ExampleWeekView(analysis: analysis)
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

struct AIInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDog = Dog(name: "Buddy")
        AIInsightsView(dog: sampleDog, currentMonth: Date())
    }
}
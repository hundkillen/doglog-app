import SwiftUI

struct MorningForecastView: View {
    @Environment(\.dismiss) private var dismiss
    let dog: Dog
    @State private var forecast: MorningForecast?
    @State private var isLoading = true
    @State private var selectedDate = Date()
    
    private let predictiveAnalyzer = PredictiveAnalyzer()
    
    // Cache key for today's forecast
    private var cacheKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "forecast_\(dog.id)_\(formatter.string(from: selectedDate))"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        // Dr. Elias thinking state
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
                        
                    } else if let forecast = forecast {
                        // Dr. Elias result header
                        DrEliasResultHeaderView(profileStyle: true)
                            .padding(.bottom, 10)
                        
                        // Main prediction card
                        PredictionCardView(forecast: forecast)
                        
                        // Risk level indicator
                        RiskLevelView(riskLevel: forecast.riskLevel)
                        
                        // Key factors section
                        if !forecast.keyFactors.isEmpty {
                            KeyFactorsView(factors: forecast.keyFactors)
                        }
                        
                        // Recommendations section
                        if !forecast.recommendations.isEmpty {
                            ForecastRecommendationsView(recommendations: forecast.recommendations)
                        }
                        
                        // Daily Plan section
                        DailyPlanView(forecast: forecast)
                        
                        // Confidence indicator
                        ConfidenceView(confidence: forecast.confidenceLevel)
                        
                    } else {
                        // Insufficient data state or fallback
                        VStack(spacing: 20) {
                            Text("🐕")
                                .font(.system(size: 60))
                            
                            VStack(spacing: 12) {
                                Text("forecast.building_profile".localized)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(String(format: "forecast.need_more_data".localized, dog.name))
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                
                                Text("forecast.keep_logging".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                    }
                }
                .padding()
            }
            .navigationTitle("forecast.morning_forecast".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    DatePicker("common.date".localized, selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: selectedDate) { _ in
                            generateForecast()
                        }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            })
        }
        .onAppear {
            print("🌅 MorningForecastView appeared for dog: \(dog.name)")
            generateForecast()
        }
    }
    
    private func generateForecast() {
        print("🔍 Starting forecast generation for \(dog.name) on \(selectedDate)")
        
        // If we already have a forecast for the same date, check if data is still fresh
        if let existingForecast = forecast {
            let calendar = Calendar.current
            if calendar.isDate(existingForecast.date, inSameDayAs: selectedDate) {
                // Check if dog's data has been updated since forecast was generated
                if hasDataUpdatedSince(existingForecast.date) {
                    print("🔄 Dog data updated since last forecast - regenerating to include new data")
                } else {
                    print("💾 Reusing existing forecast - no new data or tokens used!")
                    isLoading = false
                    return
                }
            }
        }
        
        print("🆕 Generating new forecast (will use tokens)")
        isLoading = true
        
        // Simulate analysis time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            print("🧠 Generating forecast...")
            forecast = predictiveAnalyzer.generateMorningForecast(for: dog, date: selectedDate)
            print("📊 Forecast generated: \(forecast != nil ? "Success" : "No data")")
            print("💾 Forecast cached in memory for this session")
            isLoading = false
        }
    }
    
    private func hasDataUpdatedSince(_ forecastDate: Date) -> Bool {
        // Check if any activities were added after the forecast was generated
        let newActivities = dog.activities.filter { $0.date > forecastDate }
        if !newActivities.isEmpty {
            print("📊 Found \(newActivities.count) new activities since forecast")
            return true
        }
        
        // Check if any ratings were added after the forecast was generated
        let newRatings = dog.dailyRatings.filter { $0.date > forecastDate }
        if !newRatings.isEmpty {
            print("📊 Found \(newRatings.count) new ratings since forecast")
            return true
        }
        
        print("📊 No new data since forecast - cache is still fresh")
        return false
    }
}

// MARK: - Prediction Card View

struct PredictionCardView: View {
    let forecast: MorningForecast
    
    var body: some View {
        VStack(spacing: 16) {
            // Prediction header
            HStack {
                Text(forecast.overallPrediction.emoji)
                    .font(.system(size: 50))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(forecast.overallPrediction.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(String(format: "forecast.for_name".localized, forecast.dog.name))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(forecast.confidenceLevel * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(confidenceColor(forecast.confidenceLevel))
                    
                    Text("forecast.confidence".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Personalized message
            Text(forecast.personalizedMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    predictionColor(forecast.overallPrediction).opacity(0.1),
                    predictionColor(forecast.overallPrediction).opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(predictionColor(forecast.overallPrediction).opacity(0.3), lineWidth: 1)
        )
    }
    
    private func predictionColor(_ prediction: DayPrediction) -> Color {
        switch prediction {
        case .excellent: return .yellow
        case .good: return .green
        case .okay: return .blue
        case .challenging: return .orange
        case .difficult: return .red
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.5 { return .orange }
        return .red
    }
}

// MARK: - Risk Level View

struct RiskLevelView: View {
    let riskLevel: RiskLevel
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(riskLevelColor(riskLevel))
            
            Text(String(format: "forecast.risk_level".localized, riskLevel.displayName))
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Circle()
                .fill(riskLevelColor(riskLevel))
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func riskLevelColor(_ riskLevel: RiskLevel) -> Color {
        switch riskLevel {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Key Factors View

struct KeyFactorsView: View {
    let factors: [ForecastFactor]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("forecast.key_factors".localized)
                    .font(.headline)
                Spacer()
            }
            
            LazyVStack(spacing: 10) {
                ForEach(Array(factors.enumerated()), id: \.offset) { index, factor in
                    FactorRowView(factor: factor)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct FactorRowView: View {
    let factor: ForecastFactor
    @State private var showingExplanation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Impact indicator
            VStack {
                Text(factor.impact.emoji)
                    .font(.title3)
                
                Circle()
                    .fill(impactColor(factor.impact))
                    .frame(width: 8, height: 8)
            }
            .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(factor.factor)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Button(action: { showingExplanation = true }) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Text("\(Int(factor.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(factor.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .alert(factor.factor, isPresented: $showingExplanation) {
            Button("common.ok".localized) { }
        } message: {
            Text(getDetailedExplanation(for: factor))
        }
    }
    
    private func impactColor(_ impact: FactorImpact) -> Color {
        switch impact {
        case .veryPositive, .positive: return .green
        case .neutral: return .blue
        case .negative, .veryNegative: return .red
        }
    }
    
    private func getDetailedExplanation(for factor: ForecastFactor) -> String {
        let factorName = factor.factor.lowercased()
        
        if factorName.contains("historical") || factorName.contains("mönster") || factorName.contains("pattern") {
            return String(format: "forecast.info.historical".localized, Int(factor.confidence * 100), factor.description)
        } else if factorName.contains("recent") || factorName.contains("trend") {
            return String(format: "forecast.info.recent".localized, Int(factor.confidence * 100), factor.description)
        } else if factorName.contains("sunday") || factorName.contains("monday") || factorName.contains("tuesday") || factorName.contains("wednesday") || factorName.contains("thursday") || factorName.contains("friday") || factorName.contains("saturday") || factorName.contains("måndag") || factorName.contains("tisdag") || factorName.contains("onsdag") || factorName.contains("torsdag") || factorName.contains("fredag") || factorName.contains("lördag") || factorName.contains("söndag") {
            return String(format: "forecast.info.weekday".localized, Int(factor.confidence * 100), factor.description)
        } else {
            return String(format: "forecast.info.generic".localized, factor.factor, Int(factor.confidence * 100), factor.description)
        }
    }
}

// MARK: - Recommendations View

struct ForecastRecommendationsView: View {
    let recommendations: [ForecastRecommendation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("forecast.dr_elias_recommendations".localized)
                    .font(.headline)
                Spacer()
            }
            
            LazyVStack(spacing: 10) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                    ForecastRecommendationRowView(recommendation: recommendation)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ForecastRecommendationRowView: View {
    let recommendation: ForecastRecommendation
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor(recommendation.priority))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if let timeOfDay = recommendation.timeOfDay {
                        Text(timeOfDay)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                            .foregroundColor(.blue)
                    }
                }
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            priorityColor(recommendation.priority).opacity(0.1)
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(priorityColor(recommendation.priority).opacity(0.3), lineWidth: 1)
        )
    }
    
    private func priorityColor(_ priority: RecommendationPriority) -> Color {
        switch priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .green
        }
    }
}

// MARK: - Confidence View

struct ConfidenceView: View {
    let confidence: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("forecast.analysis_confidence".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(confidence * 100))%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(confidenceColor(confidence))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(confidenceColor(confidence))
                        .frame(width: geometry.size.width * confidence, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            Text(confidenceDescription(confidence))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.5 { return .orange }
        return .red
    }
    
    private func confidenceDescription(_ confidence: Double) -> String {
        if confidence >= 0.8 { return "ai.high_confidence".localized }
        if confidence >= 0.5 { return "ai.moderate_confidence".localized }
        return "ai.low_confidence".localized
    }
}

// MARK: - Daily Plan View

struct DailyPlanView: View {
    let forecast: MorningForecast
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.green)
                Text("forecast.todays_plan".localized)
                    .font(.headline)
                Spacer()
            }
            
            LazyVStack(spacing: 10) {
                ForEach(Array(generateDailyPlan().enumerated()), id: \.offset) { index, plan in
                    DailyPlanItemView(plan: plan)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func generateDailyPlan() -> [DailyPlanItem] {
        var plans: [DailyPlanItem] = []
        
        // First, check if we have Suggested Training Week recommendations for today
        let todaysSuggestedTrainingWeekPlan = getTodaysSuggestedTrainingWeekPlan()
        if !todaysSuggestedTrainingWeekPlan.isEmpty {
            plans.append(contentsOf: todaysSuggestedTrainingWeekPlan)
        }
        
        // If no Suggested Training Week plan, use forecast-based plans
        if plans.isEmpty {
            plans.append(contentsOf: getForecastBasedPlans())
        }
        
        // Add specific plans based on key factors
        plans.append(contentsOf: getFactorBasedPlans())
        
        // Add confidence-based suggestions
        plans.append(contentsOf: getConfidenceBasedPlans())
        
        return plans
    }
    
    private func getTodaysSuggestedTrainingWeekPlan() -> [DailyPlanItem] {
        // Check if there's a cached Suggested Training Week for this dog
        let suggestedTrainingWeekKey = "suggested_training_week_\(forecast.dog.id)"
        guard let data = UserDefaults.standard.data(forKey: suggestedTrainingWeekKey),
              let suggestedTrainingWeek = try? JSONDecoder().decode(SuggestedTrainingWeek.self, from: data) else {
            return []
        }
        
        // Get today's day name
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Monday, Tuesday, etc.
        let todayName = formatter.string(from: forecast.date)
        
        // Find today's training plan
        guard let todaysTraining = suggestedTrainingWeek.days.first(where: { $0.dayName.lowercased() == todayName.lowercased() }) else {
            return []
        }
        
        var plans: [DailyPlanItem] = []
        
        // Add daily goal as first item
        plans.append(DailyPlanItem(
            time: "forecast.daily_goal".localized,
            activity: todaysTraining.theme,
            description: todaysTraining.dailyGoal,
            icon: "target",
            priority: .high
        ))
        
        // Convert training activities to daily plan items
        for activity in todaysTraining.activities.prefix(3) { // Limit to 3 activities
            plans.append(DailyPlanItem(
                time: activity.time,
                activity: activity.activity,
                description: "\(activity.focus): \(activity.trainingGoal)",
                icon: getIconForActivity(activity.focus),
                priority: .medium
            ))
        }
        
        print("📋 Using Suggested Training Week plan for \(todayName): \(todaysTraining.theme)")
        return plans
    }
    
    private func getIconForActivity(_ focus: String) -> String {
        let focusLower = focus.lowercased()
        if focusLower.contains("physical") || focusLower.contains("exercise") {
            return "figure.run"
        } else if focusLower.contains("mental") || focusLower.contains("training") {
            return "brain.head.profile"
        } else if focusLower.contains("social") {
            return "heart.fill"
        } else if focusLower.contains("rest") || focusLower.contains("calm") {
            return "leaf.fill"
        } else {
            return "star.fill"
        }
    }
    
    private func getForecastBasedPlans() -> [DailyPlanItem] {
        var plans: [DailyPlanItem] = []
        
        // Base plans on forecast prediction
        switch forecast.overallPrediction {
        case .excellent:
            plans.append(DailyPlanItem(
                time: "forecast.time.morning".localized,
                activity: "forecast.plan.energy_challenge.title".localized,
                description: "forecast.plan.energy_challenge.desc".localized,
                icon: "figure.run",
                priority: .high
            ))
            plans.append(DailyPlanItem(
                time: "forecast.time.afternoon".localized, 
                activity: "forecast.plan.social_time.title".localized,
                description: "forecast.plan.social_time.desc".localized,
                icon: "heart.fill",
                priority: .medium
            ))
            
        case .good:
            plans.append(DailyPlanItem(
                time: "forecast.time.morning".localized,
                activity: "forecast.plan.regular_exercise.title".localized,
                description: "forecast.plan.regular_exercise.desc".localized,
                icon: "figure.walk",
                priority: .high
            ))
            plans.append(DailyPlanItem(
                time: "forecast.time.afternoon".localized,
                activity: "forecast.plan.bonding_time.title".localized, 
                description: "forecast.plan.bonding_time.desc".localized,
                icon: "hands.and.sparkles.fill",
                priority: .medium
            ))
            
        case .okay:
            plans.append(DailyPlanItem(
                time: "forecast.time.morning".localized,
                activity: "forecast.plan.gentle_start.title".localized,
                description: "forecast.plan.gentle_start.desc".localized,
                icon: "leaf.fill",
                priority: .high
            ))
            plans.append(DailyPlanItem(
                time: "forecast.time.midday".localized,
                activity: "forecast.plan.comfort_zone.title".localized,
                description: "forecast.plan.comfort_zone.desc".localized,
                icon: "house.fill",
                priority: .medium
            ))
            
        case .challenging:
            plans.append(DailyPlanItem(
                time: "forecast.time.morning".localized,
                activity: "forecast.plan.extra_support.title".localized,
                description: "forecast.plan.extra_support.desc".localized,
                icon: "heart.circle.fill",
                priority: .high
            ))
            plans.append(DailyPlanItem(
                time: "forecast.time.all_day".localized,
                activity: "forecast.plan.patience_love.title".localized,
                description: "forecast.plan.patience_love.desc".localized,
                icon: "heart.text.square.fill",
                priority: .high
            ))
            
        case .difficult:
            plans.append(DailyPlanItem(
                time: "forecast.time.all_day".localized,
                activity: "forecast.plan.gentle_care.title".localized,
                description: "forecast.plan.gentle_care.desc".localized,
                icon: "cross.case.fill",
                priority: .high
            ))
            plans.append(DailyPlanItem(
                time: "forecast.time.afternoon".localized,
                activity: "forecast.plan.quiet_time.title".localized,
                description: "forecast.plan.quiet_time.desc".localized,
                icon: "moon.fill",
                priority: .medium
            ))
        }
        
        return plans
    }
    
    private func getFactorBasedPlans() -> [DailyPlanItem] {
        var plans: [DailyPlanItem] = []
        
        // Add specific plans based on key factors
        if let sundayFactor = forecast.keyFactors.first(where: { $0.factor.lowercased().contains("sunday") }) {
            if sundayFactor.impact == .negative || sundayFactor.impact == .veryNegative {
                plans.append(DailyPlanItem(
                    time: "forecast.tag.data_insight".localized,
                    activity: "forecast.plan.combat_sunday_blues.title".localized,
                    description: "forecast.plan.combat_sunday_blues.desc".localized,
                    icon: "gamecontroller.fill",
                    priority: .medium
                ))
            }
        }
        
        return plans
    }
    
    private func getConfidenceBasedPlans() -> [DailyPlanItem] {
        var plans: [DailyPlanItem] = []
        
        // Add confidence-based suggestions
        if forecast.confidenceLevel > 0.8 {
            plans.append(DailyPlanItem(
                time: "forecast.tag.data_insight".localized,
                activity: "forecast.plan.trust_pattern.title".localized,
                description: "forecast.plan.trust_pattern.desc".localized,
                icon: "checkmark.seal.fill",
                priority: .low
            ))
        } else if forecast.confidenceLevel < 0.5 {
            plans.append(DailyPlanItem(
                time: "forecast.tag.data_insight".localized,
                activity: "forecast.plan.stay_flexible.title".localized,
                description: "forecast.plan.stay_flexible.desc".localized,
                icon: "arrow.triangle.2.circlepath",
                priority: .low
            ))
        }
        
        return plans
    }
}

struct DailyPlanItem {
    let time: String
    let activity: String
    let description: String
    let icon: String
    let priority: PlanPriority
}

enum PlanPriority {
    case high, medium, low
    
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

struct DailyPlanItemView: View {
    let plan: DailyPlanItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Time and priority indicator
            VStack {
                Image(systemName: plan.icon)
                    .font(.title3)
                    .foregroundColor(plan.priority.color)
                
                Circle()
                    .fill(plan.priority.color)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plan.activity)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(plan.time)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(plan.priority.color.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(plan.priority.color)
                }
                
                Text(plan.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(plan.priority.color.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(plan.priority.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Insufficient Data View

struct InsufficientDataView: View {
    let dogName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                Text("forecast.building_profile".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(String(format: "forecast.need_more_data".localized, dogName))
                    .font(.body)
                    .multilineTextAlignment(.center)
                
                Text("forecast.keep_logging".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("forecast.start_logging".localized) {
                // Navigate to daily activity view
                NotificationCenter.default.post(name: .showDailyLog, object: nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// MARK: - Preview

struct MorningForecastView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDog = Dog(name: "Buddy")
        MorningForecastView(dog: sampleDog)
    }
}
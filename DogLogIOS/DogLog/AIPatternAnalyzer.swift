import Foundation
import SwiftData

// MARK: - AI Pattern Analysis Engine
class AIPatternAnalyzer {
    
    // MARK: - Data Structures
    struct DogInsights {
        let overallMood: MoodTrend
        let activityPatterns: [ActivityPattern]
        let recommendations: [Recommendation]
        let weeklyTrends: WeeklyTrend
        let behaviorInsights: [BehaviorInsight]
        let confidence: Double // 0.0 to 1.0
    }
    
    struct ActivityPattern {
        let activityType: String
        let averageOutcome: String
        let frequency: Int // per week
        let successRate: Double // 0.0 to 1.0
        let bestTimeOfDay: String?
        let trend: PatternTrend
    }
    
    struct MoodTrend {
        let current: String // "good", "okay", "bad"
        let direction: TrendDirection
        let consistency: Double // 0.0 to 1.0
        let improvement: Double // percentage change
    }
    
    struct WeeklyTrend {
        let bestDays: [String] // day names
        let worstDays: [String]
        let averageActivitiesPerDay: Double
        let moodStability: Double
    }
    
    struct BehaviorInsight {
        let title: String
        let description: String
        let confidence: Double
        let category: InsightCategory
    }
    
    struct Recommendation {
        let title: String
        let description: String
        let priority: RecommendationPriority
        let category: RecommendationCategory
        let actionable: Bool
    }
    
    enum PatternTrend {
        case improving, declining, stable, insufficient_data
    }
    
    enum TrendDirection {
        case up, down, stable
    }
    
    enum InsightCategory {
        case behavior, health, activity, mood, routine
    }
    
    enum RecommendationPriority {
        case high, medium, low
    }
    
    enum RecommendationCategory {
        case exercise, training, health, routine, socialization
    }
    
    enum AnalysisTimeRange: Hashable, Equatable {
        case thisMonth(Date) // Pass the current month date
        case allTime
        
        var displayName: String {
            switch self {
            case .thisMonth:
                return "This Month"
            case .allTime:
                return "All Time"
            }
        }
        
        // Implement Hashable
        func hash(into hasher: inout Hasher) {
            switch self {
            case .thisMonth(let date):
                hasher.combine("thisMonth")
                hasher.combine(date.timeIntervalSince1970)
            case .allTime:
                hasher.combine("allTime")
            }
        }
        
        // Implement Equatable
        static func == (lhs: AnalysisTimeRange, rhs: AnalysisTimeRange) -> Bool {
            switch (lhs, rhs) {
            case (.allTime, .allTime):
                return true
            case (.thisMonth(let date1), .thisMonth(let date2)):
                let calendar = Calendar.current
                return calendar.isDate(date1, equalTo: date2, toGranularity: .month)
            default:
                return false
            }
        }
    }
    
    // MARK: - Analysis Methods
    
    func analyzeDog(_ dog: Dog, timeRange: AnalysisTimeRange = .allTime) -> DogInsights {
        let activities = filterActivities(dog.activities, for: timeRange)
        let dailyRatings = filterDailyRatings(dog.dailyRatings, for: timeRange)
        
        // Ensure we have enough data for meaningful analysis
        guard activities.count >= 5 || dailyRatings.count >= 3 else {
            return generateInsufficientDataInsights()
        }
        
        let overallMood = analyzeMoodTrend(dailyRatings)
        let activityPatterns = analyzeActivityPatterns(activities)
        let weeklyTrends = analyzeWeeklyTrends(activities, dailyRatings)
        let behaviorInsights = generateBehaviorInsights(activities, dailyRatings, activityPatterns)
        let recommendations = generateRecommendations(overallMood, activityPatterns, behaviorInsights)
        
        let confidence = calculateConfidence(activities.count, dailyRatings.count)
        
        return DogInsights(
            overallMood: overallMood,
            activityPatterns: activityPatterns,
            recommendations: recommendations,
            weeklyTrends: weeklyTrends,
            behaviorInsights: behaviorInsights,
            confidence: confidence
        )
    }
    
    // MARK: - Mood Analysis
    private func analyzeMoodTrend(_ dailyRatings: [DailyRating]) -> MoodTrend {
        guard !dailyRatings.isEmpty else {
            return MoodTrend(current: "okay", direction: .stable, consistency: 0.0, improvement: 0.0)
        }
        
        let sortedRatings = dailyRatings.sorted { $0.date < $1.date }
        let recentRatings = Array(sortedRatings.suffix(7)) // Last 7 days
        
        // Calculate current mood (most recent or average of recent)
        let currentMood = recentRatings.last?.rating ?? "okay"
        
        // Calculate trend direction
        let direction = calculateMoodDirection(sortedRatings)
        
        // Calculate consistency (how stable the mood has been)
        let consistency = calculateMoodConsistency(recentRatings)
        
        // Calculate improvement percentage
        let improvement = calculateMoodImprovement(sortedRatings)
        
        return MoodTrend(
            current: currentMood,
            direction: direction,
            consistency: consistency,
            improvement: improvement
        )
    }
    
    private func calculateMoodDirection(_ ratings: [DailyRating]) -> TrendDirection {
        guard ratings.count >= 3 else { return .stable }
        
        let recent = Array(ratings.suffix(3))
        let older = Array(ratings.prefix(ratings.count - 3).suffix(3))
        
        let recentScore = recent.map { moodScore($0.rating) }.reduce(0, +) / Double(recent.count)
        let olderScore = older.map { moodScore($0.rating) }.reduce(0, +) / Double(older.count)
        
        let difference = recentScore - olderScore
        
        if difference > 0.3 { return .up }
        if difference < -0.3 { return .down }
        return .stable
    }
    
    private func calculateMoodConsistency(_ ratings: [DailyRating]) -> Double {
        guard ratings.count > 1 else { return 1.0 }
        
        let scores = ratings.map { moodScore($0.rating) }
        let average = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.map { pow($0 - average, 2) }.reduce(0, +) / Double(scores.count)
        
        // Convert variance to consistency (lower variance = higher consistency)
        return max(0, 1.0 - variance)
    }
    
    private func calculateMoodImprovement(_ ratings: [DailyRating]) -> Double {
        guard ratings.count >= 4 else { return 0.0 }
        
        let firstHalf = Array(ratings.prefix(ratings.count / 2))
        let secondHalf = Array(ratings.suffix(ratings.count / 2))
        
        let firstScore = firstHalf.map { moodScore($0.rating) }.reduce(0, +) / Double(firstHalf.count)
        let secondScore = secondHalf.map { moodScore($0.rating) }.reduce(0, +) / Double(secondHalf.count)
        
        return ((secondScore - firstScore) / firstScore) * 100
    }
    
    private func moodScore(_ mood: String) -> Double {
        switch mood {
        case "good": return 1.0
        case "okay": return 0.5
        case "bad": return 0.0
        default: return 0.5
        }
    }
    
    // MARK: - Activity Pattern Analysis
    private func analyzeActivityPatterns(_ activities: [Activity]) -> [ActivityPattern] {
        let groupedActivities = Dictionary(grouping: activities) { $0.activityType }
        
        return groupedActivities.compactMap { (activityType, activityList) in
            analyzeActivityType(activityType, activities: activityList)
        }.sorted { $0.frequency > $1.frequency }
    }
    
    private func analyzeActivityType(_ type: String, activities: [Activity]) -> ActivityPattern {
        let sortedActivities = activities.sorted { $0.date < $1.date }
        
        // Calculate average outcome
        let outcomes = activities.map { $0.outcome }
        let averageOutcome = calculateAverageOutcome(outcomes)
        
        // Calculate frequency (activities per week)
        let frequency = calculateWeeklyFrequency(activities)
        
        // Calculate success rate (good outcomes / total)
        let successRate = calculateSuccessRate(outcomes)
        
        // Find best time of day (if we had time data)
        let bestTimeOfDay: String? = nil // Would need time data
        
        // Calculate trend
        let trend = calculateActivityTrend(sortedActivities)
        
        return ActivityPattern(
            activityType: type,
            averageOutcome: averageOutcome,
            frequency: frequency,
            successRate: successRate,
            bestTimeOfDay: bestTimeOfDay,
            trend: trend
        )
    }
    
    private func calculateAverageOutcome(_ outcomes: [String]) -> String {
        let scores = outcomes.map { moodScore($0) }
        let average = scores.reduce(0, +) / Double(scores.count)
        
        if average >= 0.75 { return "good" }
        if average >= 0.25 { return "okay" }
        return "bad"
    }
    
    private func calculateWeeklyFrequency(_ activities: [Activity]) -> Int {
        guard let earliest = activities.map({ $0.date }).min(),
              let latest = activities.map({ $0.date }).max() else { return 0 }
        
        let timeSpan = latest.timeIntervalSince(earliest)
        let weeks = max(1, timeSpan / (7 * 24 * 60 * 60))
        
        return Int(Double(activities.count) / weeks)
    }
    
    private func calculateSuccessRate(_ outcomes: [String]) -> Double {
        let goodCount = outcomes.filter { $0 == "good" }.count
        return Double(goodCount) / Double(outcomes.count)
    }
    
    private func calculateActivityTrend(_ activities: [Activity]) -> PatternTrend {
        guard activities.count >= 4 else { return .insufficient_data }
        
        let midPoint = activities.count / 2
        let firstHalf = Array(activities.prefix(midPoint))
        let secondHalf = Array(activities.suffix(midPoint))
        
        let firstScore = firstHalf.map { moodScore($0.outcome) }.reduce(0, +) / Double(firstHalf.count)
        let secondScore = secondHalf.map { moodScore($0.outcome) }.reduce(0, +) / Double(secondHalf.count)
        
        let improvement = (secondScore - firstScore) / firstScore
        
        if improvement > 0.2 { return .improving }
        if improvement < -0.2 { return .declining }
        return .stable
    }
    
    // MARK: - Weekly Trends Analysis
    private func analyzeWeeklyTrends(_ activities: [Activity], _ dailyRatings: [DailyRating]) -> WeeklyTrend {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        
        // Group ratings by day of week
        let ratingsByDay = Dictionary(grouping: dailyRatings) { rating in
            dayFormatter.string(from: rating.date)
        }
        
        // Calculate average mood score for each day
        let dayScores = ratingsByDay.mapValues { ratings in
            ratings.map { moodScore($0.rating) }.reduce(0, +) / Double(ratings.count)
        }
        
        let sortedDays = dayScores.sorted { $0.value > $1.value }
        let bestDays = Array(sortedDays.prefix(2)).map { $0.key }
        let worstDays = Array(sortedDays.suffix(2)).map { $0.key }
        
        // Calculate average activities per day
        let activitiesByDate = Dictionary(grouping: activities) { activity in
            DateFormatter.dayFormatter.string(from: activity.date)
        }
        
        let totalActivities = Double(activities.count)
        let uniqueDaysWithActivities = Double(activitiesByDate.keys.count)
        let avgActivitiesPerDay = uniqueDaysWithActivities > 0 ? totalActivities / uniqueDaysWithActivities : 0.0
        
        // Calculate mood stability
        let moodStability = calculateMoodConsistency(dailyRatings)
        
        return WeeklyTrend(
            bestDays: bestDays,
            worstDays: worstDays,
            averageActivitiesPerDay: avgActivitiesPerDay,
            moodStability: moodStability
        )
    }
    
    // MARK: - Behavior Insights Generation
    private func generateBehaviorInsights(_ activities: [Activity], _ dailyRatings: [DailyRating], _ patterns: [ActivityPattern]) -> [BehaviorInsight] {
        var insights: [BehaviorInsight] = []
        
        // Activity frequency insights
        if let mostFrequent = patterns.first {
            insights.append(BehaviorInsight(
                title: "Favorite Activity",
                description: "\(mostFrequent.activityType) is your dog's most frequent activity with a \(Int(mostFrequent.successRate * 100))% success rate.",
                confidence: 0.8,
                category: .activity
            ))
        }
        
        // Mood pattern insights
        let recentMood = dailyRatings.suffix(7)
        let goodDays = recentMood.filter { $0.rating == "good" }.count
        if goodDays >= 5 {
            insights.append(BehaviorInsight(
                title: "Great Week!",
                description: "Your dog had \(goodDays) good days this week. Keep up the great routine!",
                confidence: 0.9,
                category: .mood
            ))
        }
        
        // Activity success insights
        let successfulActivities = patterns.filter { $0.successRate > 0.8 }
        if !successfulActivities.isEmpty {
            let topActivity = successfulActivities.first!
            insights.append(BehaviorInsight(
                title: "High Success Activity",
                description: "\(topActivity.activityType) consistently goes well - consider doing it more often!",
                confidence: 0.85,
                category: .behavior
            ))
        }
        
        return insights
    }
    
    // MARK: - Recommendations Generation
    private func generateRecommendations(_ mood: MoodTrend, _ patterns: [ActivityPattern], _ insights: [BehaviorInsight]) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Mood-based recommendations
        if mood.direction == .down {
            recommendations.append(Recommendation(
                title: "Boost Mood Activities",
                description: "Try increasing activities that usually go well to improve overall mood.",
                priority: .high,
                category: .routine,
                actionable: true
            ))
        }
        
        // Activity pattern recommendations
        if let lowSuccessActivity = patterns.first(where: { $0.successRate < 0.5 }) {
            recommendations.append(Recommendation(
                title: "Improve \(lowSuccessActivity.activityType)",
                description: "Consider breaking down \(lowSuccessActivity.activityType) into smaller steps or trying different approaches.",
                priority: .medium,
                category: .training,
                actionable: true
            ))
        }
        
        // Exercise recommendations
        let exerciseActivities = patterns.filter { 
            $0.activityType.lowercased().contains("walk") || 
            $0.activityType.lowercased().contains("exercise") ||
            $0.activityType.lowercased().contains("play")
        }
        
        if exerciseActivities.isEmpty || exerciseActivities.allSatisfy({ $0.frequency < 3 }) {
            recommendations.append(Recommendation(
                title: "Increase Exercise",
                description: "Regular exercise can improve mood and behavior. Aim for daily walks or play sessions.",
                priority: .high,
                category: .exercise,
                actionable: true
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Utility Methods
    private func calculateConfidence(_ activityCount: Int, _ ratingCount: Int) -> Double {
        let dataPoints = activityCount + ratingCount
        
        if dataPoints < 5 { return 0.3 }
        if dataPoints < 10 { return 0.5 }
        if dataPoints < 20 { return 0.7 }
        if dataPoints < 50 { return 0.85 }
        return 0.95
    }
    
    private func generateInsufficientDataInsights() -> DogInsights {
        return DogInsights(
            overallMood: MoodTrend(current: "okay", direction: .stable, consistency: 0.5, improvement: 0.0),
            activityPatterns: [],
            recommendations: [
                Recommendation(
                    title: "Start Logging Activities",
                    description: "Log more daily activities to get personalized insights about your dog's patterns and behavior.",
                    priority: .high,
                    category: .routine,
                    actionable: true
                )
            ],
            weeklyTrends: WeeklyTrend(bestDays: [], worstDays: [], averageActivitiesPerDay: 0, moodStability: 0),
            behaviorInsights: [
                BehaviorInsight(
                    title: "Building Your Profile",
                    description: "Keep logging activities and daily ratings to unlock AI insights about your dog's behavior patterns.",
                    confidence: 1.0,
                    category: .routine
                )
            ],
            confidence: 0.1
        )
    }
    
    // MARK: - Date Filtering Methods
    
    private func filterActivities(_ activities: [Activity], for timeRange: AnalysisTimeRange) -> [Activity] {
        switch timeRange {
        case .allTime:
            return activities
        case .thisMonth(let currentMonth):
            let calendar = Calendar.current
            return activities.filter { activity in
                calendar.isDate(activity.date, equalTo: currentMonth, toGranularity: .month)
            }
        }
    }
    
    private func filterDailyRatings(_ ratings: [DailyRating], for timeRange: AnalysisTimeRange) -> [DailyRating] {
        switch timeRange {
        case .allTime:
            return ratings
        case .thisMonth(let currentMonth):
            let calendar = Calendar.current
            return ratings.filter { rating in
                calendar.isDate(rating.date, equalTo: currentMonth, toGranularity: .month)
            }
        }
    }
}
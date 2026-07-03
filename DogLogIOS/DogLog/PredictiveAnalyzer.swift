import Foundation
import SwiftData

// MARK: - Data Structures

struct MorningForecast {
    let dog: Dog
    let date: Date
    let overallPrediction: DayPrediction
    let confidenceLevel: Double // 0.0 to 1.0
    let keyFactors: [ForecastFactor]
    let recommendations: [ForecastRecommendation]
    let riskLevel: RiskLevel
    let weatherImpact: WeatherImpact?
    let personalizedMessage: String
}

struct ForecastFactor {
    let factor: String
    let impact: FactorImpact
    let description: String
    let confidence: Double
}

struct ForecastRecommendation {
    let title: String
    let description: String
    let priority: RecommendationPriority
    let timeOfDay: String?
}

struct WeatherImpact {
    let currentConditions: String
    let temperature: Double
    let expectedImpact: FactorImpact
    let recommendation: String
}

enum DayPrediction: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case okay = "okay"
    case challenging = "challenging"
    case difficult = "difficult"
    
    var emoji: String {
        switch self {
        case .excellent: return "🌟"
        case .good: return "😊"
        case .okay: return "😐"
        case .challenging: return "😬"
        case .difficult: return "😞"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "gold"
        case .good: return "green"
        case .okay: return "blue"
        case .challenging: return "orange"
        case .difficult: return "red"
        }
    }
    
    var displayName: String {
        switch self {
        case .excellent: return "risk.excellent_day".localized
        case .good: return "risk.good_day".localized
        case .okay: return "risk.okay_day".localized
        case .challenging: return "risk.challenging_day".localized
        case .difficult: return "risk.difficult_day".localized
        }
    }
}

enum FactorImpact: String {
    case veryPositive = "very_positive"
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
    case veryNegative = "very_negative"
    
    var score: Double {
        switch self {
        case .veryPositive: return 1.0
        case .positive: return 0.5
        case .neutral: return 0.0
        case .negative: return -0.5
        case .veryNegative: return -1.0
        }
    }
    
    var emoji: String {
        switch self {
        case .veryPositive: return "⬆️⬆️"
        case .positive: return "⬆️"
        case .neutral: return "➡️"
        case .negative: return "⬇️"
        case .veryNegative: return "⬇️⬇️"
        }
    }
}

enum RiskLevel: String {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case critical = "critical"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "risk.low".localized
        case .moderate: return "risk.moderate".localized
        case .high: return "risk.high".localized
        case .critical: return "risk.critical".localized
        }
    }
}

enum RecommendationPriority: String {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
}

// MARK: - Predictive Analysis Engine

class PredictiveAnalyzer {
    
    // MARK: - Analysis Methods
    
    func generateMorningForecast(for dog: Dog, date: Date = Date()) -> MorningForecast? {
        guard hasMinimumData(for: dog) else { return nil }
        
        let historicalData = analyzeHistoricalPatterns(for: dog, targetDate: date)
        let recentTrends = analyzeRecentTrends(for: dog, days: 7)
        let yesterdayImpact = analyzeYesterdayImpact(for: dog, date: date)
        let weekdayPattern = analyzeWeekdayPattern(for: dog, weekday: Calendar.current.component(.weekday, from: date))
        
        // Calculate base prediction score
        var predictionScore = 0.0
        var factors: [ForecastFactor] = []
        
        // Historical pattern influence (30%)
        let historicalInfluence = historicalData.averageScore * 0.3
        predictionScore += historicalInfluence
        
        if historicalData.confidence > 0.5 {
            factors.append(ForecastFactor(
                factor: "forecast.factor.historical".localized,
                impact: scoreToImpact(historicalData.averageScore),
                description: String(format: "forecast.factor.historical_desc".localized, historicalData.dataPoints),
                confidence: historicalData.confidence
            ))
        }
        
        // Recent trend influence (25%)
        let trendInfluence = recentTrends.trendScore * 0.25
        predictionScore += trendInfluence
        
        factors.append(ForecastFactor(
            factor: "forecast.factor.recent_trend".localized,
            impact: scoreToImpact(recentTrends.trendScore),
            description: trendInfluence > 0 ? "forecast.factor.recent_trend_up".localized : "forecast.factor.recent_trend_down".localized,
            confidence: recentTrends.confidence
        ))
        
        // Yesterday's impact (30%)
        let yesterdayInfluence = yesterdayImpact.carryoverScore * 0.3
        predictionScore += yesterdayInfluence
        
        if abs(yesterdayInfluence) > 0.2 {
            factors.append(ForecastFactor(
                factor: "forecast.factor.yesterday".localized,
                impact: scoreToImpact(yesterdayImpact.carryoverScore),
                description: yesterdayImpact.description, // already localized below
                confidence: 0.8
            ))
        }
        
        // Weekday pattern influence (15%)
        let weekdayInfluence = weekdayPattern.averageScore * 0.15
        predictionScore += weekdayInfluence
        
        if weekdayPattern.confidence > 0.4 {
            factors.append(ForecastFactor(
                factor: weekdayPattern.weekdayName, // uses user's locale
                impact: scoreToImpact(weekdayPattern.averageScore),
                description: String(format: "forecast.factor.weekday_pattern".localized, (weekdayPattern.averageScore > 0 ? "risk.good_day".localized.lowercased() : "risk.challenging_day".localized.lowercased()), weekdayPattern.weekdayName),
                confidence: weekdayPattern.confidence
            ))
        }
        
        // Convert score to prediction
        let prediction = scoreToPrediction(predictionScore)
        let riskLevel = scoreToRiskLevel(predictionScore)
        let confidence = calculateOverallConfidence(factors)
        
        // Generate recommendations
        let recommendations = generateRecommendations(
            prediction: prediction,
            factors: factors,
            dog: dog,
            date: date
        )
        
        // Generate personalized message
        let personalizedMessage = generatePersonalizedMessage(
            dogName: dog.name,
            prediction: prediction,
            keyFactor: factors.first,
            date: date
        )
        
        return MorningForecast(
            dog: dog,
            date: date,
            overallPrediction: prediction,
            confidenceLevel: confidence,
            keyFactors: factors,
            recommendations: recommendations,
            riskLevel: riskLevel,
            weatherImpact: nil, // Will be added with weather integration
            personalizedMessage: personalizedMessage
        )
    }
    
    // MARK: - Historical Analysis
    
    private struct HistoricalData {
        let averageScore: Double
        let confidence: Double
        let dataPoints: Int
    }
    
    private func analyzeHistoricalPatterns(for dog: Dog, targetDate: Date) -> HistoricalData {
        let calendar = Calendar.current
        let targetWeekday = calendar.component(.weekday, from: targetDate)
        let targetDayOfMonth = calendar.component(.day, from: targetDate)
        
        // Find similar days (same weekday, similar date in month)
        let relevantRatings = dog.dailyRatings.filter { rating in
            let ratingWeekday = calendar.component(.weekday, from: rating.date)
            let ratingDayOfMonth = calendar.component(.day, from: rating.date)
            
            // Same weekday or similar day of month (±3 days)
            return ratingWeekday == targetWeekday || abs(ratingDayOfMonth - targetDayOfMonth) <= 3
        }
        
        guard relevantRatings.count >= 3 else {
            return HistoricalData(averageScore: 0.0, confidence: 0.0, dataPoints: 0)
        }
        
        let scores = relevantRatings.map { ratingToScore($0.rating) }
        let averageScore = scores.reduce(0, +) / Double(scores.count)
        let confidence = min(Double(relevantRatings.count) / 10.0, 1.0) // More data = higher confidence
        
        return HistoricalData(
            averageScore: averageScore,
            confidence: confidence,
            dataPoints: relevantRatings.count
        )
    }
    
    // MARK: - Recent Trends Analysis
    
    private struct RecentTrends {
        let trendScore: Double
        let confidence: Double
        let direction: String
    }
    
    private func analyzeRecentTrends(for dog: Dog, days: Int) -> RecentTrends {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let recentRatings = dog.dailyRatings
            .filter { $0.date >= cutoffDate }
            .sorted { $0.date < $1.date }
        
        guard recentRatings.count >= 3 else {
            return RecentTrends(trendScore: 0.0, confidence: 0.0, direction: "stable")
        }
        
        let scores = recentRatings.map { ratingToScore($0.rating) }
        
        // Calculate trend using linear regression
        let trendScore = calculateTrend(scores)
        let confidence = min(Double(recentRatings.count) / Double(days), 1.0)
        
        let direction = trendScore > 0.1 ? "improving" : trendScore < -0.1 ? "declining" : "stable"
        
        return RecentTrends(
            trendScore: trendScore,
            confidence: confidence,
            direction: direction
        )
    }
    
    // MARK: - Yesterday's Impact Analysis
    
    private struct YesterdayImpact {
        let carryoverScore: Double
        let description: String
    }
    
    private func analyzeYesterdayImpact(for dog: Dog, date: Date) -> YesterdayImpact {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        let yesterdayString = DateFormatter.dayFormatter.string(from: yesterday)
        
        // Check yesterday's rating
        let yesterdayRating = dog.dailyRatings.first { rating in
            DateFormatter.dayFormatter.string(from: rating.date) == yesterdayString
        }
        
        // Check yesterday's activities
        let yesterdayActivities = dog.activities.filter { activity in
            DateFormatter.dayFormatter.string(from: activity.date) == yesterdayString
        }
        
        var carryoverScore = 0.0
        var description = "forecast.factor.yesterday_neutral".localized
        
        if let rating = yesterdayRating {
            let ratingScore = ratingToScore(rating.rating)
            
            // Strong carryover for extreme days
            if ratingScore > 0.5 {
                carryoverScore += 0.3
                description = "forecast.factor.yesterday_positive".localized
            } else if ratingScore < -0.5 {
                carryoverScore -= 0.4
                description = "forecast.factor.yesterday_negative".localized
            }
        }
        
        // Check for high-impact activities yesterday
        let badActivities = yesterdayActivities.filter { $0.outcome == "bad" }
        if badActivities.count >= 2 {
            carryoverScore -= 0.3
            description = "forecast.factor.yesterday_many_bad".localized
        }
        
        let goodActivities = yesterdayActivities.filter { $0.outcome == "good" }
        if goodActivities.count >= 3 {
            carryoverScore += 0.2
            description = "forecast.factor.yesterday_many_good".localized
        }
        
        return YesterdayImpact(
            carryoverScore: carryoverScore,
            description: description
        )
    }
    
    // MARK: - Weekday Pattern Analysis
    
    private struct WeekdayPattern {
        let weekdayName: String
        let averageScore: Double
        let confidence: Double
    }
    
    private func analyzeWeekdayPattern(for dog: Dog, weekday: Int) -> WeekdayPattern {
        let weekdayName = DateFormatter().weekdaySymbols[weekday - 1]
        
        let weekdayRatings = dog.dailyRatings.filter { rating in
            Calendar.current.component(.weekday, from: rating.date) == weekday
        }
        
        guard weekdayRatings.count >= 2 else {
            return WeekdayPattern(weekdayName: weekdayName, averageScore: 0.0, confidence: 0.0)
        }
        
        let scores = weekdayRatings.map { ratingToScore($0.rating) }
        let averageScore = scores.reduce(0, +) / Double(scores.count)
        let confidence = min(Double(weekdayRatings.count) / 6.0, 1.0) // 6 weeks of data = full confidence
        
        return WeekdayPattern(
            weekdayName: weekdayName,
            averageScore: averageScore,
            confidence: confidence
        )
    }
    
    // MARK: - Helper Methods
    
    private func hasMinimumData(for dog: Dog) -> Bool {
        return dog.dailyRatings.count >= 3 || dog.activities.count >= 5
    }
    
    private func ratingToScore(_ rating: String) -> Double {
        switch rating {
        case "good": return 1.0
        case "okay": return 0.0
        case "bad": return -1.0
        default: return 0.0
        }
    }
    
    private func scoreToImpact(_ score: Double) -> FactorImpact {
        switch score {
        case 0.5...: return .veryPositive
        case 0.2..<0.5: return .positive
        case -0.2..<0.2: return .neutral
        case -0.5..<(-0.2): return .negative
        default: return .veryNegative
        }
    }
    
    private func scoreToPrediction(_ score: Double) -> DayPrediction {
        switch score {
        case 0.6...: return .excellent
        case 0.2..<0.6: return .good
        case -0.2..<0.2: return .okay
        case -0.6..<(-0.2): return .challenging
        default: return .difficult
        }
    }
    
    private func scoreToRiskLevel(_ score: Double) -> RiskLevel {
        switch score {
        case 0.3...: return .low
        case -0.2..<0.3: return .moderate
        case -0.6..<(-0.2): return .high
        default: return .critical
        }
    }
    
    private func calculateTrend(_ scores: [Double]) -> Double {
        guard scores.count > 1 else { return 0.0 }
        
        let n = Double(scores.count)
        let xValues = Array(0..<scores.count).map { Double($0) }
        
        let sumX = xValues.reduce(0, +)
        let sumY = scores.reduce(0, +)
        let sumXY = zip(xValues, scores).map(*).reduce(0, +)
        let sumXX = xValues.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        
        return slope // Positive = improving, Negative = declining
    }
    
    private func calculateOverallConfidence(_ factors: [ForecastFactor]) -> Double {
        guard !factors.isEmpty else { return 0.3 }
        
        let averageConfidence = factors.map { $0.confidence }.reduce(0, +) / Double(factors.count)
        return min(averageConfidence, 0.95) // Cap at 95%
    }
    
    private func generateRecommendations(prediction: DayPrediction, factors: [ForecastFactor], dog: Dog, date: Date) -> [ForecastRecommendation] {
        var recommendations: [ForecastRecommendation] = []
        
        switch prediction {
        case .excellent, .good:
            recommendations.append(ForecastRecommendation(
                title: "forecast.reco.try_new.title".localized,
                description: "forecast.reco.try_new.desc".localized,
                priority: .medium,
                timeOfDay: "forecast.time.afternoon".localized
            ))
            
        case .okay:
            recommendations.append(ForecastRecommendation(
                title: "forecast.reco.stick_routine.title".localized,
                description: "forecast.reco.stick_routine.desc".localized,
                priority: .medium,
                timeOfDay: "forecast.time.morning".localized
            ))
            
        case .challenging:
            recommendations.append(ForecastRecommendation(
                title: "forecast.reco.extra_patience.title".localized,
                description: "forecast.reco.extra_patience.desc".localized,
                priority: .high,
                timeOfDay: "forecast.time.all_day".localized
            ))
            
        case .difficult:
            recommendations.append(ForecastRecommendation(
                title: "forecast.reco.minimal_stress.title".localized,
                description: "forecast.reco.minimal_stress.desc".localized,
                priority: .critical,
                timeOfDay: "forecast.time.all_day".localized
            ))
        }
        
        // Add factor-specific recommendations
        for factor in factors.prefix(2) { // Top 2 factors
            if factor.impact == .negative || factor.impact == .veryNegative {
                switch factor.factor {
                case "forecast.factor.yesterday".localized:
                    recommendations.append(ForecastRecommendation(
                        title: "forecast.reco.recovery_mode.title".localized,
                        description: "forecast.reco.recovery_mode.desc".localized,
                        priority: .high,
                        timeOfDay: "forecast.time.morning".localized
                    ))
                    
                case "forecast.factor.recent_trend".localized:
                    recommendations.append(ForecastRecommendation(
                        title: "forecast.reco.break_pattern.title".localized,
                        description: "forecast.reco.break_pattern.desc".localized,
                        priority: .medium,
                        timeOfDay: nil
                    ))
                    
                default:
                    break
                }
            }
        }
        
        return recommendations
    }
    
    private func generatePersonalizedMessage(dogName: String, prediction: DayPrediction, keyFactor: ForecastFactor?, date: Date) -> String {
        let greeting = isWeekend(date) ? "forecast.greeting.weekend".localized : "forecast.greeting.morning".localized
        let predictionMessage: String
        switch prediction {
        case .excellent:
            predictionMessage = String(format: "forecast.msg.excellent".localized, dogName, prediction.emoji)
        case .good:
            predictionMessage = String(format: "forecast.msg.good".localized, dogName, prediction.emoji)
        case .okay:
            predictionMessage = String(format: "forecast.msg.okay".localized, dogName, prediction.emoji)
        case .challenging:
            predictionMessage = String(format: "forecast.msg.challenging".localized, dogName, prediction.emoji)
        case .difficult:
            predictionMessage = String(format: "forecast.msg.difficult".localized, dogName, prediction.emoji)
        }
        var message = "\(greeting) \(predictionMessage)"
        if let factor = keyFactor {
            message += " \(factor.impact.emoji) \("forecast.key_insight".localized) \(factor.description)"
        }
        message += "\n\n- Barkley"
        return message
    }
    
    private func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }
}
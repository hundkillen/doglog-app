import Foundation

// MARK: - Lagged Pattern

/// A detected day-after (or two-days-after) relationship between an activity
/// type and the dog's daily rating. Pure value type, explainable output.
struct LaggedPattern {
    /// Synthetic activity type for a day with zero logged activities.
    static let restDayType = "__rest_day__"
    /// Synthetic activity type for a day rated "bad".
    static let badDayType = "__bad_day__"
    /// Prefix for synthetic types built from DailyRating.contextTags,
    /// e.g. "tag_context.thunder".
    static let tagTypePrefix = "tag_"

    let activityType: String        // stable key or custom name
    let lagDays: Int                // 1 or 2
    let sampleCount: Int            // how many times this activity had a rated day at that lag
    let badRate: Double             // share of those lagged days rated "bad"
    let goodRate: Double
    let baselineBadRate: Double     // bad-share across ALL rated days for this dog
    let baselineGoodRate: Double
    let direction: Direction        // .negative (predicts bad), .positive (predicts good)

    enum Direction {
        case negative, positive
    }

    /// Effect size weighted by confidence; used for sorting.
    var score: Double {
        let rate = direction == .negative ? badRate : goodRate
        let baseline = direction == .negative ? baselineBadRate : baselineGoodRate
        return abs(rate - baseline) * min(1.0, Double(sampleCount) / 8.0)
    }
}

// MARK: - Display helpers

extension LaggedPattern {
    /// Human-readable name of the (possibly synthetic) activity type.
    var displayName: String {
        switch activityType {
        case LaggedPattern.restDayType:
            return "lagged.rest_day".localized
        case LaggedPattern.badDayType:
            return "lagged.bad_day".localized
        default:
            if activityType.hasPrefix(LaggedPattern.tagTypePrefix) {
                let tagKey = String(activityType.dropFirst(LaggedPattern.tagTypePrefix.count))
                return ContextTag.displayName(for: tagKey)
            }
            return ActivityCatalog.shared.displayName(forStoredType: activityType)
        }
    }

    /// Localized sentence, e.g.
    /// "After daycare: 5 of 6 following days were bad (baseline 20%)".
    var localizedDescription: String {
        let key: String
        switch (direction, lagDays) {
        case (.negative, 1): key = "lagged.pattern_negative_lag1"
        case (.positive, 1): key = "lagged.pattern_positive_lag1"
        case (.negative, _): key = "lagged.pattern_negative_lag2"
        case (.positive, _): key = "lagged.pattern_positive_lag2"
        }
        let rate = direction == .negative ? badRate : goodRate
        let baseline = direction == .negative ? baselineBadRate : baselineGoodRate
        let matchingCount = Int((rate * Double(sampleCount)).rounded())
        return String(
            format: key.localized,
            displayName,
            matchingCount,
            sampleCount,
            Int((baseline * 100).rounded())
        )
    }
}

// MARK: - Analyzer

/// On-device, counting-based analyzer answering: "which activity types predict
/// the next day's (and the day after's) rating?" No ML, no SwiftData queries —
/// operates purely on the arrays already loaded on the `Dog` object.
final class LaggedPatternAnalyzer {

    private static let lags = [1, 2]

    func analyze(dog: Dog, minSamples: Int = 4, minDeltaPercentagePoints: Double = 20) -> [LaggedPattern] {
        let calendar = Calendar.current

        // 1. Normalized rating-by-day map. Later entries win (latest by insertion).
        var ratingByDay: [Date: String] = [:]
        for rating in dog.dailyRatings {
            ratingByDay[calendar.startOfDay(for: rating.date)] = rating.rating
        }
        guard !ratingByDay.isEmpty else { return [] }

        // 2. Baseline distribution across all rated days.
        let ratedCount = Double(ratingByDay.count)
        let baselineBadRate = Double(ratingByDay.values.filter { $0 == "bad" }.count) / ratedCount
        let baselineGoodRate = Double(ratingByDay.values.filter { $0 == "good" }.count) / ratedCount

        // 3. Occurrence days per activity type (one occurrence per type per day).
        var occurrenceDaysByType: [String: Set<Date>] = [:]
        for activity in dog.activities {
            let day = calendar.startOfDay(for: activity.date)
            occurrenceDaysByType[activity.activityType, default: []].insert(day)
        }

        // 5. Synthetic types.
        let activityDays = Set(occurrenceDaysByType.values.flatMap { $0 })
        occurrenceDaysByType[LaggedPattern.restDayType] =
            restDays(activityDays: activityDays, ratedDays: Set(ratingByDay.keys), calendar: calendar)
        occurrenceDaysByType[LaggedPattern.badDayType] =
            Set(ratingByDay.filter { $0.value == "bad" }.keys)
        // Context tags (thunder, heat cycle, ...) get the same lag treatment
        // as activities, so confounds can surface as patterns of their own.
        for rating in dog.dailyRatings {
            let day = calendar.startOfDay(for: rating.date)
            for tag in rating.contextTags {
                occurrenceDaysByType[LaggedPattern.tagTypePrefix + tag, default: []].insert(day)
            }
        }

        // 4. Count lagged rating distributions and emit qualifying patterns.
        let minDelta = minDeltaPercentagePoints / 100.0
        var patterns: [LaggedPattern] = []

        for (type, days) in occurrenceDaysByType {
            for lag in Self.lags {
                var sampleCount = 0
                var badCount = 0
                var goodCount = 0
                for day in days {
                    guard let laggedDay = calendar.date(byAdding: .day, value: lag, to: day),
                          let rating = ratingByDay[laggedDay] else { continue }
                    sampleCount += 1
                    if rating == "bad" { badCount += 1 }
                    if rating == "good" { goodCount += 1 }
                }
                guard sampleCount >= minSamples else { continue }

                let badRate = Double(badCount) / Double(sampleCount)
                let goodRate = Double(goodCount) / Double(sampleCount)
                let badDelta = abs(badRate - baselineBadRate)
                let goodDelta = abs(goodRate - baselineGoodRate)

                let direction: LaggedPattern.Direction
                if badDelta >= minDelta && badDelta >= goodDelta {
                    direction = .negative
                } else if goodDelta >= minDelta {
                    direction = .positive
                } else {
                    continue
                }

                patterns.append(LaggedPattern(
                    activityType: type,
                    lagDays: lag,
                    sampleCount: sampleCount,
                    badRate: badRate,
                    goodRate: goodRate,
                    baselineBadRate: baselineBadRate,
                    baselineGoodRate: baselineGoodRate,
                    direction: direction
                ))
            }
        }

        // 6. Effect size weighted by confidence, descending.
        return patterns.sorted { $0.score > $1.score }
    }

    /// Days with zero logged activities that still lie within the dog's active
    /// logging period: a rest day only counts if at least one activity was
    /// logged in the surrounding ±3 days, so long gaps of non-usage are ignored.
    private func restDays(activityDays: Set<Date>, ratedDays: Set<Date>, calendar: Calendar) -> Set<Date> {
        let observedDays = activityDays.union(ratedDays)
        guard let first = observedDays.min(), let last = observedDays.max() else { return [] }

        var result: Set<Date> = []
        var day = first
        while day <= last {
            defer { day = calendar.date(byAdding: .day, value: 1, to: day) ?? last.addingTimeInterval(1) }
            guard !activityDays.contains(day) else { continue }
            let hasNearbyActivity = (-3...3).contains { offset in
                guard offset != 0,
                      let nearby = calendar.date(byAdding: .day, value: offset, to: day) else { return false }
                return activityDays.contains(nearby)
            }
            if hasNearbyActivity {
                result.insert(day)
            }
        }
        return result
    }
}

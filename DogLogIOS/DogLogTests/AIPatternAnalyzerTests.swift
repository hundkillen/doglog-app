import XCTest
import SwiftData
@testable import DogLog

final class AIPatternAnalyzerTests: XCTestCase {

    /// A dog whose first-half ratings are all "bad" used to produce an
    /// infinite improvement value, and converting that to Int crashed the
    /// app when preparing the ChatGPT data summary.
    @MainActor
    func testAllBadFirstHalfDoesNotCrashAndReportsPositiveImprovement() throws {
        let container = try ModelContainer(
            for: Dog.self, Activity.self, CustomActivity.self, DailyRating.self, DogPhoto.self, TrainingExercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let dog = Dog(name: "Testhund")
        context.insert(dog)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let ratings = ["bad", "bad", "good", "good"]
        for (offset, rating) in ratings.enumerated() {
            let date = calendar.date(byAdding: .day, value: offset - ratings.count, to: today)!
            let dailyRating = DailyRating(date: date, rating: rating)
            dailyRating.dog = dog
            context.insert(dailyRating)
        }
        try context.save()

        let insights = AIPatternAnalyzer().analyzeDog(dog, timeRange: .allTime)

        XCTAssertTrue(insights.overallMood.improvement.isFinite,
                      "Improvement must be finite even when the first half is all bad")
        XCTAssertGreaterThan(insights.overallMood.improvement, 0,
                             "Going from all-bad to all-good must report positive improvement")
        // This is what used to crash (Int(Double.infinity) traps at runtime).
        _ = Int(insights.overallMood.improvement)
    }
}

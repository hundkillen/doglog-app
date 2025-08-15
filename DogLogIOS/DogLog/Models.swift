import Foundation
import SwiftData

@Model
class Dog {
    var id: UUID
    var name: String
    var breed: String?
    var dateOfBirth: Date?
    var gender: String?
    var notes: String?
    var photoData: Data?
    
    @Relationship(deleteRule: .cascade, inverse: \Activity.dog)
    var activities: [Activity] = []
    
    @Relationship(deleteRule: .cascade, inverse: \DailyRating.dog)
    var dailyRatings: [DailyRating] = []
    
    init(name: String, breed: String? = nil, dateOfBirth: Date? = nil, gender: String? = nil, notes: String? = nil, photoData: Data? = nil) {
        self.id = UUID()
        self.name = name
        self.breed = breed
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.notes = notes
        self.photoData = photoData
    }
}

@Model
class Activity {
    var id: UUID
    var date: Date
    var activityType: String
    var outcome: String // "good", "okay", "bad"
    var notes: String?
    
    var dog: Dog?
    
    init(date: Date, activityType: String, outcome: String, notes: String? = nil) {
        self.id = UUID()
        self.date = date
        self.activityType = activityType
        self.outcome = outcome
        self.notes = notes
    }
}

@Model
class CustomActivity {
    var id: UUID
    var name: String
    var dateCreated: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.dateCreated = Date()
    }
}

@Model
class DailyRating {
    var id: UUID
    var date: Date
    var rating: String // "good", "okay", "bad"
    var notes: String?
    
    var dog: Dog?
    
    init(date: Date, rating: String, notes: String? = nil) {
        self.id = UUID()
        self.date = date
        self.rating = rating
        self.notes = notes
    }
}
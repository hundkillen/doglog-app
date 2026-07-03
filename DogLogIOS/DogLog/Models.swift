import Foundation
import SwiftData
import Foundation

@Model
class Dog {
    var id: UUID
    var name: String
    var breed: String?
    var dateOfBirth: Date?
    var gender: String?
    var notes: String?
    var photoData: Data? // Keep for backward compatibility
    var profilePhotoID: UUID? // ID of the main profile photo
    
    @Relationship(deleteRule: .cascade, inverse: \Activity.dog)
    var activities: [Activity] = []
    
    @Relationship(deleteRule: .cascade, inverse: \DailyRating.dog)
    var dailyRatings: [DailyRating] = []
    
    @Relationship(deleteRule: .cascade, inverse: \DogPhoto.dog)
    var photos: [DogPhoto] = []
    
    // Computed property to get the profile photo
    var profilePhoto: DogPhoto? {
        if let profilePhotoID = profilePhotoID {
            return photos.first { $0.id == profilePhotoID }
        }
        return photos.first
    }
    
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

// LEGACY – read-only, remove in vNext. Superseded by ActivityDefinition;
// kept so the one-shot migration can import old custom activities.
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

/// Single source of truth for activity identity. Default activities are
/// identified by a stable localization key ("activity.walk") so the stored
/// data never depends on the app language; custom ones get "custom_<uuid>".
@Model
class ActivityDefinition {
    var id: UUID
    var key: String         // "activity.walk" for defaults; "custom_<uuid>" for custom
    var customName: String? // nil for defaults (display via key.localized)
    var iconName: String    // SF Symbol
    var isDefault: Bool
    var sortOrder: Int
    var isArchived: Bool    // hide from picker without deleting history
    
    init(key: String, customName: String? = nil, iconName: String, isDefault: Bool, sortOrder: Int, isArchived: Bool = false) {
        self.id = UUID()
        self.key = key
        self.customName = customName
        self.iconName = iconName
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }
    
    var displayName: String {
        customName ?? key.localized
    }
}

@Model
class DailyRating {
    var id: UUID
    var date: Date
    var rating: String // "good", "okay", "bad"
    var notes: String?
    /// Context tag keys ("context.thunder", ...) — confounds like heat cycles
    /// or guests that the pattern engine should see. See ContextTag.
    var contextTags: [String] = []
    
    var dog: Dog?
    
    init(date: Date, rating: String, notes: String? = nil, contextTags: [String] = []) {
        self.id = UUID()
        self.date = date
        self.rating = rating
        self.notes = notes
        self.contextTags = contextTags
    }
}

/// Predefined context tags for a day: not activities, but circumstances
/// (weather, health, environment) that can explain a bad day so the lagged
/// pattern engine doesn't blame the wrong activity.
enum ContextTag {
    static let all: [(key: String, icon: String)] = [
        ("context.heat_cycle", "drop.circle.fill"),
        ("context.thunder", "cloud.bolt.rain.fill"),
        ("context.guests", "person.3.fill"),
        ("context.poor_sleep", "moon.zzz.fill"),
        ("context.sick_injured", "bandage.fill"),
        ("context.travel", "car.fill"),
        ("context.home_alone_long", "house.fill"),
        ("context.new_environment", "map.fill"),
    ]
    
    static func icon(for key: String) -> String {
        all.first { $0.key == key }?.icon ?? "tag.fill"
    }
    
    static func displayName(for key: String) -> String {
        key.localized
    }
}

@Model
class DogPhoto {
    var id: UUID
    var imageData: Data
    var dateAdded: Date
    var caption: String?
    
    var dog: Dog?
    
    init(imageData: Data, caption: String? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.dateAdded = Date()
        self.caption = caption
    }
}

@Model
class TrainingExercise {
    var id: UUID
    var name: String
    var category: String?
    var difficulty: String?
    var equipment: String?
    var instructions: String
    var tags: [String]
    var source: String?
    var isFavorite: Bool
    var createdAt: Date
    
    init(name: String, category: String? = nil, difficulty: String? = nil, equipment: String? = nil, instructions: String, tags: [String] = [], source: String? = nil, isFavorite: Bool = false) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.equipment = equipment
        self.instructions = instructions
        self.tags = tags
        self.source = source
        self.isFavorite = isFavorite
        self.createdAt = Date()
    }
}
import Foundation
import SwiftData

/// In-memory lookup from stored activity keys to display names and icons,
/// plus the one-shot migration that converts legacy localized-string data
/// to stable keys. See ActivityDefinition in Models.swift.
final class ActivityCatalog {
    static let shared = ActivityCatalog()
    private init() {}

    /// Default activities: stable key → SF Symbol.
    static let defaultSeed: [(key: String, icon: String)] = [
        ("activity.walk", "figure.walk"),
        ("activity.training", "graduationcap.fill"),
        ("activity.playtime", "tennisball.fill"),
        ("activity.feeding", "fork.knife"),
        ("activity.grooming", "comb.fill"),
        ("activity.vet_visit", "cross.case.fill"),
        ("activity.socialization", "person.2.fill"),
        ("activity.rest", "bed.double.fill"),
        ("activity.exercise", "figure.run"),
        ("activity.bath", "drop.fill"),
    ]

    static let customIcon = "pawprint.fill"
    private static let migrationFlag = "migration_v2_activity_keys_done"
    private static let testDaycareMigrationFlag = "migration_v3_test_daycare_key_done"

    /// Snapshot of definitions for synchronous lookups from views/models.
    /// Custom name is stored raw and default names resolve via `.localized`
    /// at lookup time, so an in-app language switch is picked up immediately.
    private var byKey: [String: (customName: String?, icon: String)] = [:]

    // MARK: - Lookup

    func refresh(from definitions: [ActivityDefinition]) {
        var map: [String: (String?, String)] = [:]
        for definition in definitions {
            map[definition.key] = (definition.customName, definition.iconName)
        }
        byKey = map
    }

    /// Display name for whatever is stored in Activity.activityType:
    /// a definition key, or (pre-migration / unknown) a raw string.
    func displayName(forStoredType storedType: String) -> String {
        if let entry = byKey[storedType] { return entry.customName ?? storedType.localized }
        if storedType.hasPrefix("activity.") { return storedType.localized }
        let localized = storedType.localized
        if localized != storedType { return localized }
        return storedType
    }

    func iconName(forStoredType storedType: String) -> String {
        if let entry = byKey[storedType] { return entry.icon }
        if let seeded = Self.defaultSeed.first(where: { $0.key == storedType }) { return seeded.icon }
        return Self.customIcon
    }

    // MARK: - Migration

    /// One-shot, safe on an empty database. Seeds default definitions,
    /// converts legacy localized activityType strings back to stable keys,
    /// and imports legacy custom activities. Always refreshes the lookup.
    func migrateIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard

        do {
            var definitions = try context.fetch(FetchDescriptor<ActivityDefinition>())

            if !defaults.bool(forKey: Self.migrationFlag) {
                // 1. Seed defaults if the table is empty.
                if definitions.isEmpty {
                    for (index, seed) in Self.defaultSeed.enumerated() {
                        context.insert(ActivityDefinition(
                            key: seed.key, iconName: seed.icon, isDefault: true, sortOrder: index
                        ))
                    }
                }
                definitions = try context.fetch(FetchDescriptor<ActivityDefinition>())

                // 2. Reverse map: localized default names (en + sv) → stable key.
                var localizedToKey: [String: String] = [:]
                for language in ["en", "sv"] {
                    let table = Self.localizedTable(for: language)
                    for seed in Self.defaultSeed {
                        if let localizedName = table[seed.key] {
                            localizedToKey[localizedName] = seed.key
                        }
                    }
                }

                // 3. Import legacy custom names (old CustomActivity rows and the
                //    old UserDefaults list) that aren't just localized defaults.
                var legacyCustomNames: [String] = []
                if let saved = defaults.array(forKey: "PredefinedActivities") as? [String] {
                    legacyCustomNames.append(contentsOf: saved)
                }
                if let customRows = try? context.fetch(FetchDescriptor<CustomActivity>()) {
                    legacyCustomNames.append(contentsOf: customRows.map { $0.name })
                }
                var sortOrder = definitions.map { $0.sortOrder }.max().map { $0 + 1 } ?? 0
                for name in legacyCustomNames {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty,
                          localizedToKey[trimmed] == nil,
                          !definitions.contains(where: { $0.displayName == trimmed || $0.customName == trimmed })
                    else { continue }
                    let definition = ActivityDefinition(
                        key: "custom_\(UUID().uuidString)",
                        customName: trimmed,
                        iconName: Self.customIcon,
                        isDefault: false,
                        sortOrder: sortOrder
                    )
                    context.insert(definition)
                    definitions.append(definition)
                    sortOrder += 1
                }

                // Custom names map to their definition key too.
                var nameToKey = localizedToKey
                for definition in definitions where !definition.isDefault {
                    if let customName = definition.customName {
                        nameToKey[customName] = definition.key
                    }
                }

                // 4. Rewrite existing Activity rows from display names to keys.
                let activities = try context.fetch(FetchDescriptor<Activity>())
                for activity in activities {
                    if let key = nameToKey[activity.activityType] {
                        activity.activityType = key
                    }
                }

                try context.save()
                defaults.set(true, forKey: Self.migrationFlag)
            }

            // One-shot: legacy test data stored "Doggy daycare" / "Hunddagis"
            // as localized strings — normalize to the stable key.
            if !defaults.bool(forKey: Self.testDaycareMigrationFlag) {
                var localizedToKey: [String: String] = [:]
                for language in ["en", "sv"] {
                    let table = Self.localizedTable(for: language)
                    if let localizedName = table["test.daycare"] {
                        localizedToKey[localizedName] = "test.daycare"
                    }
                }
                let activities = try context.fetch(FetchDescriptor<Activity>())
                var changed = false
                for activity in activities {
                    if let key = localizedToKey[activity.activityType] {
                        activity.activityType = key
                        changed = true
                    }
                }
                if changed { try context.save() }
                defaults.set(true, forKey: Self.testDaycareMigrationFlag)
            }

            refresh(from: definitions)
        } catch {
            print("ActivityCatalog migration error: \(error)")
        }
    }

    /// Loads the Localizable.strings table for a specific language,
    /// regardless of the device language.
    private static func localizedTable(for language: String) -> [String: String] {
        guard let path = Bundle.main.path(
            forResource: "Localizable", ofType: "strings",
            inDirectory: nil, forLocalization: language
        ), let dictionary = NSDictionary(contentsOfFile: path) as? [String: String] else {
            return [:]
        }
        return dictionary
    }
}

// MARK: - Daily rating dedup (task 3d)

/// One-shot cleanup: historically nothing prevented two DailyRating rows for
/// the same dog+day. The save path now updates in place; this pass removes
/// duplicates already in the store, keeping the newest row per dog+day.
enum DailyRatingDeduplicator {
    private static let flag = "migration_v2_daily_rating_dedup_done"
    
    static func runIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        
        do {
            let calendar = Calendar.current
            let ratings = try context.fetch(FetchDescriptor<DailyRating>())
            
            // Later fetch order = more recently inserted, so the last row in
            // each group is "the newest" and wins.
            var newestByKey: [String: DailyRating] = [:]
            var duplicates: [DailyRating] = []
            for rating in ratings {
                let dogID = rating.dog?.id.uuidString ?? "no-dog"
                let day = calendar.startOfDay(for: rating.date).timeIntervalSince1970
                let key = "\(dogID)|\(day)"
                if let previous = newestByKey[key] {
                    duplicates.append(previous)
                }
                newestByKey[key] = rating
            }
            
            for duplicate in duplicates {
                duplicate.dog?.dailyRatings.removeAll { $0.id == duplicate.id }
                context.delete(duplicate)
            }
            
            if !duplicates.isEmpty {
                try context.save()
                print("DailyRatingDeduplicator: removed \(duplicates.count) duplicate rating(s)")
            }
            UserDefaults.standard.set(true, forKey: flag)
        } catch {
            print("DailyRatingDeduplicator error: \(error)")
        }
    }
}

// MARK: - Activity display helpers

extension Activity {
    /// Human-readable name regardless of whether activityType holds a stable
    /// key (post-migration) or a legacy raw string.
    var displayName: String {
        ActivityCatalog.shared.displayName(forStoredType: activityType)
    }

    var iconName: String {
        ActivityCatalog.shared.iconName(forStoredType: activityType)
    }
}

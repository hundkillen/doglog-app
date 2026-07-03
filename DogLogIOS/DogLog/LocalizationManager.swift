import Foundation
import SwiftUI

// MARK: - Training Week Cache

/// UserDefaults cache for the AI-generated training week, including which
/// app language it was created in so we can prompt to regenerate after a
/// language switch instead of showing stale Swedish/English content.
enum TrainingWeekCache {
    private static let cachePrefix = "suggested_training_week_"

    static func cacheKey(dogId: UUID) -> String { "\(cachePrefix)\(dogId)" }
    static func languageKey(dogId: UUID) -> String { "\(cachePrefix)\(dogId)_language" }
    static func regenKey(dogId: UUID) -> String { "suggested_training_week_needs_regeneration_\(dogId)" }

    /// Stable language code at generation time ("en", "sv", or system-resolved).
    static var currentLanguageCode: String {
        LocalizationManager.shared.currentLanguage.languageCode
    }

    static func hasCachedWeek(dogId: UUID) -> Bool {
        UserDefaults.standard.data(forKey: cacheKey(dogId: dogId)) != nil
    }

    static func saveLanguage(dogId: UUID) {
        UserDefaults.standard.set(currentLanguageCode, forKey: languageKey(dogId: dogId))
    }

    static func cachedLanguage(dogId: UUID) -> String? {
        UserDefaults.standard.string(forKey: languageKey(dogId: dogId))
    }

    static func markNeedsRegeneration(dogId: UUID) {
        UserDefaults.standard.set(true, forKey: regenKey(dogId: dogId))
    }

    /// False when a cached week exists but was generated in a different language.
    static func isCacheLanguageCurrent(dogId: UUID) -> Bool {
        guard hasCachedWeek(dogId: dogId) else { return true }
        guard let cached = cachedLanguage(dogId: dogId) else { return true }
        return cached == currentLanguageCode
    }

    static func markNeedsRegenerationIfLanguageMismatch(dogId: UUID) {
        guard hasCachedWeek(dogId: dogId) else { return }
        if let cached = cachedLanguage(dogId: dogId) {
            guard cached != currentLanguageCode else { return }
        }
        markNeedsRegeneration(dogId: dogId)
    }

    /// Call when the in-app language changes: flag every dog whose cached week
    /// was generated in another language so the UI prompts to regenerate.
    static func handleLanguageChange() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            guard key.hasPrefix(cachePrefix),
                  !key.hasSuffix("_language"),
                  !key.contains("needs_regeneration"),
                  defaults.data(forKey: key) != nil,
                  let dogId = UUID(uuidString: String(key.dropFirst(cachePrefix.count)))
            else { continue }
            markNeedsRegenerationIfLanguageMismatch(dogId: dogId)
        }
        NotificationCenter.default.post(name: Notification.Name("trainingWeekNeedsRegeneration"), object: nil)
    }

    static func removeLanguage(dogId: UUID) {
        UserDefaults.standard.removeObject(forKey: languageKey(dogId: dogId))
    }

    /// One-shot: weeks saved before language tracking have no tag; prompt
    /// the owner to regenerate once so content matches the current language.
    static func migrateLegacyCachesIfNeeded() {
        let flag = "migration_training_week_language_v1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            guard key.hasPrefix(cachePrefix),
                  !key.hasSuffix("_language"),
                  !key.contains("needs_regeneration"),
                  defaults.data(forKey: key) != nil,
                  let dogId = UUID(uuidString: String(key.dropFirst(cachePrefix.count))),
                  cachedLanguage(dogId: dogId) == nil
            else { continue }
            markNeedsRegeneration(dogId: dogId)
        }
        defaults.set(true, forKey: flag)
    }
}

// MARK: - Localization Manager
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            TrainingWeekCache.handleLanguageChange()
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }
    
    enum AppLanguage: String, CaseIterable {
        case system = "system"
        case swedish = "sv"
        case english = "en"
        
        var displayName: String {
            switch self {
            case .system:
                return NSLocalizedString("language.system", comment: "System Language")
            case .swedish:
                return "Svenska"
            case .english:
                return "English"
            }
        }
        
        var icon: String {
            switch self {
            case .system: return "globe"
            case .swedish: return "flag.fill"
            case .english: return "flag.fill"
            }
        }
        
        var locale: Locale {
            switch self {
            case .system:
                return Locale.current
            case .swedish:
                return Locale(identifier: "sv_SE")
            case .english:
                return Locale(identifier: "en_US")
            }
        }
        
        var languageCode: String {
            switch self {
            case .system:
                return Locale.current.language.languageCode?.identifier ?? "en"
            case .swedish:
                return "sv"
            case .english:
                return "en"
            }
        }
    }
    
    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Auto-detect system language
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            if systemLanguage.hasPrefix("sv") {
                self.currentLanguage = .swedish
            } else {
                self.currentLanguage = .system
            }
        }
    }
    
    func localizedString(_ key: String, comment: String = "") -> String {
        let bundle: Bundle
        
        switch currentLanguage {
        case .system:
            bundle = Bundle.main
        case .swedish:
            if let path = Bundle.main.path(forResource: "sv", ofType: "lproj"),
               let swedishBundle = Bundle(path: path) {
                bundle = swedishBundle
            } else {
                bundle = Bundle.main
            }
        case .english:
            if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let englishBundle = Bundle(path: path) {
                bundle = englishBundle
            } else {
                bundle = Bundle.main
            }
        }
        
        return NSLocalizedString(key, bundle: bundle, comment: comment)
    }
    
    func isSwedish() -> Bool {
        switch currentLanguage {
        case .system:
            return Locale.current.language.languageCode?.identifier.hasPrefix("sv") ?? false
        case .swedish:
            return true
        case .english:
            return false
        }
    }
    
    func getLocale() -> Locale {
        return currentLanguage.locale
    }
    
    func getChatGPTLanguageInstruction() -> String {
        if isSwedish() {
            return "Svara på svenska. Använd svenska termer för hundträning och hundbeteende."
        } else {
            return "Respond in English. Use English terms for dog training and behavior."
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - String Extension for Localization
extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }
    
    func localized(comment: String = "") -> String {
        return LocalizationManager.shared.localizedString(self, comment: comment)
    }
}

// MARK: - View Extension for Language Changes
extension View {
    func onLanguageChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            action()
        }
    }
}
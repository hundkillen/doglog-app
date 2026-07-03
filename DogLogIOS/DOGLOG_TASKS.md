# DogLog — Implementation Spec (Code Review Follow-up)

This document is the result of a full code review of the DogLog codebase (2026-07-02).
Work through the tasks **in the order listed**. Priority 1–2 are blocking; do not start
Priority 4+ before 1–3 are done and building.

Context for the agent: DogLog is a SwiftUI + SwiftData iOS app (deployment target 17.0)
that lets dog owners log daily activities and grade them good/okay/bad, grade the whole
day, and see the results color-coded in a calendar. The core product idea — the whole
reason the app exists — is **lagged cause-and-effect**: activities on day N affect the
dog's behavior on day N+1 and N+2 (e.g. "day after doggy daycare is always a red day").
The review found that this core analysis is NOT implemented anywhere, and that the
ChatGPT integration only receives aggregated stats, never a day-by-day timeline, so the
AI cannot discover lagged patterns either. Fixing that is Priority 1.

General rules for all tasks:

- The app is fully localized (en + sv). Every user-visible string goes through
  `"key".localized`. When you add strings, add them to BOTH
  `DogLog/en.lproj/Localizable.strings` and `DogLog/sv.lproj/Localizable.strings`.
- Do not rename existing localization keys.
- All data migrations must be one-shot, guarded by a UserDefaults flag
  (e.g. `migration_v2_activity_keys_done`), and safe to run on an empty database.
- Build after every task. Do not batch multiple priorities into one giant change.
- Existing models: `Dog`, `Activity`, `CustomActivity`, `DailyRating`, `DogPhoto`,
  `TrainingExercise` in `DogLog/Models.swift`. Ratings/outcomes are the strings
  `"good"` / `"okay"` / `"bad"`.

---

## Priority 1 — The lagged pattern engine (the actual product)

### 1a. New file: `DogLog/LaggedPatternAnalyzer.swift`

Create a local, on-device analyzer that answers: *"which activity types predict the
next day's (and the day after's) rating?"* No ML, pure counting. Explainable output.

Spec:

```swift
struct LaggedPattern {
    let activityType: String        // stable key or custom name
    let lagDays: Int                // 1 or 2
    let sampleCount: Int            // how many times this activity had a rated day at that lag
    let badRate: Double             // share of those lagged days rated "bad"
    let goodRate: Double
    let baselineBadRate: Double     // bad-share across ALL rated days for this dog
    let baselineGoodRate: Double
    let direction: Direction        // .negative (predicts bad), .positive (predicts good)
    enum Direction { case negative, positive }
}

final class LaggedPatternAnalyzer {
    func analyze(dog: Dog, minSamples: Int = 4, minDeltaPercentagePoints: Double = 20) -> [LaggedPattern]
}
```

Algorithm:

1. Normalize dates with `Calendar.current.startOfDay(for:)`. Build
   `ratingByDay: [Date: String]` from `dog.dailyRatings` (if duplicates exist for a
   day, use the latest by insertion — but also see task 3d).
2. Compute baseline: over all rated days, share rated bad and share rated good.
3. Group `dog.activities` by `activityType`. For each type, for each occurrence date D,
   look up the rating at D+1 (lag 1) and D+2 (lag 2). Count distributions per lag.
4. Emit a `LaggedPattern` when `sampleCount >= minSamples` AND
   `abs(rate - baselineRate) >= minDelta/100` for either bad (→ .negative) or
   good (→ .positive). If both trigger, emit the stronger one.
5. Also treat two synthetic "activity types" the same way:
   - `"__rest_day__"`: a day with zero logged activities (only counts if the dog has
     ≥ 1 activity logged in the surrounding ±3 days, so long gaps of non-usage don't
     count as rest days).
   - `"__bad_day__"`: day rated bad → does a bad day predict another bad day?
6. Sort results by `abs(rate - baseline) * min(1.0, Double(sampleCount)/8.0)`
   (effect size weighted by confidence), descending.
7. Keep it pure and unit-testable: no SwiftData queries inside, operate on the arrays
   from the `Dog` object.

Add localized display strings, e.g.:
- en: `"After %@: %d of %d following days were bad (baseline %d%%)"`
- sv: `"Efter %@: %d av %d följande dagar var dåliga (baslinje %d%%)"`

### 1b. Surface the results in `AIInsightsView`

Add a "Lagged patterns" section (localized title, en: "Day-after patterns",
sv: "Dagen-efter-mönster") ABOVE the existing local insights. Each pattern is a card:
icon (arrow.down.right.circle for negative, arrow.up.right.circle for positive),
the sentence above, and a small sample-size caption ("based on N occurrences").
If the analyzer returns nothing, show one card explaining that ~3 weeks of daily
logging is needed before day-after patterns can be detected (localized).

### 1c. Feed the AI a real timeline — fix `prepareDataSummary` in `ChatGPTService.swift`

`prepareDataSummary` currently sends only aggregates (frequencies, success rates,
mood trend). The model never sees the sequence of days, so it cannot find lagged
patterns. Change it:

1. Append a `DAILY TIMELINE` section: one line per day, most recent ~120 rated days,
   oldest first, compact format:
   ```
   2026-06-28 Sun [DAY: bad] daycare(okay), walk(bad) | note: "very reactive on walk"
   2026-06-29 Mon [DAY: good] rest day
   ```
   Truncate each note to 80 chars. Days with neither rating nor activities are skipped
   but a gap marker `--- 3 days not logged ---` is inserted so the model knows.
2. Append a `LOCALLY DETECTED LAGGED PATTERNS` section with the output of
   `LaggedPatternAnalyzer` (or "none detected yet").
3. Update the system prompt in `analyzeWithChatGPT`: add an explicit instruction —
   the model must analyze **lagged effects** (activities on day N vs ratings on
   N+1/N+2, trigger stacking across consecutive days, missing decompression after
   intense days), must validate or refute the locally detected patterns, and must add
   a `"laggedPatterns"` array to the JSON output:
   ```json
   "laggedPatterns": [
     {"cause": "...", "effect": "...", "evidence": "...", "recommendation": "..."}
   ]
   ```
4. Add `laggedPatterns` to the `ChatGPTAnalysis` Codable struct as an OPTIONAL field
   (`let laggedPatterns: [LaggedPatternDTO]?`) so old cached JSON still decodes.
   Render it in `AIInsightsView`.
5. Token sanity: the timeline at ~120 days ≈ a few thousand tokens. That is fine, but
   raise `maxTokens` awareness: keep request `maxTokens` (response cap) as is.

---

## Priority 2 — Crash + security fixes

### 2a. Division-by-zero crash in `AIPatternAnalyzer.swift`

`calculateMoodImprovement` computes `((secondScore - firstScore) / firstScore) * 100`.
`moodScore` maps `"bad"` → 0.0, so a dog whose first half of ratings are all bad gives
`firstScore == 0` → result is `Double.infinity`. `ChatGPTService.prepareDataSummary`
then does `Int(localInsights.overallMood.improvement)` — converting an infinite Double
to Int **crashes** in Swift. This hits exactly the target user (dog that started badly).

Fix:
- In `calculateMoodImprovement`: if `firstScore == 0`, return
  `secondScore > 0 ? 100.0 : 0.0` (define improvement-from-zero as +100%).
- Same guard in `calculateActivityTrend` (same file) — there it only produces a
  garbage comparison, but fix it anyway.
- Grep the whole project for `Int(` applied to `.improvement` or any other computed
  Double ratio and guard every conversion with `.isFinite` (fallback 0).
- Add a unit test: dog with ratings [bad, bad, good, good] must not crash and must
  report positive improvement.

### 2b. Move the API key from UserDefaults to Keychain

`ChatGPTService.apiKey` reads/writes `UserDefaults.standard` key `"ChatGPT_API_Key"`.
UserDefaults is a plaintext plist. Replace with Keychain:

1. New file `DogLog/KeychainHelper.swift`: minimal wrapper over Security framework
   (`kSecClassGenericPassword`, service `"com.doglog.apikeys"`, account per provider,
   e.g. `"openai"`). Functions: `set(_ value: String, account: String)`,
   `get(account: String) -> String?`, `delete(account: String)`. Use
   `kSecAttrAccessibleAfterFirstUnlock`.
2. In `ChatGPTService.apiKey`: getter reads Keychain first; if nil, reads the old
   UserDefaults key, and if found, writes it to Keychain and REMOVES it from
   UserDefaults (silent one-time migration). Setter writes Keychain only.
3. Nothing else in the call sites changes.

### 2c. Deprecated APIs (target is iOS 17)

- `DogLogApp.swift`: replace both `UIApplication.shared.applicationIconBadgeNumber = 0`
  with `UNUserNotificationCenter.current().setBadgeCount(0)`.
- Replace `NavigationView` with `NavigationStack` in `ContentView.swift` and anywhere
  else it appears (grep). Remove the now-meaningless `.navigationViewStyle(...)`.
  Verify sheets/navigation still behave on iPhone.

---

## Priority 3 — Data model integrity

### 3a. Stop storing localized strings as data (activity identity bug)

`DailyActivityView.loadPredefinedActivities()` builds the default list from
`"activity.walk".localized` etc. and SAVES those localized display strings both to
UserDefaults (`"PredefinedActivities"`) and into `Activity.activityType`. Consequence:
switching app language splits one activity into two ("Walk" vs "Promenad"), which
corrupts history AND silently breaks all pattern analysis (including Priority 1).

Fix — introduce a single source of truth:

1. New SwiftData model `ActivityDefinition`:
   ```swift
   @Model class ActivityDefinition {
       var id: UUID
       var key: String        // "activity.walk" for defaults; "custom_<uuid>" for custom
       var customName: String? // nil for defaults (display via key.localized)
       var iconName: String    // SF Symbol
       var isDefault: Bool
       var sortOrder: Int
       var isArchived: Bool    // hide from picker without deleting history
   }
   ```
   Display name = `customName ?? key.localized`.
2. Default seed (key → SF Symbol): activity.walk → figure.walk,
   activity.training → graduationcap.fill, activity.playtime → tennisball.fill,
   activity.feeding → fork.knife, activity.grooming → comb.fill,
   activity.vet_visit → cross.case.fill, activity.socialization → person.2.fill,
   activity.rest → bed.double.fill, activity.exercise → figure.run,
   activity.bath → drop.fill.
3. `Activity.activityType` now stores the **key** (or custom name for legacy customs).
   Add a computed `Activity.displayName` that resolves via ActivityDefinition lookup
   with fallback to the raw stored string, so nothing renders wrong during transition.
4. **Migration (one-shot, flag `migration_v2_activity_keys_done`):**
   - Seed `ActivityDefinition` defaults if the table is empty.
   - Build a reverse map: for each default key, its localized value in BOTH en and sv
     (load both `.strings` files via `Bundle.path(forResource:"Localizable", ofType:"strings", inDirectory:nil, forLocalization:"sv")`
     etc.). Map every existing `Activity.activityType` matching a localized default
     back to its stable key.
   - Import old `CustomActivity` rows and old UserDefaults `"PredefinedActivities"`
     entries (that aren't defaults) as custom `ActivityDefinition`s with
     iconName `"pawprint.fill"`.
   - Leave old data sources in place (read-only) for one release; stop writing to them.
5. Update `DailyActivityView` picker to read `ActivityDefinition` (SwiftData query,
   sorted by sortOrder), show the icon in the grid, and allow add/edit/archive of
   custom ones. Delete of a default = archive.
6. Show the activity icon everywhere activities are listed (day detail, calendar day
   view if it shows activities, insights).

### 3b. Kill the duplicate custom-activity storage

After 3a, `CustomActivity` and the UserDefaults `"PredefinedActivities"` array are
legacy. Remove all WRITE paths to both. Keep the models/keys readable for the
migration, mark them clearly `// LEGACY – read-only, remove in vNext`.

### 3c. Context tags on the day (confound tracking)

Behavior isn't only activities: heat cycles, thunder, guests, poor sleep, illness.
Without these the pattern engine blames the wrong things.

1. Add `var contextTags: [String] = []` to `DailyRating` (SwiftData handles the
   lightweight migration; verify on an existing store).
2. Predefined tag keys (localize en+sv): context.heat_cycle, context.thunder,
   context.guests, context.poor_sleep, context.sick_injured, context.travel,
   context.home_alone_long, context.new_environment.
3. UI: in the day-rating flow, a horizontal wrap of toggle chips (icon + label),
   zero typing required, all optional.
4. Include tags in the Priority 1c timeline lines: `[tags: thunder, guests]`.
5. `LaggedPatternAnalyzer`: treat each tag as a synthetic activity type on that day
   (same lag logic), prefixed `"tag_"` so display can distinguish.

### 3d. Duplicate-day guard

Nothing prevents two `DailyRating` rows for the same dog+day. Before saving a rating,
check for an existing rating on `startOfDay` for that dog and UPDATE it instead of
inserting. Add a migration pass that deduplicates existing data (keep the newest).

---

## Priority 4 — Honesty fixes on existing features

### 4a. `fetchExerciseCatalog` claims the internet, uses none

It calls plain chat completions on `gpt-4o-mini` — the model invents exercises from
training data; there is no web search on that endpoint. Two options, do BOTH:

1. Short term: change nothing functionally but make the UI copy honest — the button
   and description must say "AI-generated exercise library", not anything implying
   fresh internet content.
2. Real fix: add a second code path using OpenAI's Responses API
   (`POST https://api.openai.com/v1/responses`) with the `web_search` tool enabled,
   model `gpt-4o-mini`, same JSON-array output contract. Feature-flag it
   (`Settings → "Use web search for exercises"`, default off). Verify the current
   request/response shape against OpenAI's live docs before implementing — do not
   code it from memory.

### 4b. Refresh scheduling (from the original spec, never implemented)

Settings: exercise-library refresh interval — weekly / bi-weekly / monthly / manual
(default manual). Implement as a lazy check on app foreground: if
`lastExerciseFetchDate` is older than the interval and an API key exists, refresh in
the background of the session and merge (dedupe by exercise name, keep favorites).
Do NOT use BGTaskScheduler for this; on-foreground check is more reliable and simpler.

### 4c. Minor prompt hygiene in `ChatGPTService`

- `getNext7DaysStartingFromToday()` hardcodes `Locale(identifier: "en_US")` day names
  while the response may be Swedish. Keep en_US for the JSON `dayName` contract but
  add to the prompt: "dayName values must remain in English exactly as provided;
  translate everything else."
- `hasValidAPIKey` checks `hasPrefix("sk-")`. Keep for OpenAI but move validation
  next to the provider definition so it doesn't block future providers.

---

## Priority 5 — Cleanup (from CLAUDE.md, still valid)

- Hide the "Generate Test Data" button behind `#if DEBUG`.
- Replace the `print()` debug logging in ChatGPTService/NotificationManager with
  `os.Logger` (subsystem `com.doglog`, categories `ai`, `notifications`, `patterns`).
  Never log the API key or full prompts in release builds.
- Update the tutorial pages to mention: day-after patterns, context tags, icons.

## Explicitly parked — do NOT build now

- Apple Watch app
- Gamification/badges/streaks (product decision pending: streaks tied to the DOG's
  mood are emotionally punishing for owners of struggling dogs; only logging-streaks
  would ever be acceptable)
- Multi-provider AI (Claude/Grok) — architecture should not preclude it (see 4c) but
  no implementation yet

---

## Acceptance checklist

- [ ] Dog with 30 days of test data where "daycare" is always followed by a bad day →
      LaggedPatternAnalyzer reports it, AIInsightsView shows it, and the ChatGPT
      timeline section contains all 30 lines.
- [ ] Dog whose first-half ratings are all "bad" → AI analysis runs without crashing.
- [ ] API key survives app reinstall-free upgrade, is gone from the UserDefaults
      plist, works from Keychain.
- [ ] Switch app language sv↔en → activity history stays unified, icons unchanged.
- [ ] Rating the same day twice updates instead of duplicating.
- [ ] Project builds with zero deprecation warnings for NavigationView /
      applicationIconBadgeNumber.
- [ ] Both Localizable.strings files contain every new key (script-check:
      keys present in en but not sv = fail).

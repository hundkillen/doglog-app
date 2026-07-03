import Foundation
import SwiftData
import os

// MARK: - Logging

enum DogLogLogger {
    static let ai = Logger(subsystem: "com.doglog", category: "ai")
    static let notifications = Logger(subsystem: "com.doglog", category: "notifications")
    static let patterns = Logger(subsystem: "com.doglog", category: "patterns")
}

// MARK: - ChatGPT Service
/// AI provider definition. Key validation lives here (not in call sites) so a
/// future provider (Claude, Grok, ...) only needs a new case, not a code hunt.
enum AIProvider {
    case openAI
    
    var chatCompletionsURL: String { "https://api.openai.com/v1/chat/completions" }
    var responsesURL: String { "https://api.openai.com/v1/responses" }
    
    func isValidKey(_ key: String) -> Bool {
        switch self {
        case .openAI:
            return key.hasPrefix("sk-") && key.count > 20
        }
    }
}

class ChatGPTService: ObservableObject {
    static let shared = ChatGPTService()
    
    @Published var isLoading = false
    
    private let provider: AIProvider = .openAI
    private var baseURL: String { provider.chatCompletionsURL }
    
    /// Settings toggle: fetch exercises via OpenAI's Responses API with the
    /// hosted web_search tool instead of plain (offline-knowledge) completions.
    static let webSearchExercisesKey = "use_web_search_for_exercises"
    
    private init() {}
    
    /// OpenAI signals "account out of credit" with the same 429 status as
    /// rate limiting; only the error body distinguishes them.
    private static func isInsufficientQuota(_ data: Data) -> Bool {
        guard let body = String(data: data, encoding: .utf8) else { return false }
        return body.contains("insufficient_quota") || body.contains("exceeded your current quota")
    }
    
    /// @Published properties must be mutated on the main thread; these methods
    /// run in background async contexts, so hop to main before updating.
    private func setLoading(_ value: Bool) {
        if Thread.isMainThread {
            isLoading = value
        } else {
            DispatchQueue.main.async { self.isLoading = value }
        }
    }
    
    // MARK: - API Key Management
    private static let keychainAccount = "openai"
    private static let legacyDefaultsKey = "ChatGPT_API_Key"
    
    var apiKey: String? {
        get {
            if let key = KeychainHelper.get(account: Self.keychainAccount) {
                return key
            }
            // One-time silent migration: keys stored by older versions live in
            // UserDefaults (a plaintext plist). Move them to the Keychain.
            if let legacyKey = UserDefaults.standard.string(forKey: Self.legacyDefaultsKey) {
                KeychainHelper.set(legacyKey, account: Self.keychainAccount)
                UserDefaults.standard.removeObject(forKey: Self.legacyDefaultsKey)
                return legacyKey
            }
            return nil
        }
        set {
            if let newValue = newValue, !newValue.isEmpty {
                KeychainHelper.set(newValue, account: Self.keychainAccount)
            } else {
                KeychainHelper.delete(account: Self.keychainAccount)
            }
        }
    }
    
    var hasValidAPIKey: Bool {
        guard let key = apiKey, !key.isEmpty else { return false }
        return provider.isValidKey(key)
    }
    
    // MARK: - ChatGPT Analysis
    func analyzeWithChatGPT(
        dog: Dog,
        timeRange: AIPatternAnalyzer.AnalysisTimeRange,
        localInsights: AIPatternAnalyzer.DogInsights
    ) async throws -> ChatGPTAnalysis {
        
        guard hasValidAPIKey, let apiKey = apiKey else {
            throw ChatGPTError.missingAPIKey
        }
        
        setLoading(true)
        defer { setLoading(false) }
        
        // Check cache first
        let cacheKey = generateCacheKey(dogId: dog.id, timeRange: timeRange)
        if let cachedAnalysis = getCachedAnalysis(key: cacheKey) {
            return cachedAnalysis
        }
        
        // Prepare data summary for ChatGPT
        let dataSummary = prepareDataSummary(dog: dog, timeRange: timeRange, localInsights: localInsights)
        
        // Get language instruction
        let languageInstruction = LocalizationManager.shared.getChatGPTLanguageInstruction()
        
        // Create ChatGPT request
        let messages = [
            ChatGPTMessage(
                role: "system",
                content: """
                You are Barkley, expert dog behaviorist. Analyze this dog's data and provide breed-specific, age-appropriate training advice.

                LANGUAGE: \(languageInstruction)

                Focus on:
                - Breed traits & exercise needs
                - Age-appropriate expectations
                - Specific training techniques
                - Actionable recommendations

                CRITICAL — LAGGED EFFECTS ANALYSIS:
                The data includes a DAILY TIMELINE. You MUST analyze lagged cause-and-effect:
                - Compare activities on day N against day ratings on N+1 and N+2 (e.g. "day after daycare is always a bad day").
                - Look for trigger stacking: multiple intense days in a row followed by a crash.
                - Look for missing decompression: intense days not followed by rest days.
                - The data also includes LOCALLY DETECTED LAGGED PATTERNS from on-device counting. Validate or refute each one against the timeline, and say why.
                Report your findings in the "laggedPatterns" array of the JSON output. If you find no credible lagged pattern, return an empty array — do not invent patterns.

                Respond in this exact JSON format:
                {
                    "summary": "Professional assessment as Barkley would provide",
                    "breedAnalysis": {
                        "breedTraits": ["trait1", "trait2", "trait3"],
                        "exerciseNeeds": "Description of breed-specific exercise requirements",
                        "mentalStimulationNeeds": "Description of breed-specific mental stimulation needs",
                        "commonIssues": ["issue1", "issue2"]
                    },
                    "ageConsiderations": {
                        "developmentalStage": "puppy|adolescent|adult|senior",
                        "ageAppropriateExpectations": "What's normal for this age",
                        "trainingReadiness": "Age-specific training capabilities"
                    },
                    "behaviorAssessment": {
                        "strengths": ["strength1", "strength2"],
                        "concerns": ["concern1", "concern2"],
                        "overallScore": 85,
                        "progressTrend": "improving|stable|declining"
                    },
                    "trainingRecommendations": [
                        {
                            "issue": "Specific behavioral issue or improvement area",
                            "technique": "Exact training technique name",
                            "steps": ["step1", "step2", "step3"],
                            "duration": "Expected training timeline",
                            "frequency": "How often to practice",
                            "priority": "high|medium|low"
                        }
                    ],
                    "keyInsights": ["insight1", "insight2", "insight3"],
                    "laggedPatterns": [
                        {
                            "cause": "What happened (e.g. 'doggy daycare')",
                            "effect": "What followed and when (e.g. 'bad day the day after')",
                            "evidence": "Specific dates/counts from the timeline supporting this",
                            "recommendation": "What the owner should do about it"
                        }
                    ],
                    "healthIndicators": {
                        "exerciseLevel": "excellent|good|fair|poor",
                        "mentalStimulation": "excellent|good|fair|poor",
                        "routineConsistency": "excellent|good|fair|poor"
                    }
                }
                """
            ),
            ChatGPTMessage(
                role: "user",
                content: dataSummary
            )
        ]
        
        let requestBody = ChatGPTRequest(
            model: "gpt-4o-mini",
            messages: messages,
            temperature: 0.3,
            maxTokens: 2500
        )
        
        // Make API request
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatGPTError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw ChatGPTError.invalidAPIKey
            } else if httpResponse.statusCode == 429 {
                // OpenAI returns 429 both for rate limits and for an account
                // that is out of credit; the response body tells them apart.
                throw Self.isInsufficientQuota(data) ? ChatGPTError.insufficientQuota : ChatGPTError.rateLimitExceeded
            } else {
                throw ChatGPTError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        let chatGPTResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
        
        guard let content = chatGPTResponse.choices.first?.message.content else {
            throw ChatGPTError.invalidResponse
        }
        
        // Parse the JSON response from ChatGPT
        let analysis = try parseChatGPTResponse(content)
        
        // Cache the result
        cacheAnalysis(analysis, key: cacheKey)
        
        return analysis
    }

    // MARK: - ChatGPT Note Guidance
    func generateNoteGuidance(dog: Dog, timeRange: AIPatternAnalyzer.AnalysisTimeRange, excludeTips: [String] = []) async throws -> [String] {
        guard hasValidAPIKey, let apiKey = apiKey else { throw ChatGPTError.missingAPIKey }
        let activities = filterActivitiesForSummary(dog.activities, timeRange: timeRange)
        let ratings = filterRatingsForSummary(dog.dailyRatings, timeRange: timeRange)
        let recentNotes: [String] = (
            activities.compactMap { $0.notes }.suffix(10) +
            ratings.compactMap { $0.notes }.suffix(10)
        )
        let notesText = recentNotes.isEmpty ? "(no notes)" : recentNotes.joined(separator: "\n• ")
        let languageInstruction = LocalizationManager.shared.getChatGPTLanguageInstruction()
        // Build an exclusion list so output differs from local tips
        let excludedBlock = excludeTips.isEmpty ? "(none)" : excludeTips.enumerated().map { "\($0+1). \($1)" }.joined(separator: "\n")
        let messages = [
            ChatGPTMessage(role: "system", content: """
            You are Barkley, expert dog trainer. LANGUAGE: \(languageInstruction)
            Task: Provide 3-5 short, beginner-friendly tips for the owner based on the notes.
            Requirements:
            - Do NOT repeat or paraphrase tips listed in EXCLUDED.
            - Be specific and actionable (what to do today, concrete examples).
            - One concise sentence per tip (10–18 words), no numbering, no emojis.
            Output JSON array of strings only.
            """),
            ChatGPTMessage(role: "user", content: """
            Recent owner notes (bulleted):
            • \(notesText)
            
            EXCLUDED (already shown by the app):
            \(excludedBlock)
            """)
        ]
        let requestBody = ChatGPTRequest(model: "gpt-4o-mini", messages: messages, temperature: 0.6, maxTokens: 600)
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ChatGPTError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        let resp = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
        guard let content = resp.choices.first?.message.content else { throw ChatGPTError.invalidResponse }
        let jsonStart = content.firstIndex(of: "[") ?? content.startIndex
        let jsonEnd = content.lastIndex(of: "]") ?? content.endIndex
        let json = String(content[jsonStart...jsonEnd])
        guard let arrData = json.data(using: .utf8) else { throw ChatGPTError.parsingError }
        let tips = try JSONDecoder().decode([String].self, from: arrData)
        return tips
    }
    
    // MARK: - Suggested Training Week Generation
    func generateSuggestedTrainingWeek(
        dog: Dog,
        analysis: ChatGPTAnalysis,
        exerciseCatalogSummary: String? = nil
    ) async throws -> SuggestedTrainingWeek {
        
        guard hasValidAPIKey, let apiKey = apiKey else {
            throw ChatGPTError.missingAPIKey
        }
        
        setLoading(true)
        defer { setLoading(false) }
        
        // Get language instruction
        let languageInstruction = LocalizationManager.shared.getChatGPTLanguageInstruction()
        
        // Get the next 7 days starting from today for the JSON example
        let weekDays = getNext7DaysStartingFromToday()
        
        // Helper to build messages
        func buildMessages(limitActivities: Bool) -> [ChatGPTMessage] {
            let conciseNote = limitActivities
            ? "- If output is too long, reduce to max 1 sentence per activity while keeping clarity.\n"
            : ""
            let systemContent = """
                Barkley: Create a 7-day training plan starting from TODAY.

                LANGUAGE: \(languageInstruction)

                Requirements:
                - Start from today, not Monday
                - Address dog's specific needs
                - Use \(getTimeFormatDescription()) time format
                - Provide novice-friendly, step-by-step clarity: 2–3 sentences per activity with simple language
                - Decide the number of activities per day dynamically (0–5) based on breed, age, behavior score, and analysis. Do NOT use a fixed default.
                - Include full rest day(s) when beneficial for recovery; on rest days, activities can be empty
                - Vary intensity across the week (hard/moderate/light/rest) and vary activity counts across days (avoid same count every day). Aim for diversity; include at least one day with 1 activity and one day with 4–5 activities when appropriate for the dog.
                - "dayName" values must remain in English exactly as provided (they are a data contract, not display text); translate everything else per the LANGUAGE instruction.
                \(conciseNote)

                JSON format:
                {
                    "weekTitle": "Perfect Training Week for [Dog Name]",
                    "weekGoal": "Primary goal for this week",
                    "days": [
                        {
                            "dayName": "\(weekDays[0])",
                            "theme": "Day theme (e.g., 'Foundation Building')",
                            "isRestDay": false,
                            "activities": [
                                {
                                    "time": "\(getTimeFormat())",
                                    "activity": "Morning Walk",
                                    "duration": "20 minutes",
                                    "focus": "Physical exercise",
                                    "instructions": "2–3 clear, novice-friendly sentences explaining exactly what to do",
                                    "trainingGoal": "What specific behavior/skill to work on"
                                },
                                {
                                    "time": "\(getTimeFormat())",
                                    "activity": "Enrichment Puzzle",
                                    "duration": "15 minutes",
                                    "focus": "Mental stimulation",
                                    "instructions": "2–3 clear, novice-friendly sentences",
                                    "trainingGoal": "Calm focus and problem-solving"
                                },
                                {
                                    "time": "\(getTimeFormat())",
                                    "activity": "Basic Obedience",
                                    "duration": "10 minutes",
                                    "focus": "Training",
                                    "instructions": "2–3 clear, novice-friendly sentences",
                                    "trainingGoal": "Reinforce sit, stay, recall"
                                }
                            ],
                            "dailyGoal": "What to achieve today",
                            "successMetrics": ["How to measure success", "Backup plan if struggling"]
                        }
                    ],
                    "weeklyTips": ["Tip 1", "Tip 2", "Tip 3"],
                    "troubleshooting": {
                        "commonIssues": ["Issue 1", "Issue 2"],
                        "solutions": ["Solution 1", "Solution 2"]
                    }
                }
                """
            var msgs: [ChatGPTMessage] = [
                ChatGPTMessage(role: "system", content: systemContent),
                ChatGPTMessage(role: "user", content: createSuggestedTrainingWeekPrompt(dog: dog, analysis: analysis))
            ]
            if let catalog = exerciseCatalogSummary, !catalog.isEmpty {
                msgs.append(
                    ChatGPTMessage(
                        role: "user",
                        content: """
                        EXERCISE CATALOG (prefer favorites; use these first, invent only if necessary):
                        \n
                        \(catalog)
                        """
                    )
                )
            }
            return msgs
        }

        // Helper to perform the request with a given token limit
        func performRequest(maxTokens: Int, limitActivities: Bool) async throws -> SuggestedTrainingWeek {
            let requestBody = ChatGPTRequest(
                model: "gpt-4o-mini",
                messages: buildMessages(limitActivities: limitActivities),
                temperature: 0.4,
                maxTokens: maxTokens
            )
            let url = URL(string: baseURL)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatGPTError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 { throw ChatGPTError.invalidAPIKey }
                if httpResponse.statusCode == 429 {
                    throw Self.isInsufficientQuota(data) ? ChatGPTError.insufficientQuota : ChatGPTError.rateLimitExceeded
                }
                throw ChatGPTError.apiError("HTTP \(httpResponse.statusCode)")
            }
            let chatGPTResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
            guard let content = chatGPTResponse.choices.first?.message.content else {
                throw ChatGPTError.invalidResponse
            }
            return try parseSuggestedTrainingWeekResponse(content)
        }

        // First attempt
        do {
            return try await performRequest(maxTokens: 7000, limitActivities: false)
        } catch ChatGPTError.tokenLimit, ChatGPTError.parsingError {
            DogLogLogger.ai.warning("First attempt failed due to size/parsing; retrying with higher max tokens")
            // Retry with higher limit and explicit brevity to reduce output size
            return try await performRequest(maxTokens: 9000, limitActivities: true)
        }
    }
    
    private func createSuggestedTrainingWeekPrompt(dog: Dog, analysis: ChatGPTAnalysis) -> String {
        let dogName = dog.name ?? "dog.unknown_name".localized
        let breed = dog.breed ?? "dog.unknown_breed".localized
        
        let trainingFocus = analysis.trainingRecommendations.map { rec in
            "• \(rec.issue): Use \(rec.technique) - \(rec.steps.joined(separator: ", "))"
        }.joined(separator: "\n")
        
        // Get the next 7 days starting from today
        let weekDays = getNext7DaysStartingFromToday()
        let dayList = weekDays.joined(separator: ", ")
        
        return """
        Create a perfect training week for \(dogName), a \(breed).
        
        IMPORTANT: Start the week from TODAY (\(weekDays.first!)) and continue for 7 days in this order: \(dayList)
        
        TRAINING PRIORITIES FROM ANALYSIS:
        \(trainingFocus.isEmpty ? "training.general_enrichment".localized : trainingFocus)
        
        BREED CONSIDERATIONS:
        Exercise needs: \(analysis.breedAnalysis.exerciseNeeds)
        Mental stimulation: \(analysis.breedAnalysis.mentalStimulationNeeds)
        Common breed issues: \(analysis.breedAnalysis.commonIssues.joined(separator: ", "))
        
        AGE STAGE: \(analysis.ageConsiderations.developmentalStage)
        Training readiness: \(analysis.ageConsiderations.trainingReadiness)
        
        CURRENT BEHAVIOR SCORE: \(analysis.behaviorAssessment.overallScore)/100
        Progress trend: \(analysis.behaviorAssessment.progressTrend)
        
        Plan requirements:
        - Decide activities per day dynamically (0–5) based on the above; avoid any fixed default counts
        - Include full rest day(s) when appropriate; on rest days, set isRestDay=true and activities=[]
        - Balance intensity across days (hard/moderate/light/rest)
        - Keep each activity instruction to one concise sentence
        
        Please create a 7-day plan that addresses these needs and goals. Make it practical for a busy dog owner while ensuring effective training progress. Start from \(weekDays.first!) (today) and follow the exact day sequence provided above.
        """
    }
    
    private func parseSuggestedTrainingWeekResponse(_ content: String) throws -> SuggestedTrainingWeek {
        #if DEBUG
        DogLogLogger.ai.debug("ChatGPT training-week response received (\(content.count) chars)")
        #endif
        
        // Extract JSON from the response (in case ChatGPT adds extra text)
        let jsonStart = content.firstIndex(of: "{") ?? content.startIndex
        let jsonEnd = content.lastIndex(of: "}") ?? content.endIndex
        let jsonString = String(content[jsonStart...jsonEnd])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            DogLogLogger.ai.error("Failed to convert training-week JSON string to Data")
            throw ChatGPTError.parsingError
        }
        
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(SuggestedTrainingWeek.self, from: jsonData)
            DogLogLogger.ai.info("Successfully parsed SuggestedTrainingWeek")
            return result
        } catch {
            DogLogLogger.ai.error("Training-week JSON decoding failed: \(error.localizedDescription, privacy: .public)")
            throw ChatGPTError.parsingError
        }
    }
    
    private func getTimeFormat() -> String {
        if uses12HourClock() {
            return "7:00 AM"
        } else {
            return "07:00"
        }
    }
    
    private func getTimeFormatDescription() -> String {
        if uses12HourClock() {
            return "12-hour (e.g., '7:00 AM', '2:30 PM')"
        } else {
            return "24-hour (e.g., '07:00', '14:30')"
        }
    }

    // MARK: - Exercise Catalog Fetch
    struct TrainingExerciseDTO: Codable {
        let name: String
        let category: String?
        let difficulty: String?
        let equipment: String?
        let instructions: String
        let tags: [String]?
        let source: String?
    }

    func fetchExerciseCatalog(dog: Dog, analysis: ChatGPTAnalysis?) async throws -> [TrainingExerciseDTO] {
        guard hasValidAPIKey, let apiKey = apiKey else {
            throw ChatGPTError.missingAPIKey
        }
        setLoading(true)
        defer { setLoading(false) }

        let languageInstruction = LocalizationManager.shared.getChatGPTLanguageInstruction()
        let breed = dog.breed ?? "dog.unknown_breed".localized
        let behaviorScore = analysis?.behaviorAssessment.overallScore

        let systemPrompt = """
        You are Barkley, expert dog behaviorist and trainer.
        LANGUAGE: \(languageInstruction)
        Task: Provide a library of 12–20 high-quality dog training exercises suitable for a broad range of breeds and ages.
        Each exercise should be actionable and safe for novice owners.
        Output JSON ONLY (array) with objects: {"name","category","difficulty","equipment","instructions","tags","source"}.
        """

        let userPrompt = """
        Please include a mix of obedience, enrichment, impulse control, engagement, recall, calmness, and leash skills.
        Keep instructions clear, 2–4 sentences and novice-friendly.
        Consider breed: \(breed). \(behaviorScore != nil ? "Behavior score: \(behaviorScore!)." : "")
        JSON only.
        """

        let content: String
        if UserDefaults.standard.bool(forKey: Self.webSearchExercisesKey) {
            content = try await fetchExerciseContentViaWebSearch(
                apiKey: apiKey, systemPrompt: systemPrompt, userPrompt: userPrompt
            )
        } else {
            content = try await fetchExerciseContentViaChatCompletions(
                apiKey: apiKey, systemPrompt: systemPrompt, userPrompt: userPrompt
            )
        }

        let jsonStart = content.firstIndex(of: "[") ?? content.startIndex
        let jsonEnd = content.lastIndex(of: "]") ?? content.endIndex
        let json = String(content[jsonStart...jsonEnd])
        guard let jsonData = json.data(using: .utf8) else { throw ChatGPTError.parsingError }
        let list = try JSONDecoder().decode([TrainingExerciseDTO].self, from: jsonData)
        UserDefaults.standard.set(Date(), forKey: ExerciseLibraryRefresher.lastFetchDateKey)
        return list
    }

    /// Default path: plain chat completions. No internet access — the model
    /// generates exercises from its training knowledge.
    private func fetchExerciseContentViaChatCompletions(apiKey: String, systemPrompt: String, userPrompt: String) async throws -> String {
        let requestBody = ChatGPTRequest(
            model: "gpt-4o-mini",
            messages: [
                ChatGPTMessage(role: "system", content: systemPrompt),
                ChatGPTMessage(role: "user", content: userPrompt),
            ],
            temperature: 0.4,
            maxTokens: 2500
        )

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ChatGPTError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        let chatGPTResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
        guard let content = chatGPTResponse.choices.first?.message.content else {
            throw ChatGPTError.invalidResponse
        }
        return content
    }

    // MARK: Responses API (web search)

    private struct ResponsesRequest: Codable {
        struct Tool: Codable {
            let type: String
        }
        let model: String
        let instructions: String
        let input: String
        let tools: [Tool]
    }

    private struct ResponsesResponse: Codable {
        struct OutputItem: Codable {
            struct ContentItem: Codable {
                let type: String
                let text: String?
            }
            let type: String
            let content: [ContentItem]?
        }
        let output: [OutputItem]
    }

    /// Opt-in path (Settings → "Use web search for exercises"): OpenAI
    /// Responses API with the hosted web_search tool, so the exercises can
    /// draw on current web content. Same JSON-array output contract.
    private func fetchExerciseContentViaWebSearch(apiKey: String, systemPrompt: String, userPrompt: String) async throws -> String {
        let requestBody = ResponsesRequest(
            model: "gpt-4o-mini",
            instructions: systemPrompt + "\nUse the web_search tool to ground the exercises in current, reputable dog-training sources.",
            input: userPrompt,
            tools: [ResponsesRequest.Tool(type: "web_search")]
        )

        var request = URLRequest(url: URL(string: provider.responsesURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ChatGPTError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        let decoded = try JSONDecoder().decode(ResponsesResponse.self, from: data)
        // The output array holds web_search_call items plus one assistant
        // "message" item whose content carries the output_text.
        let text = decoded.output
            .filter { $0.type == "message" }
            .compactMap { $0.content?.first(where: { $0.type == "output_text" })?.text }
            .first
        guard let text = text else {
            throw ChatGPTError.invalidResponse
        }
        return text
    }
    
    private func uses12HourClock() -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.timeStyle = .short
        
        let sampleTime = Date()
        let formattedTime = dateFormatter.string(from: sampleTime)
        
        return formattedTime.uppercased().contains("AM") || 
               formattedTime.uppercased().contains("PM") ||
               formattedTime.contains("上午") || // Chinese AM
               formattedTime.contains("下午")    // Chinese PM
    }
    
    private func getNext7DaysStartingFromToday() -> [String] {
        let calendar = Calendar.current
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        dateFormatter.locale = Locale(identifier: "en_US")
        
        var weekDays: [String] = []
        for i in 0..<7 {
            if let futureDate = calendar.date(byAdding: .day, value: i, to: today) {
                let dayName = dateFormatter.string(from: futureDate)
                weekDays.append(dayName)
            }
        }
        
        return weekDays
    }
    
    // MARK: - Data Preparation
    private func prepareDataSummary(dog: Dog, timeRange: AIPatternAnalyzer.AnalysisTimeRange, localInsights: AIPatternAnalyzer.DogInsights) -> String {
        let timeRangeText = timeRange.displayName
        let dogName = dog.name ?? "dog.unknown_name".localized
        let breed = dog.breed ?? "dog.unknown_breed".localized
        let gender = dog.gender ?? "dog.unknown".localized
        
        // Calculate age with more detail
        let ageInfo: String
        if let birthDate = dog.dateOfBirth {
            let components = Calendar.current.dateComponents([.year, .month], from: birthDate, to: Date())
            let years = components.year ?? 0
            let months = components.month ?? 0
            
            if years == 0 {
                ageInfo = "\(months) months old (Puppy)"
            } else if years < 2 {
                ageInfo = "\(years) year(s) \(months) month(s) old (Young Adult)"
            } else if years < 7 {
                ageInfo = "\(years) years old (Adult)"
            } else {
                ageInfo = "\(years) years old (Senior)"
            }
        } else {
            ageInfo = "dog.age_unknown".localized
        }
        
        // Get filtered activities and ratings for the time range
        let filteredActivities = filterActivitiesForSummary(dog.activities, timeRange: timeRange)
        let filteredRatings = filterRatingsForSummary(dog.dailyRatings, timeRange: timeRange)
        
        // Activity summary with notes
        let activityDetails = localInsights.activityPatterns.map { pattern in
            let patternActivities = filteredActivities.filter { $0.activityType == pattern.activityType }
            let notesWithContent = patternActivities.compactMap { $0.notes }.filter { !$0.isEmpty }
            let notesText = notesWithContent.isEmpty ? "" : " | Recent notes: \(notesWithContent.suffix(3).joined(separator: "; "))"
            
            let name = ActivityCatalog.shared.displayName(forStoredType: pattern.activityType)
            return "\(name): \(pattern.frequency)x/week, \(Int(pattern.successRate * 100))% success rate\(notesText)"
        }.joined(separator: "\n")
        
        // Daily rating notes
        let ratingNotes = filteredRatings
            .compactMap { $0.notes }
            .filter { !$0.isEmpty }
            .suffix(5)
            .joined(separator: "\n• ")
        
        // Mood summary
        let moodSummary = """
        Current mood: \(localInsights.overallMood.current)
        Trend: \(localInsights.overallMood.direction == .up ? "ai.improving".localized : localInsights.overallMood.direction == .down ? "ai.declining".localized : "ai.stable".localized)
        Improvement: \(Int(localInsights.overallMood.improvement.isFinite ? localInsights.overallMood.improvement : 0))%
        Consistency: \(Int(localInsights.overallMood.consistency * 100))%
        """
        
        // Weekly patterns
        let weeklyPattern = """
        Best days: \(localInsights.weeklyTrends.bestDays.joined(separator: ", "))
        Average activities per day: \(String(format: "%.1f", localInsights.weeklyTrends.averageActivitiesPerDay))
        """
        
        // Recent behavioral observations
        let recentObservations = ratingNotes.isEmpty ? "ai.no_recent_notes".localized : "• \(ratingNotes)"
        
        return """
        🐕 DOG PROFILE:
        Name: \(dogName)
        Breed: \(breed) (Please analyze breed-specific traits and needs)
        Age: \(ageInfo) (Please consider age-appropriate expectations)
        Gender: \(gender)
        Analysis Period: \(timeRangeText)
        
        📊 ACTIVITY PATTERNS:
        \(activityDetails.isEmpty ? "ai.no_activities_logged".localized : activityDetails)
        
        😊 MOOD & BEHAVIOR TRENDS:
        \(moodSummary)
        
        📝 RECENT OWNER OBSERVATIONS:
        \(recentObservations)
        
        📅 WEEKLY PATTERNS:
        \(weeklyPattern)
        
        🔍 LOCAL AI INSIGHTS:
        \(localInsights.behaviorInsights.map { "• \($0.description)" }.joined(separator: "\n"))
        
        📈 DATA CONFIDENCE: \(Int(localInsights.confidence * 100))%
        
        📆 DAILY TIMELINE (oldest first, one line per day):
        \(buildDailyTimeline(activities: filteredActivities, ratings: filteredRatings))
        
        🔁 LOCALLY DETECTED LAGGED PATTERNS (on-device counting, validate or refute these):
        \(buildLaggedPatternsSummary(dog: dog))
        
        EXPERT ANALYSIS REQUEST:
        Barkley, please provide your professional behaviorist analysis for \(dogName), a \(breed). Focus on:
        1. Breed-specific behavioral assessment and training needs
        2. Age-appropriate expectations and development stage
        3. Specific training techniques for any identified issues
        4. Detailed step-by-step training protocols
        5. Exercise and mental stimulation recommendations
        
        Please be as specific and actionable as possible with your recommendations.
        """
    }
    
    /// One compact line per logged day, oldest first, capped at the most recent
    /// ~120 rated days, with gap markers for unlogged stretches. This is what
    /// lets the model see day-to-day sequences (lagged effects).
    private func buildDailyTimeline(activities: [Activity], ratings: [DailyRating], maxRatedDays: Int = 120) -> String {
        let calendar = Calendar.current
        
        var ratingByDay: [Date: DailyRating] = [:]
        for rating in ratings {
            ratingByDay[calendar.startOfDay(for: rating.date)] = rating
        }
        var activitiesByDay: [Date: [Activity]] = [:]
        for activity in activities {
            activitiesByDay[calendar.startOfDay(for: activity.date), default: []].append(activity)
        }
        
        let loggedDays = Set(ratingByDay.keys).union(activitiesByDay.keys).sorted()
        guard !loggedDays.isEmpty else { return "(no logged days)" }
        
        // Cap to the window containing the most recent `maxRatedDays` rated days.
        let ratedDaysSorted = ratingByDay.keys.sorted()
        let windowStart = ratedDaysSorted.count > maxRatedDays
            ? ratedDaysSorted[ratedDaysSorted.count - maxRatedDays]
            : loggedDays[0]
        let days = loggedDays.filter { $0 >= windowStart }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd EEE"
        
        var lines: [String] = []
        var previousDay: Date?
        
        for day in days {
            if let previous = previousDay,
               let gap = calendar.dateComponents([.day], from: previous, to: day).day,
               gap > 1 {
                lines.append("--- \(gap - 1) day(s) not logged ---")
            }
            previousDay = day
            
            let dayRating = ratingByDay[day]?.rating ?? "unrated"
            var line = "\(dateFormatter.string(from: day)) [DAY: \(dayRating)] "
            
            let dayActivities = activitiesByDay[day] ?? []
            if dayActivities.isEmpty {
                line += "rest day"
            } else {
                line += dayActivities
                    .map { "\($0.displayName)(\($0.outcome))" }
                    .joined(separator: ", ")
            }
            
            // Context tags are confounds (thunder, heat cycle, ...) — surface
            // them so the model doesn't blame an activity for a bad day.
            if let tags = ratingByDay[day]?.contextTags, !tags.isEmpty {
                let shortNames = tags.map { $0.replacingOccurrences(of: "context.", with: "") }
                line += " [tags: \(shortNames.joined(separator: ", "))]"
            }
            
            let note = ratingByDay[day]?.notes
                ?? dayActivities.compactMap { $0.notes }.first
            if let note = note, !note.isEmpty {
                line += " | note: \"\(String(note.prefix(80)))\""
            }
            
            lines.append(line)
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Output of the on-device lagged pattern analyzer, for the model to
    /// validate or refute.
    private func buildLaggedPatternsSummary(dog: Dog) -> String {
        let patterns = LaggedPatternAnalyzer().analyze(dog: dog)
        guard !patterns.isEmpty else { return "(none detected yet)" }
        
        return patterns.map { pattern in
            let rate = pattern.direction == .negative ? pattern.badRate : pattern.goodRate
            let baseline = pattern.direction == .negative ? pattern.baselineBadRate : pattern.baselineGoodRate
            let outcome = pattern.direction == .negative ? "bad" : "good"
            return "• After \(pattern.displayName) (lag \(pattern.lagDays) day(s)): "
                + "\(Int((rate * 100).rounded()))% of days were \(outcome) "
                + "(baseline \(Int((baseline * 100).rounded()))%, n=\(pattern.sampleCount))"
        }.joined(separator: "\n")
    }
    
    private func filterActivitiesForSummary(_ activities: [Activity], timeRange: AIPatternAnalyzer.AnalysisTimeRange) -> [Activity] {
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
    
    private func filterRatingsForSummary(_ ratings: [DailyRating], timeRange: AIPatternAnalyzer.AnalysisTimeRange) -> [DailyRating] {
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
    
    // MARK: - Response Parsing
    private func parseChatGPTResponse(_ content: String) throws -> ChatGPTAnalysis {
        // Extract JSON from the response (in case ChatGPT adds extra text)
        let jsonStart = content.firstIndex(of: "{") ?? content.startIndex
        let jsonEnd = content.lastIndex(of: "}") ?? content.endIndex
        let jsonString = String(content[jsonStart...jsonEnd])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ChatGPTError.parsingError
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ChatGPTAnalysis.self, from: jsonData)
    }
    
    // MARK: - Caching System
    private func generateCacheKey(dogId: UUID, timeRange: AIPatternAnalyzer.AnalysisTimeRange) -> String {
        switch timeRange {
        case .allTime:
            return "chatgpt_\(dogId)_alltime"
        case .thisMonth(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return "chatgpt_\(dogId)_\(formatter.string(from: date))"
        }
    }
    
    private func getCachedAnalysis(key: String) -> ChatGPTAnalysis? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let analysis = try? JSONDecoder().decode(ChatGPTAnalysis.self, from: data) else {
            return nil
        }
        
        // Check if cache is still valid (24 hours)
        let cacheAge = Date().timeIntervalSince(analysis.generatedAt)
        guard cacheAge < 24 * 60 * 60 else {
            // Cache expired, remove it
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
        
        return analysis
    }
    
    private func cacheAnalysis(_ analysis: ChatGPTAnalysis, key: String) {
        if let data = try? JSONEncoder().encode(analysis) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // MARK: - Cache Management
    func invalidateCache(for dogId: UUID) {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        
        // Remove all cached analyses and training weeks for this dog
        for key in allKeys {
            if key.contains("chatgpt_\(dogId)") || key.contains("suggested_training_week_\(dogId)") {
                defaults.removeObject(forKey: key)
                DogLogLogger.ai.debug("Invalidated cache key: \(key, privacy: .public)")
            }
        }
        TrainingWeekCache.removeLanguage(dogId: dogId)

        // Mark that a refreshed Suggested Training Week is recommended
        let regenKey = TrainingWeekCache.regenKey(dogId: dogId)
        defaults.set(true, forKey: regenKey)
        DogLogLogger.ai.info("Set regeneration flag for training week")
    }
    
    func hasCachedAnalysis(dogId: UUID, timeRange: AIPatternAnalyzer.AnalysisTimeRange) -> Bool {
        let key = generateCacheKey(dogId: dogId, timeRange: timeRange)
        return getCachedAnalysis(key: key) != nil
    }
}

// MARK: - Data Models
struct ChatGPTRequest: Codable {
    let model: String
    let messages: [ChatGPTMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct ChatGPTMessage: Codable {
    let role: String
    let content: String
}

struct ChatGPTResponse: Codable {
    let choices: [ChatGPTChoice]
}

struct ChatGPTChoice: Codable {
    let message: ChatGPTMessage
}

struct ChatGPTAnalysis: Codable {
    let summary: String
    let breedAnalysis: BreedAnalysis
    let ageConsiderations: AgeConsiderations
    let behaviorAssessment: BehaviorAssessment
    let trainingRecommendations: [TrainingRecommendation]
    let keyInsights: [String]
    let laggedPatterns: [LaggedPatternDTO]?  // optional so old cached JSON still decodes
    let healthIndicators: HealthIndicators
    let generatedAt: Date
    
    init(summary: String, breedAnalysis: BreedAnalysis, ageConsiderations: AgeConsiderations, behaviorAssessment: BehaviorAssessment, trainingRecommendations: [TrainingRecommendation], keyInsights: [String], laggedPatterns: [LaggedPatternDTO]? = nil, healthIndicators: HealthIndicators, generatedAt: Date) {
        self.summary = summary
        self.breedAnalysis = breedAnalysis
        self.ageConsiderations = ageConsiderations
        self.behaviorAssessment = behaviorAssessment
        self.trainingRecommendations = trainingRecommendations
        self.keyInsights = keyInsights
        self.laggedPatterns = laggedPatterns
        self.healthIndicators = healthIndicators
        self.generatedAt = generatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        breedAnalysis = try container.decode(BreedAnalysis.self, forKey: .breedAnalysis)
        ageConsiderations = try container.decode(AgeConsiderations.self, forKey: .ageConsiderations)
        behaviorAssessment = try container.decode(BehaviorAssessment.self, forKey: .behaviorAssessment)
        trainingRecommendations = try container.decode([TrainingRecommendation].self, forKey: .trainingRecommendations)
        keyInsights = try container.decode([String].self, forKey: .keyInsights)
        laggedPatterns = try container.decodeIfPresent([LaggedPatternDTO].self, forKey: .laggedPatterns)
        healthIndicators = try container.decode(HealthIndicators.self, forKey: .healthIndicators)
        generatedAt = Date() // Set current time when decoding
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(summary, forKey: .summary)
        try container.encode(breedAnalysis, forKey: .breedAnalysis)
        try container.encode(ageConsiderations, forKey: .ageConsiderations)
        try container.encode(behaviorAssessment, forKey: .behaviorAssessment)
        try container.encode(trainingRecommendations, forKey: .trainingRecommendations)
        try container.encode(keyInsights, forKey: .keyInsights)
        try container.encodeIfPresent(laggedPatterns, forKey: .laggedPatterns)
        try container.encode(healthIndicators, forKey: .healthIndicators)
        try container.encode(generatedAt, forKey: .generatedAt)
    }
    
    enum CodingKeys: CodingKey {
        case summary, breedAnalysis, ageConsiderations, behaviorAssessment, trainingRecommendations, keyInsights, laggedPatterns, healthIndicators, generatedAt
    }
}

struct LaggedPatternDTO: Codable {
    let cause: String
    let effect: String
    let evidence: String
    let recommendation: String
}

struct ChatGPTRecommendation: Codable {
    let title: String
    let description: String
    let priority: String
    let timeframe: String
}

struct BreedAnalysis: Codable {
    let breedTraits: [String]
    let exerciseNeeds: String
    let mentalStimulationNeeds: String
    let commonIssues: [String]
}

struct AgeConsiderations: Codable {
    let developmentalStage: String
    let ageAppropriateExpectations: String
    let trainingReadiness: String
}

struct TrainingRecommendation: Codable {
    let issue: String
    let technique: String
    let steps: [String]
    let duration: String
    let frequency: String
    let priority: String
}

struct BehaviorAssessment: Codable {
    let strengths: [String]
    let concerns: [String]
    let overallScore: Int
    let progressTrend: String
}

struct HealthIndicators: Codable {
    let exerciseLevel: String
    let mentalStimulation: String
    let routineConsistency: String
}

// MARK: - Suggested Training Week Models
struct SuggestedTrainingWeek: Codable {
    let weekTitle: String
    let weekGoal: String
    var days: [TrainingDay]
    let weeklyTips: [String]
    let troubleshooting: Troubleshooting
}

struct TrainingDay: Codable {
    let dayName: String
    let theme: String
    let isRestDay: Bool?
    var activities: [TrainingActivity]
    let dailyGoal: String
    let successMetrics: [String]
}

struct TrainingActivity: Codable, Identifiable {
    let id = UUID()
    var time: String
    var activity: String
    var duration: String
    var focus: String
    var instructions: String
    var trainingGoal: String
    
    init(time: String, activity: String, duration: String, focus: String, instructions: String, trainingGoal: String) {
        self.time = time
        self.activity = activity
        self.duration = duration
        self.focus = focus
        self.instructions = instructions
        self.trainingGoal = trainingGoal
    }
    
    private enum CodingKeys: String, CodingKey {
        case time, activity, duration, focus, instructions, trainingGoal
    }
}

struct Troubleshooting: Codable {
    let commonIssues: [String]
    let solutions: [String]
}

// MARK: - Errors
enum ChatGPTError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimitExceeded
    case insufficientQuota
    case apiError(String)
    case invalidResponse
    case parsingError
    case tokenLimit
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "chatgpt.error.missing_api_key".localized
        case .invalidAPIKey:
            return "chatgpt.error.invalid_api_key".localized
        case .rateLimitExceeded:
            return "chatgpt.error.rate_limit_exceeded".localized
        case .insufficientQuota:
            return "chatgpt.error.insufficient_quota".localized
        case .apiError(let message):
            return String(format: "chatgpt.error.api_error".localized, message)
        case .invalidResponse:
            return "chatgpt.error.invalid_response".localized
        case .parsingError:
            return "chatgpt.error.parsing_error".localized
        case .tokenLimit:
            return "chatgpt.error.token_limit".localized
        }
    }
}
// MARK: - Exercise Library Auto-Refresh (task 4b)

/// Lazy, on-foreground refresh of the AI exercise library. No BGTaskScheduler:
/// when the app comes to the foreground we check whether the configured
/// interval has elapsed since the last fetch and, if so, refresh in the
/// background of the session and merge (dedupe by name, favorites untouched).
enum ExerciseLibraryRefresher {
    static let lastFetchDateKey = "last_exercise_fetch_date"
    static let intervalKey = "exercise_refresh_interval"

    enum Interval: String, CaseIterable {
        case manual, weekly, biweekly, monthly

        var days: Int? {
            switch self {
            case .manual: return nil
            case .weekly: return 7
            case .biweekly: return 14
            case .monthly: return 30
            }
        }

        var displayName: String {
            switch self {
            case .manual: return "settings.exercise.refresh.manual".localized
            case .weekly: return "settings.exercise.refresh.weekly".localized
            case .biweekly: return "settings.exercise.refresh.biweekly".localized
            case .monthly: return "settings.exercise.refresh.monthly".localized
            }
        }
    }

    private static var isRefreshing = false

    static func refreshIfDue(context: ModelContext) {
        let defaults = UserDefaults.standard
        let interval = Interval(rawValue: defaults.string(forKey: intervalKey) ?? "") ?? .manual
        guard let intervalDays = interval.days else { return }
        guard ChatGPTService.shared.hasValidAPIKey else { return }
        guard !isRefreshing else { return }

        if let lastFetch = defaults.object(forKey: lastFetchDateKey) as? Date {
            let age = Calendar.current.dateComponents([.day], from: lastFetch, to: Date()).day ?? 0
            guard age >= intervalDays else { return }
        }
        // No recorded fetch yet counts as due.

        isRefreshing = true
        Task { @MainActor in
            defer { isRefreshing = false }
            do {
                let dtos = try await ChatGPTService.shared.fetchExerciseCatalog(dog: Dog(name: "DogLog"), analysis: nil)
                let existing = (try? context.fetch(FetchDescriptor<TrainingExercise>())) ?? []
                let existingNames = Set(existing.map { $0.name.lowercased() })
                for dto in dtos where !existingNames.contains(dto.name.lowercased()) {
                    let exercise = TrainingExercise(
                        name: dto.name,
                        category: dto.category,
                        difficulty: dto.difficulty,
                        equipment: dto.equipment,
                        instructions: dto.instructions,
                        tags: dto.tags ?? [],
                        source: dto.source ?? "chatgpt",
                        isFavorite: false
                    )
                    context.insert(exercise)
                }
                try context.save()
                DogLogLogger.ai.info("ExerciseLibraryRefresher merged \(dtos.count) fetched exercises")
            } catch {
                DogLogLogger.ai.error("ExerciseLibraryRefresher refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

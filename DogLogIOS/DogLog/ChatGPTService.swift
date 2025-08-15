import Foundation
import SwiftData

// MARK: - ChatGPT Service
class ChatGPTService: ObservableObject {
    static let shared = ChatGPTService()
    
    @Published var isLoading = false
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    private init() {}
    
    // MARK: - API Key Management
    var apiKey: String? {
        get {
            return UserDefaults.standard.string(forKey: "ChatGPT_API_Key")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ChatGPT_API_Key")
        }
    }
    
    var hasValidAPIKey: Bool {
        guard let key = apiKey, !key.isEmpty else { return false }
        return key.hasPrefix("sk-") && key.count > 20
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
        
        isLoading = true
        defer { isLoading = false }
        
        // Check cache first
        let cacheKey = generateCacheKey(dogId: dog.id, timeRange: timeRange)
        if let cachedAnalysis = getCachedAnalysis(key: cacheKey) {
            return cachedAnalysis
        }
        
        // Prepare data summary for ChatGPT
        let dataSummary = prepareDataSummary(dog: dog, timeRange: timeRange, localInsights: localInsights)
        
        // Create ChatGPT request
        let messages = [
            ChatGPTMessage(
                role: "system",
                content: """
                You are Dr. Sarah Chen, a world-renowned dog behaviorist with 25+ years of experience specializing in breed-specific behavior, age-appropriate training, and behavioral modification. You've worked with thousands of dogs across all breeds and ages, published research on canine psychology, and are known for your practical, science-based training approaches.

                ANALYSIS APPROACH:
                - Consider breed-specific traits, instincts, and common behavioral patterns
                - Factor in age-appropriate expectations and developmental stages
                - Analyze activity patterns for breed suitability and adequacy
                - Identify training opportunities based on breed characteristics
                - Provide specific, actionable training techniques with examples
                - Consider the dog's individual personality alongside breed tendencies

                TRAINING PHILOSOPHY:
                - Positive reinforcement-based methods
                - Breed-specific exercise and mental stimulation needs
                - Age-appropriate training complexity
                - Consistency and routine importance
                - Early intervention for behavioral concerns

                Provide your response in exactly this JSON format:
                {
                    "summary": "Professional assessment as Dr. Chen would provide",
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
            maxTokens: 1500
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
                throw ChatGPTError.rateLimitExceeded
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
    
    // MARK: - Example Week Generation
    func generateExampleWeek(
        dog: Dog,
        analysis: ChatGPTAnalysis
    ) async throws -> ExampleWeek {
        
        guard hasValidAPIKey, let apiKey = apiKey else {
            throw ChatGPTError.missingAPIKey
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Create ChatGPT request for example week
        let messages = [
            ChatGPTMessage(
                role: "system",
                content: """
                You are Dr. Sarah Chen creating a specific 7-day training plan for this dog. Based on your previous analysis, create a detailed weekly schedule that addresses the training recommendations you provided.

                Create a realistic, actionable weekly training plan that:
                - Addresses the specific training recommendations from your analysis
                - Considers the dog's breed, age, and current behavioral patterns
                - Includes daily activities with specific timing
                - Balances training, exercise, and rest
                - Shows progression throughout the week
                - Includes backup plans for busy days

                Provide your response in exactly this JSON format:
                {
                    "weekTitle": "Perfect Training Week for [Dog Name]",
                    "weekGoal": "Primary goal for this week",
                    "days": [
                        {
                            "dayName": "Monday",
                            "theme": "Day theme (e.g., 'Foundation Building')",
                            "activities": [
                                {
                                    "time": "7:00 AM",
                                    "activity": "Morning Walk",
                                    "duration": "20 minutes",
                                    "focus": "Physical exercise",
                                    "instructions": "Detailed step-by-step instructions",
                                    "trainingGoal": "What specific behavior/skill to work on"
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
            ),
            ChatGPTMessage(
                role: "user",
                content: createExampleWeekPrompt(dog: dog, analysis: analysis)
            )
        ]
        
        let requestBody = ChatGPTRequest(
            model: "gpt-4o-mini",
            messages: messages,
            temperature: 0.4,
            maxTokens: 2000
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
                throw ChatGPTError.rateLimitExceeded
            } else {
                throw ChatGPTError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        let chatGPTResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
        
        guard let content = chatGPTResponse.choices.first?.message.content else {
            throw ChatGPTError.invalidResponse
        }
        
        // Parse the JSON response from ChatGPT
        return try parseExampleWeekResponse(content)
    }
    
    private func createExampleWeekPrompt(dog: Dog, analysis: ChatGPTAnalysis) -> String {
        let dogName = dog.name ?? "Dog"
        let breed = dog.breed ?? "Unknown breed"
        
        let trainingFocus = analysis.trainingRecommendations.map { rec in
            "• \(rec.issue): Use \(rec.technique) - \(rec.steps.joined(separator: ", "))"
        }.joined(separator: "\n")
        
        return """
        Create a perfect training week for \(dogName), a \(breed).
        
        TRAINING PRIORITIES FROM ANALYSIS:
        \(trainingFocus.isEmpty ? "General training and enrichment" : trainingFocus)
        
        BREED CONSIDERATIONS:
        Exercise needs: \(analysis.breedAnalysis.exerciseNeeds)
        Mental stimulation: \(analysis.breedAnalysis.mentalStimulationNeeds)
        Common breed issues: \(analysis.breedAnalysis.commonIssues.joined(separator: ", "))
        
        AGE STAGE: \(analysis.ageConsiderations.developmentalStage)
        Training readiness: \(analysis.ageConsiderations.trainingReadiness)
        
        CURRENT BEHAVIOR SCORE: \(analysis.behaviorAssessment.overallScore)/100
        Progress trend: \(analysis.behaviorAssessment.progressTrend)
        
        Please create a detailed 7-day plan that addresses these specific needs and training goals. Make it practical for a busy dog owner while ensuring effective training progress.
        """
    }
    
    private func parseExampleWeekResponse(_ content: String) throws -> ExampleWeek {
        // Extract JSON from the response (in case ChatGPT adds extra text)
        let jsonStart = content.firstIndex(of: "{") ?? content.startIndex
        let jsonEnd = content.lastIndex(of: "}") ?? content.endIndex
        let jsonString = String(content[jsonStart...jsonEnd])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ChatGPTError.parsingError
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ExampleWeek.self, from: jsonData)
    }
    
    // MARK: - Data Preparation
    private func prepareDataSummary(dog: Dog, timeRange: AIPatternAnalyzer.AnalysisTimeRange, localInsights: AIPatternAnalyzer.DogInsights) -> String {
        let timeRangeText = timeRange.displayName
        let dogName = dog.name ?? "Dog"
        let breed = dog.breed ?? "Unknown breed"
        let gender = dog.gender ?? "Unknown"
        
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
            ageInfo = "Age unknown"
        }
        
        // Get filtered activities and ratings for the time range
        let filteredActivities = filterActivitiesForSummary(dog.activities, timeRange: timeRange)
        let filteredRatings = filterRatingsForSummary(dog.dailyRatings, timeRange: timeRange)
        
        // Activity summary with notes
        let activityDetails = localInsights.activityPatterns.map { pattern in
            let patternActivities = filteredActivities.filter { $0.activityType == pattern.activityType }
            let notesWithContent = patternActivities.compactMap { $0.notes }.filter { !$0.isEmpty }
            let notesText = notesWithContent.isEmpty ? "" : " | Recent notes: \(notesWithContent.suffix(3).joined(separator: "; "))"
            
            return "\(pattern.activityType): \(pattern.frequency)x/week, \(Int(pattern.successRate * 100))% success rate\(notesText)"
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
        Trend: \(localInsights.overallMood.direction == .up ? "Improving" : localInsights.overallMood.direction == .down ? "Declining" : "Stable")
        Improvement: \(Int(localInsights.overallMood.improvement))%
        Consistency: \(Int(localInsights.overallMood.consistency * 100))%
        """
        
        // Weekly patterns
        let weeklyPattern = """
        Best days: \(localInsights.weeklyTrends.bestDays.joined(separator: ", "))
        Average activities per day: \(String(format: "%.1f", localInsights.weeklyTrends.averageActivitiesPerDay))
        """
        
        // Recent behavioral observations
        let recentObservations = ratingNotes.isEmpty ? "No recent notes recorded" : "• \(ratingNotes)"
        
        return """
        🐕 DOG PROFILE:
        Name: \(dogName)
        Breed: \(breed) (Please analyze breed-specific traits and needs)
        Age: \(ageInfo) (Please consider age-appropriate expectations)
        Gender: \(gender)
        Analysis Period: \(timeRangeText)
        
        📊 ACTIVITY PATTERNS:
        \(activityDetails.isEmpty ? "No activities logged" : activityDetails)
        
        😊 MOOD & BEHAVIOR TRENDS:
        \(moodSummary)
        
        📝 RECENT OWNER OBSERVATIONS:
        \(recentObservations)
        
        📅 WEEKLY PATTERNS:
        \(weeklyPattern)
        
        🔍 LOCAL AI INSIGHTS:
        \(localInsights.behaviorInsights.map { "• \($0.description)" }.joined(separator: "\n"))
        
        📈 DATA CONFIDENCE: \(Int(localInsights.confidence * 100))%
        
        EXPERT ANALYSIS REQUEST:
        Dr. Chen, please provide your professional behaviorist analysis for \(dogName), a \(breed). Focus on:
        1. Breed-specific behavioral assessment and training needs
        2. Age-appropriate expectations and development stage
        3. Specific training techniques for any identified issues
        4. Detailed step-by-step training protocols
        5. Exercise and mental stimulation recommendations
        
        Please be as specific and actionable as possible with your recommendations.
        """
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
        
        // Remove all cached analyses for this dog
        for key in allKeys {
            if key.contains("chatgpt_\(dogId)") {
                defaults.removeObject(forKey: key)
            }
        }
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
    let healthIndicators: HealthIndicators
    let generatedAt: Date
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        breedAnalysis = try container.decode(BreedAnalysis.self, forKey: .breedAnalysis)
        ageConsiderations = try container.decode(AgeConsiderations.self, forKey: .ageConsiderations)
        behaviorAssessment = try container.decode(BehaviorAssessment.self, forKey: .behaviorAssessment)
        trainingRecommendations = try container.decode([TrainingRecommendation].self, forKey: .trainingRecommendations)
        keyInsights = try container.decode([String].self, forKey: .keyInsights)
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
        try container.encode(healthIndicators, forKey: .healthIndicators)
        try container.encode(generatedAt, forKey: .generatedAt)
    }
    
    enum CodingKeys: CodingKey {
        case summary, breedAnalysis, ageConsiderations, behaviorAssessment, trainingRecommendations, keyInsights, healthIndicators, generatedAt
    }
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

// MARK: - Example Week Models
struct ExampleWeek: Codable {
    let weekTitle: String
    let weekGoal: String
    let days: [TrainingDay]
    let weeklyTips: [String]
    let troubleshooting: Troubleshooting
}

struct TrainingDay: Codable {
    let dayName: String
    let theme: String
    let activities: [TrainingActivity]
    let dailyGoal: String
    let successMetrics: [String]
}

struct TrainingActivity: Codable {
    let time: String
    let activity: String
    let duration: String
    let focus: String
    let instructions: String
    let trainingGoal: String
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
    case apiError(String)
    case invalidResponse
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "ChatGPT API key is missing. Please add your API key in settings."
        case .invalidAPIKey:
            return "Invalid ChatGPT API key. Please check your API key in settings."
        case .rateLimitExceeded:
            return "ChatGPT rate limit exceeded. Please try again later."
        case .apiError(let message):
            return "ChatGPT API error: \(message)"
        case .invalidResponse:
            return "Invalid response from ChatGPT."
        case .parsingError:
            return "Error parsing ChatGPT response."
        }
    }
}
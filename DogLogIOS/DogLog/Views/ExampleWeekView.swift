import SwiftUI

struct ExampleWeekView: View {
    @Environment(\.dismiss) private var dismiss
    let analysis: ChatGPTAnalysis
    @State private var exampleWeek: ExampleWeek?
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedDay: TrainingDay?
    @State private var showingDayDetail = false
    
    @ObservedObject private var chatGPTService = ChatGPTService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Creating your perfect training week...")
                                .font(.headline)
                            Text("Dr. Chen is designing a personalized 7-day plan")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let exampleWeek = exampleWeek {
                        // Week Title and Goal
                        VStack(spacing: 12) {
                            Text(exampleWeek.weekTitle)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text(exampleWeek.weekGoal)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Days of the Week
                        LazyVStack(spacing: 12) {
                            ForEach(exampleWeek.days, id: \.dayName) { day in
                                TrainingDayCardView(day: day) {
                                    selectedDay = day
                                    showingDayDetail = true
                                }
                            }
                        }
                        
                        // Weekly Tips
                        if !exampleWeek.weeklyTips.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("📝 Weekly Tips")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                ForEach(exampleWeek.weeklyTips, id: \.self) { tip in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("💡")
                                        Text(tip)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGroupedBackground))
                            .cornerRadius(12)
                        }
                        
                        // Troubleshooting
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🚨 Troubleshooting")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if !exampleWeek.troubleshooting.commonIssues.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Common Issues:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)
                                    
                                    ForEach(Array(exampleWeek.troubleshooting.commonIssues.enumerated()), id: \.offset) { index, issue in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("⚠️")
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(issue)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                if index < exampleWeek.troubleshooting.solutions.count {
                                                    Text("💡 \(exampleWeek.troubleshooting.solutions[index])")
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                        .italic()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(12)
                        
                    } else if let error = error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            
                            Text("Unable to Generate Week")
                                .font(.headline)
                            
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Try Again") {
                                generateExampleWeek()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(.blue)
                            
                            Text("Perfect Training Week")
                                .font(.headline)
                            
                            Text("Get a personalized 7-day training plan designed by Dr. Chen based on your dog's specific needs and analysis.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Generate Training Week") {
                                generateExampleWeek()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding()
            }
            .navigationTitle("Example Training Week")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDayDetail) {
            if let selectedDay = selectedDay {
                TrainingDayDetailView(day: selectedDay)
            }
        }
    }
    
    private func generateExampleWeek() {
        isLoading = true
        error = nil
        
        // Find the dog from the analysis - we'll need to pass it differently
        // For now, we'll create a mock dog or pass it from the parent view
        guard let mockDog = createMockDogFromAnalysis() else {
            error = "Unable to generate week - missing dog information"
            isLoading = false
            return
        }
        
        Task {
            do {
                let week = try await chatGPTService.generateExampleWeek(
                    dog: mockDog,
                    analysis: analysis
                )
                
                await MainActor.run {
                    exampleWeek = week
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func createMockDogFromAnalysis() -> Dog? {
        // This is a temporary solution - ideally we'd pass the actual dog
        let dog = Dog(name: "Dog")
        dog.breed = "Unknown" // We could extract this from analysis if needed
        return dog
    }
}

// MARK: - Training Day Card View
struct TrainingDayCardView: View {
    let day: TrainingDay
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(day.dayName)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(day.theme)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundColor(.blue)
            }
            
            Text(day.dailyGoal)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Activity count
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                Text("\(day.activities.count) activities planned")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Training Day Detail View
struct TrainingDayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let day: TrainingDay
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Day Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(day.dayName)
                                .font(.title)
                                .fontWeight(.bold)
                            Spacer()
                            Text(day.theme)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.blue)
                        }
                        
                        Text(day.dailyGoal)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Activities
                    VStack(alignment: .leading, spacing: 12) {
                        Text("📅 Daily Schedule")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(day.activities, id: \.time) { activity in
                            TrainingActivityView(activity: activity)
                        }
                    }
                    
                    // Success Metrics
                    if !day.successMetrics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("✅ Success Metrics")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(day.successMetrics, id: \.self) { metric in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text(metric)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle(day.dayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Training Activity View
struct TrainingActivityView: View {
    let activity: TrainingActivity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(activity.time)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundColor(.green)
                
                Text(activity.activity)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(activity.duration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Focus: \(activity.focus)")
                .font(.caption)
                .foregroundColor(.blue)
                .italic()
            
            Text("Goal: \(activity.trainingGoal)")
                .font(.caption)
                .foregroundColor(.purple)
                .italic()
            
            Text(activity.instructions)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ExampleWeekView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock analysis for preview
        let mockAnalysis = ChatGPTAnalysis(
            summary: "Sample analysis",
            breedAnalysis: BreedAnalysis(
                breedTraits: ["Sample trait"],
                exerciseNeeds: "High",
                mentalStimulationNeeds: "High",
                commonIssues: ["Sample issue"]
            ),
            ageConsiderations: AgeConsiderations(
                developmentalStage: "adult",
                ageAppropriateExpectations: "Sample expectations",
                trainingReadiness: "High"
            ),
            behaviorAssessment: BehaviorAssessment(
                strengths: ["Sample strength"],
                concerns: ["Sample concern"],
                overallScore: 85,
                progressTrend: "improving"
            ),
            trainingRecommendations: [],
            keyInsights: ["Sample insight"],
            healthIndicators: HealthIndicators(
                exerciseLevel: "good",
                mentalStimulation: "good",
                routineConsistency: "good"
            ),
            generatedAt: Date()
        )
        
        ExampleWeekView(analysis: mockAnalysis)
    }
}
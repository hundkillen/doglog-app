import SwiftUI

struct ChatGPTSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var chatGPTService = ChatGPTService.shared
    @State private var apiKey: String = ""
    @State private var showingTestResult = false
    @State private var testResultMessage = ""
    @State private var isTestingAPI = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ChatGPT API Key")
                            .font(.headline)
                        
                        Text("Enter your OpenAI API key to enable AI-powered insights")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("sk-...", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if chatGPTService.hasValidAPIKey {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("API key configured")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                } header: {
                    Text("API Configuration")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to get your API key:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Visit platform.openai.com")
                            Text("2. Sign in or create an account")
                            Text("3. Go to API Keys section")
                            Text("4. Create a new secret key")
                            Text("5. Copy and paste it above")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Text("⚠️ Your API key is stored securely on your device and never shared.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 8)
                    }
                } header: {
                    Text("Getting Started")
                }
                
                if !apiKey.isEmpty {
                    Section {
                        Button(action: testAPIKey) {
                            HStack {
                                if isTestingAPI {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                }
                                Text("Test API Key")
                            }
                        }
                        .disabled(isTestingAPI || apiKey.isEmpty)
                    } header: {
                        Text("Test Connection")
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Token Usage")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("ChatGPT analysis uses approximately 1,000-1,500 tokens per request. Requests are cached to minimize usage - you'll only be charged when new data is analyzed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Cache is automatically invalidated when you add new activities or ratings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Cost Information")
                }
            }
            .navigationTitle("ChatGPT Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
        }
        .onAppear {
            apiKey = chatGPTService.apiKey ?? ""
        }
        .alert("API Test Result", isPresented: $showingTestResult) {
            Button("OK") { }
        } message: {
            Text(testResultMessage)
        }
    }
    
    private func saveAPIKey() {
        chatGPTService.apiKey = apiKey.isEmpty ? nil : apiKey
        dismiss()
    }
    
    private func testAPIKey() {
        isTestingAPI = true
        
        Task {
            do {
                let testMessages = [
                    ChatGPTMessage(role: "system", content: "You are a helpful assistant. Respond with exactly 'API test successful' if you receive this message."),
                    ChatGPTMessage(role: "user", content: "Test connection")
                ]
                
                let requestBody = ChatGPTRequest(
                    model: "gpt-4o-mini",
                    messages: testMessages,
                    temperature: 0.0,
                    maxTokens: 50
                )
                
                guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
                    throw ChatGPTError.invalidResponse
                }
                
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
                
                await MainActor.run {
                    isTestingAPI = false
                    
                    if httpResponse.statusCode == 200 {
                        testResultMessage = "✅ API key is valid and working!"
                    } else {
                        testResultMessage = "❌ API key test failed. Please check your key and try again."
                    }
                    
                    showingTestResult = true
                }
                
            } catch {
                await MainActor.run {
                    isTestingAPI = false
                    testResultMessage = "❌ Test failed: \(error.localizedDescription)"
                    showingTestResult = true
                }
            }
        }
    }
}

struct ChatGPTSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatGPTSettingsView()
    }
}
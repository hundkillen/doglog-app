import SwiftUI

struct ChatGPTSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var chatGPTService = ChatGPTService.shared
    @State private var apiKey: String = ""
    @State private var showingTestResult = false
    @State private var testResultMessage = ""
    @State private var isTestingAPI = false
    @State private var showingSaveSuccess = false
    @State private var hasUnsavedChanges = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("chatgpt.api_key_section".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("chatgpt.enter_api_key".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        SecureField("sk-...", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isTextFieldFocused)
                            .onChange(of: apiKey) { _, newValue in
                                hasUnsavedChanges = newValue != (chatGPTService.apiKey ?? "")
                            }
                        
                        if chatGPTService.hasValidAPIKey {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("chatgpt.api_key_configured".localized)
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                } header: {
                    Text("chatgpt.api_configuration".localized)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("chatgpt.how_to_get_key".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("chatgpt.step_1".localized)
                            Text("chatgpt.step_2".localized)
                            Text("chatgpt.step_3".localized)
                            Text("chatgpt.step_4".localized)
                            Text("chatgpt.step_5".localized)
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        
                        Text("chatgpt.security_note".localized)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.top, 8)
                    }
                } header: {
                    Text("chatgpt.getting_started".localized)
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
                                Text("chatgpt.test_api_key".localized)
                            }
                        }
                        .disabled(isTestingAPI || apiKey.isEmpty)
                    } header: {
                        Text("chatgpt.test_connection".localized)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("chatgpt.token_usage".localized)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("chatgpt.token_description".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("chatgpt.cache_note".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("chatgpt.cost_information".localized)
                }
            }
            .navigationTitle("chatgpt.settings_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                }
            })
        }
        .onAppear {
            apiKey = chatGPTService.apiKey ?? ""
        }
        .alert("chatgpt.api_test_result".localized, isPresented: $showingTestResult) {
            Button("common.ok".localized) { }
        } message: {
            Text(testResultMessage)
        }
        .alert("chatgpt.settings_saved".localized, isPresented: $showingSaveSuccess) {
            Button("common.ok".localized) { }
        } message: {
            Text("chatgpt.api_key_saved".localized)
        }
    }
    
    private func saveAPIKey() {
        // Dismiss keyboard first
        isTextFieldFocused = false
        
        chatGPTService.apiKey = apiKey.isEmpty ? nil : apiKey
        hasUnsavedChanges = false
        
        // Show success feedback
        showingSaveSuccess = true
        
        // Post notification to update AI source selection
        NotificationCenter.default.post(name: .chatGPTAPIKeyChanged, object: nil)
        
        // Auto-dismiss after showing success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if !hasUnsavedChanges {
                dismiss()
            }
        }
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
                        testResultMessage = "chatgpt.api_test_success".localized
                    } else {
                        testResultMessage = "chatgpt.api_test_failed".localized
                    }
                    
                    showingTestResult = true
                }
                
            } catch {
                await MainActor.run {
                    isTestingAPI = false
                    testResultMessage = String(format: "chatgpt.api_test_error".localized, error.localizedDescription)
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
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingChatGPTSettings = false
    @State private var showingNotificationSettings = false
    @State private var showingExerciseLibrary = false
    @State private var showingLanguageSelector = false
    @AppStorage(ChatGPTService.webSearchExercisesKey) private var useWebSearchForExercises = false
    @AppStorage(ExerciseLibraryRefresher.intervalKey) private var exerciseRefreshInterval = ExerciseLibraryRefresher.Interval.manual.rawValue
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @ObservedObject private var chatGPTService = ChatGPTService.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                // Notifications Section
                Section {
                    Button(action: { showingNotificationSettings = true }) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings.notifications".localized)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                let statusText: String = {
                                    if !notificationManager.hasPermission { return "common.disabled".localized }
                                    return notificationManager.morningForecastEnabled ? "common.enabled".localized : "common.disabled".localized
                                }()
                                Text(statusText)
                                    .font(.caption)
                                    .foregroundColor(notificationManager.hasPermission && notificationManager.morningForecastEnabled ? .green : .secondary)
                            }
                            
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                } header: {
                    Text("settings.notifications".localized)
                }
                // Language Section
                Section {
                    LanguageSettingsRowView()
                } header: {
                    Text("settings.language".localized)
                }
                
                // ChatGPT Section
                Section {
                    Button(action: {
                        showingChatGPTSettings = true
                    }) {
                        HStack {
                            Image(systemName: "brain.filled.head.profile")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings.chatgpt".localized)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text(chatGPTService.hasValidAPIKey ? 
                                     "settings.connection_success".localized : 
                                     "settings.api_key".localized)
                                    .font(.caption)
                                    .foregroundColor(chatGPTService.hasValidAPIKey ? .green : .secondary)
                            }
                            
                            Spacer()
                            
                            if chatGPTService.hasValidAPIKey {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                } header: {
                    Text("ai.title".localized.replacingOccurrences(of: "🧠 ", with: ""))
                } footer: {
                    Text("chatgpt.description".localized)
                }

                // Exercise Library
                Section {
                    Button(action: { showingExerciseLibrary = true }) {
                        HStack {
                            Image(systemName: "books.vertical")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("exercise.library.title".localized)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("exercise.library.subtitle".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Toggle(isOn: $useWebSearchForExercises) {
                        HStack {
                            Image(systemName: "globe.badge.chevron.backward")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("settings.exercise.web_search".localized)
                                .font(.body)
                        }
                    }
                    
                    Picker(selection: $exerciseRefreshInterval) {
                        ForEach(ExerciseLibraryRefresher.Interval.allCases, id: \.rawValue) { interval in
                            Text(interval.displayName).tag(interval.rawValue)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("settings.exercise.refresh_interval".localized)
                                .font(.body)
                        }
                    }
                } footer: {
                    Text("settings.exercise.web_search_footer".localized)
                }
                
                // App Information Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.version".localized)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text(getAppVersion())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                } header: {
                    Text("settings.about".localized)
                }

                // Disclaimer / Safety Notice
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text("settings.disclaimer.message".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("settings.disclaimer.title".localized)
                }
            }
            .navigationTitle("settings.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingChatGPTSettings) {
            ChatGPTSettingsView()
        }
        .sheet(isPresented: $showingExerciseLibrary) {
            ExerciseLibraryView()
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
        .onLanguageChange {
            // Force UI refresh when language changes
        }
    }
    
    private func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
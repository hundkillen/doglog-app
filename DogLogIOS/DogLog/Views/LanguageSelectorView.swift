import SwiftUI

struct LanguageSelectorView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(LocalizationManager.AppLanguage.allCases, id: \.self) { language in
                        LanguageRowView(
                            language: language,
                            isSelected: localizationManager.currentLanguage == language
                        ) {
                            localizationManager.currentLanguage = language
                        }
                    }
                } header: {
                    Text("language.choose".localized)
                } footer: {
                    Text("language.footer".localized)
                }
            }
            .navigationTitle("language.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LanguageRowView: View {
    let language: LocalizationManager.AppLanguage
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: language.icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if language == .system {
                        Text("language.system.description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconColor: Color {
        switch language {
        case .system: return .blue
        case .swedish: return .yellow
        case .english: return .red
        }
    }
}

// MARK: - Settings Integration
struct LanguageSettingsRowView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var showingLanguageSelector = false
    
    var body: some View {
        Button(action: {
            showingLanguageSelector = true
        }) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.language".localized)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(localizationManager.currentLanguage.displayName)
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
        .sheet(isPresented: $showingLanguageSelector) {
            LanguageSelectorView()
        }
    }
}

struct LanguageSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageSelectorView()
    }
}
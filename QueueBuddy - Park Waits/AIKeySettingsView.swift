import SwiftUI

/// Sheet for entering the Anthropic API key and picking a Claude model.
/// The key is persisted in the Keychain via `ClaudeAIClient`.
struct AIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var selectedModelID: String = ClaudeAIClient.currentModelID()
    @State private var didSave: Bool = false

    private let models = ClaudeAIClient.availableModels

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("QueueBuddy's AI assistant uses Anthropic's Claude API. Paste an API key from console.anthropic.com — it stays on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("API Key") {
                    SecureField("sk-ant-...", text: $apiKey)
                        .autocorrectionDisabled(true)

                    if !apiKey.isEmpty {
                        Button(role: .destructive) {
                            apiKey = ""
                            ClaudeAIClient.storeAPIKey("")
                        } label: {
                            Label("Clear Key", systemImage: "trash")
                        }
                    }
                }

                Section("Model") {
                    ForEach(models) { model in
                        Button {
                            selectedModelID = model.id
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(model.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(model.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedModelID == model.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.purple)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if didSave {
                    Section {
                        Label("Saved", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("AI Settings")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        ClaudeAIClient.storeAPIKey(apiKey)
                        ClaudeAIClient.setModelID(selectedModelID)
                        didSave = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            dismiss()
                        }
                    }
                    .bold()
                }
            }
            .swipeBackEnabled()
            .onAppear {
                apiKey = ClaudeAIClient.readAPIKey() ?? ""
                selectedModelID = ClaudeAIClient.currentModelID()
            }
        }
    }
}

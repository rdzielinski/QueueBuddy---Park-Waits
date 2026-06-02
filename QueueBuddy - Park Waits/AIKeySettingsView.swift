import SwiftUI

/// Sheet for picking an AI provider, supplying its API key, and choosing
/// the model to use. One active provider at a time — switching the
/// picker swaps which key field and model list is shown. Keys for the
/// non-active providers are still stored in the Keychain so flipping
/// back doesn't require re-entering them.
struct AIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProvider: AIProviderKind = AIProviderRegistry.currentKind()
    @State private var apiKey: String = ""
    @State private var selectedModelID: String = ""
    @State private var didSave: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                blurbSection
                keySection
                modelSection
                helpSection
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
                    Button("Save", action: save).bold()
                }
            }
            .swipeBackEnabled()
            .onAppear { syncFieldsFromStorage() }
            .onChange(of: selectedProvider) { _, _ in syncFieldsFromStorage() }
        }
    }

    // MARK: - Sections

    private var providerSection: some View {
        Section("Provider") {
            ForEach(AIProviderKind.allCases) { kind in
                Button {
                    selectedProvider = kind
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(kind.blurb)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if kind == .apple && !AppleIntelligenceClient.isAvailableOnThisDevice {
                                Text("Not available on this device.")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .padding(.top, 2)
                            }
                        }
                        Spacer()
                        if selectedProvider == kind {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.purple)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(kind == .apple && !AppleIntelligenceClient.isAvailableOnThisDevice)
            }
        }
    }

    private var blurbSection: some View {
        Section {
            Text(blurbText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var keySection: some View {
        if selectedProvider.requiresAPIKey {
            Section("API Key") {
                SecureField(selectedProvider.keyPlaceholder, text: $apiKey)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)

                if !apiKey.isEmpty {
                    Button(role: .destructive) {
                        apiKey = ""
                        AIProviderRegistry.storeAPIKey("", for: selectedProvider)
                    } label: {
                        Label("Clear Key", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        let models = selectedProvider.availableModels
        if models.count > 1 {
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
        }
    }

    @ViewBuilder
    private var helpSection: some View {
        if let url = selectedProvider.keyHelpURL {
            Section {
                Link(destination: url) {
                    Label("Get a \(selectedProvider.shortName) API key",
                          systemImage: "arrow.up.right.square")
                }
            }
        }
    }

    // MARK: - Helpers

    private var blurbText: String {
        switch selectedProvider {
        case .claude:
            return "QueueBuddy's AI assistant talks to Anthropic's Claude API. Paste an API key from console.anthropic.com — it stays on this device, encrypted in the Keychain."
        case .openai:
            return "QueueBuddy's AI assistant talks to OpenAI's Chat Completions API. Paste an API key from platform.openai.com — it stays on this device, encrypted in the Keychain."
        case .gemini:
            return "QueueBuddy's AI assistant talks to Google Gemini. Paste an API key from aistudio.google.com — it stays on this device, encrypted in the Keychain. Free tier is generous."
        case .apple:
            return "QueueBuddy's AI assistant uses Apple Intelligence on-device — no API key required, no data ever leaves your phone. Requires iOS 26 or later on Apple-Intelligence-capable hardware."
        }
    }

    private func syncFieldsFromStorage() {
        if selectedProvider.requiresAPIKey {
            apiKey = AIProviderRegistry.readAPIKey(for: selectedProvider) ?? ""
        } else {
            apiKey = ""
        }
        selectedModelID = AIProviderRegistry.currentModelID(for: selectedProvider)
    }

    private func save() {
        if selectedProvider.requiresAPIKey {
            AIProviderRegistry.storeAPIKey(apiKey, for: selectedProvider)
        }
        AIProviderRegistry.setModelID(selectedModelID, for: selectedProvider)
        AIProviderRegistry.setCurrentKind(selectedProvider)
        didSave = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
    }
}

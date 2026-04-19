import SwiftUI

struct AIPlaygroundView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @AppStorage("preferredParkId") private var preferredParkId: Int = 0
    @AppStorage("childHeightInches") private var childHeightInches: Int = 0
    @State private var query: String = ""
    @State private var selectedParkID: Int = 0
    @State private var showSettings: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    private var parksForPicker: [Park] {
        let nonePark = Park(id: 0, name: "No Park Context")
        return [nonePark] + (viewModel.resortGroups.flatMap { $0.parks })
    }

    private var hasAPIKey: Bool {
        (ClaudeAIClient.readAPIKey() ?? "").isEmpty == false
    }

    private var selectedPark: Park? {
        parksForPicker.first { $0.id == selectedParkID && $0.id != 0 }
    }

    private var accent: Color {
        guard let park = selectedPark else { return DB.amber }
        return DB.accent(for: park.id)
    }

    private var suggestions: [String] {
        if let park = selectedPark {
            return [
                "Shortest waits right now at \(park.name)?",
                "Plan a 4-hour morning for first-time visitors.",
                "Best rides for a 42\" child?",
                "Which shows are worth seeing today?"
            ]
        }
        return [
            "Which Orlando park has the shortest waits today?",
            "Compare Epic Universe to Magic Kingdom for thrill seekers.",
            "Rainy-day park plan?",
            "Tips for a trip with kids under 6?"
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DB.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if !hasAPIKey { missingKeyBanner }
                        parkContextPicker
                        inputRow
                        if !viewModel.isAILoading && viewModel.aiConversation.isEmpty {
                            suggestionChips
                        }
                        if let error = viewModel.aiError {
                            errorBanner(error)
                        }
                        conversationList
                        Color.clear.frame(height: 120)
                    }
                    .padding(.horizontal, 16)
                }
                .onTapGesture { isTextFieldFocused = false }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                AIKeySettingsView()
            }
            .onAppear {
                if selectedParkID == 0 {
                    // Prefer the user's saved favorite, then active park, then first in the list.
                    if preferredParkId != 0 { selectedParkID = preferredParkId }
                    else if let id = viewModel.activeParkId { selectedParkID = id }
                    else { selectedParkID = viewModel.resortGroups.first?.parks.first?.id ?? 0 }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isTextFieldFocused = false }
                        .foregroundStyle(DB.amber)
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                MonoLabel(text: "POWERED BY CLAUDE", color: DB.muted)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("Plan")
                        .font(DB.displayTitle(34))
                        .foregroundStyle(DB.text)
                        .tracking(-0.8)
                    Text(".")
                        .font(DB.displayTitle(34))
                        .foregroundStyle(DB.amber)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                if !viewModel.aiConversation.isEmpty {
                    Button {
                        viewModel.resetAIConversation()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(DB.muted)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().fill(Color.white.opacity(0.05))
                                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                        .foregroundStyle(DB.muted)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(Color.white.opacity(0.05))
                                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private var missingKeyBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "key.horizontal.fill")
                .foregroundStyle(DB.amber)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                MonoLabel(text: "CONNECT ANTHROPIC KEY", color: DB.amber)
                Text("Paste a Claude API key in Settings. It stays on this device.")
                    .font(.system(size: 12))
                    .foregroundStyle(DB.muted)
            }
            Spacer()
            Button("Open") { showSettings = true }
                .font(DB.heading(12, weight: .semibold))
                .foregroundStyle(Color(hex: 0x0A0B0D))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(DB.amber))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DB.amber.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DB.amber.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var parkContextPicker: some View {
        HStack(spacing: 8) {
            MonoLabel(text: "CONTEXT", color: DB.muted, tracking: 1.5, size: 10)
            Spacer()
            Menu {
                Picker("Park", selection: $selectedParkID) {
                    ForEach(parksForPicker) { park in
                        Text(park.name).tag(park.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if let park = selectedPark {
                        Circle().fill(DB.accent(for: park.id))
                            .frame(width: 6, height: 6)
                        Text(park.name)
                    } else {
                        Text("No park")
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(DB.mono(12))
                .foregroundStyle(DB.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color.white.opacity(0.05))
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
            }
        }
    }

    private var inputRow: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(">")
                    .font(DB.mono(14, weight: .bold))
                    .foregroundStyle(accent)
                    .padding(.top, 12)
                TextField(
                    "",
                    text: $query,
                    prompt: Text("ask anything…").foregroundStyle(DB.muted),
                    axis: .vertical
                )
                .font(DB.mono(14))
                .foregroundStyle(DB.text)
                .tint(accent)
                .lineLimit(1...5)
                .focused($isTextFieldFocused)
                .onSubmit(submitQuery)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DB.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )

            Button(action: submitQuery) {
                HStack {
                    if viewModel.isAILoading {
                        ProgressView().tint(Color(hex: 0x0A0B0D))
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(viewModel.isAILoading ? "THINKING..." : "SEND")
                        .tracking(1.5)
                }
                .font(DB.mono(13, weight: .bold))
                .foregroundStyle(Color(hex: 0x0A0B0D))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent)
                        .opacity(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isAILoading || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        query = s
                    } label: {
                        Text(s)
                            .font(.system(size: 12))
                            .foregroundStyle(DB.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(accent.opacity(0.12))
                                    .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DB.red)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(DB.text)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DB.red.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DB.red.opacity(0.3), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var conversationList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.aiConversation) { message in
                HStack(alignment: .top, spacing: 8) {
                    if message.speaker == .ai {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                            .foregroundStyle(accent)
                            .padding(.top, 10)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        MonoLabel(
                            text: message.speaker == .user ? "YOU" : "CLAUDE",
                            color: message.speaker == .user ? DB.muted : accent,
                            tracking: 1.5, size: 9
                        )
                        Text(message.text)
                            .font(.system(size: 14))
                            .foregroundStyle(DB.text)
                            .lineSpacing(3)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(message.speaker == .user
                                  ? Color.white.opacity(0.04)
                                  : DB.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private func submitQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isTextFieldFocused = false
        let sendText = trimmed
        query = ""
        let height: Int? = childHeightInches > 0 ? childHeightInches : nil
        Task {
            let parkContext = parksForPicker.first { $0.id == selectedParkID && $0.id != 0 }
            await viewModel.fetchAIResponse(
                for: sendText,
                parkContext: parkContext,
                childHeight: height
            )
        }
    }
}

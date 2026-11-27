import SwiftUI

struct AIPlaygroundView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @StateObject private var planStore = ParkDayPlanStore.shared
    @AppStorage("preferredParkId") private var preferredParkId: Int = 0
    @AppStorage("childHeightInches") private var childHeightInches: Int = 0
    @AppStorage(AIProviderRegistry.activeProviderKey) private var activeProviderRaw: String = AIProviderKind.claude.rawValue
    @State private var query: String = ""
    /// Parks the chat answers about: "" = not chosen yet (defaults to the
    /// guest's park on first appear), "all", or comma-separated park ids.
    @AppStorage("planParkScope") private var parkScopeRaw: String = ""
    @State private var showSettings: Bool = false
    @State private var addedMessageIDs: Set<UUID> = []
    @State private var parkDayActivityRunning: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    private var allParks: [Park] { viewModel.resortGroups.flatMap { $0.parks } }

    /// nil means every park.
    private var scopeIds: Set<Int>? {
        guard !parkScopeRaw.isEmpty, parkScopeRaw != "all" else { return nil }
        let ids = Set(parkScopeRaw.split(separator: ",").compactMap { Int($0) })
        return ids.isEmpty ? nil : ids
    }

    private var scopedParks: [Park] {
        guard let ids = scopeIds else { return allParks }
        let parks = allParks.filter { ids.contains($0.id) }
        return parks.isEmpty ? allParks : parks
    }

    private var isAllParks: Bool { scopeIds == nil || scopedParks.count == allParks.count }

    private func setScope(_ ids: Set<Int>?) {
        if let ids, !ids.isEmpty, ids.count < allParks.count {
            parkScopeRaw = ids.sorted().map(String.init).joined(separator: ",")
        } else {
            parkScopeRaw = "all"
        }
    }

    private func toggleScope(_ park: Park) {
        // From "all parks", picking a park narrows to just that park.
        guard var ids = scopeIds else { setScope([park.id]); return }
        if ids.contains(park.id) { ids.remove(park.id) } else { ids.insert(park.id) }
        setScope(ids)
    }

    private var hasAPIKey: Bool {
        // True when the currently-selected AI provider is ready to call.
        // Cloud providers need a key; Apple Intelligence is "ready" once
        // the device supports it.
        AIProviderRegistry.currentIsConfigured()
    }

    /// The park when exactly one is in scope (My Day, Live Activity and
    /// per-park suggestions only make sense for one park).
    private var selectedPark: Park? {
        let parks = scopedParks
        return parks.count == 1 ? parks.first : nil
    }

    /// The AI provider the user picked in Settings. Read through @AppStorage
    /// so the "Powered by" label and the chat byline track provider changes
    /// live (e.g. switching from Claude to ChatGPT in Settings).
    private var currentProvider: AIProviderKind {
        AIProviderKind(rawValue: activeProviderRaw) ?? .claude
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
            "What's the longest wait right now?",
            "Which park has the shortest waits?",
            "Best thrill ride under 30 minutes?",
            "Where should we go for a rainy afternoon?"
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
                        myDayBoard
                        inputRow
                        if !viewModel.isAILoading && viewModel.aiConversation.isEmpty {
                            suggestionChips
                        }
                        if let error = viewModel.aiError {
                            errorBanner(error)
                        }
                        conversationList
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 16)
                }
                .onTapGesture { isTextFieldFocused = false }
            }
            .toolbar(.hidden, for: .navigationBar)
            .swipeBackEnabled()
            .sheet(isPresented: $showSettings) {
                AIKeySettingsView()
            }
            .onAppear {
                if parkScopeRaw.isEmpty {
                    // First visit: the user's saved favorite, then the park
                    // they're in, else every park.
                    if preferredParkId != 0 { parkScopeRaw = "\(preferredParkId)" }
                    else if let id = viewModel.activeParkId { parkScopeRaw = "\(id)" }
                    else { parkScopeRaw = "all" }
                }
                syncParkDayActivityState()
            }
            .onChange(of: parkScopeRaw) { _, _ in
                syncParkDayActivityState()
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
                MonoLabel(text: "Powered by \(currentProvider.shortName)", color: DB.muted)
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
                MonoLabel(text: "CONNECT AI PROVIDER", color: DB.amber)
                Text("Pick a provider (Claude, ChatGPT, Gemini, or Apple Intelligence) in Settings → AI Assistant.")
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
            MonoLabel(text: "PARKS", color: DB.muted, tracking: 1.5, size: 10)
            Spacer()
            Menu {
                Button {
                    setScope(nil)
                } label: {
                    menuRow("All Parks", checked: isAllParks)
                }
                ForEach(viewModel.resortGroups) { group in
                    Section(group.name) {
                        ForEach(group.parks) { park in
                            Button {
                                toggleScope(park)
                            } label: {
                                menuRow(park.name, checked: !isAllParks && scopeIds?.contains(park.id) == true)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    scopeDots
                    Text(scopeTitle)
                        .lineLimit(1)
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
            .menuActionDismissBehavior(.disabled)
            .accessibilityLabel("Parks: \(scopeTitle)")
        }
    }

    @ViewBuilder
    private func menuRow(_ title: String, checked: Bool) -> some View {
        if checked { Label(title, systemImage: "checkmark") } else { Text(title) }
    }

    private var scopeTitle: String {
        if isAllParks { return "All parks" }
        let parks = scopedParks
        if parks.count == 1 { return parks[0].name }
        return "\(parks.count) parks"
    }

    private var scopeDots: some View {
        HStack(spacing: -2) {
            ForEach((isAllParks ? [] : scopedParks).prefix(4)) { park in
                Circle().fill(DB.accent(for: park.id))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var myDayBoard: some View {
        let visibleItems = planStore.items(for: selectedPark?.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonoLabel(text: "MY DAY", color: DB.muted, tracking: 1.5, size: 10)
                Spacer()
                if let park = selectedPark {
                    Button {
                        let attractions = viewModel.attractionsByPark[park.id] ?? []
                        planStore.addTopPicks(from: attractions, park: park)
                    } label: {
                        Label("Auto-fill", systemImage: "wand.and.stars")
                            .font(DB.mono(11, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Auto-fill My Day with short waits")
                }
            }

            if visibleItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add rides from attraction details or auto-fill from the shortest waits.")
                        .font(.system(size: 13))
                        .foregroundStyle(DB.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if #available(iOS 16.1, *) {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 11))
                                .foregroundStyle(accent)
                                .padding(.top, 1)
                            Text("Once your plan has a ride, you can start a Live Activity to track your next stop and its wait on the Lock Screen.")
                                .font(.system(size: 12))
                                .foregroundStyle(DB.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DB.card))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 10) {
                            Button {
                                planStore.toggleSelected(item)
                            } label: {
                                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isSelected ? accent : DB.muted)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.isSelected ? "Stop tracking \(item.attractionName)" : "Track \(item.attractionName)")

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.attractionName)
                                    .font(DB.heading(14, weight: .medium))
                                    .foregroundStyle(item.isSelected ? DB.text : DB.muted)
                                    .lineLimit(1)
                                Text(item.parkName.uppercased())
                                    .font(DB.mono(9))
                                    .tracking(1.4)
                                    .foregroundStyle(DB.muted)
                            }
                            Spacer()
                            Button {
                                planStore.remove(item)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(DB.muted)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(item.attractionName) from My Day")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        if index < visibleItems.count - 1 {
                            Rectangle().fill(DB.line).frame(height: 1)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DB.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )

                if let park = selectedPark,
                   visibleItems.contains(where: { $0.isSelected }) {
                    liveActivityToggle(park: park)
                }
            }
        }
        .onChange(of: planStore.items) { _, _ in
            syncParkDayActivityState()
            if #available(iOS 16.1, *) {
                ParkDayActivityController.refresh(attractionsByPark: viewModel.attractionsByPark)
            }
        }
    }

    @ViewBuilder
    private func liveActivityToggle(park: Park) -> some View {
        if #available(iOS 16.1, *) {
            Button {
                toggleParkDayActivity(for: park)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: parkDayActivityRunning ? "stop.circle.fill" : "dot.radiowaves.left.and.right")
                        .font(.system(size: 13))
                    Text(parkDayActivityRunning ? "STOP LIVE ACTIVITY" : "START LIVE ACTIVITY")
                        .tracking(1.5)
                }
                .font(DB.mono(11, weight: .semibold))
                .foregroundStyle(parkDayActivityRunning ? DB.red : accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill((parkDayActivityRunning ? DB.red : accent).opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke((parkDayActivityRunning ? DB.red : accent).opacity(0.35), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(parkDayActivityRunning
                                ? "Stop the Park Day Live Activity"
                                : "Start the Park Day Live Activity")
        }
    }

    private func toggleParkDayActivity(for park: Park) {
        if #available(iOS 16.1, *) {
            if parkDayActivityRunning {
                ParkDayActivityController.stop()
                parkDayActivityRunning = false
            } else {
                let attractions = viewModel.attractionsByPark[park.id] ?? []
                let didStart = ParkDayActivityController.start(park: park, attractions: attractions)
                parkDayActivityRunning = didStart
            }
        }
    }

    private func syncParkDayActivityState() {
        if #available(iOS 16.1, *) {
            parkDayActivityRunning = ParkDayActivityController.isRunning(forParkId: selectedPark?.id ?? 0)
        } else {
            parkDayActivityRunning = false
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
                            text: message.speaker == .user ? "YOU" : currentProvider.shortName,
                            color: message.speaker == .user ? DB.muted : accent,
                            tracking: 1.5, size: 9
                        )
                        Text(message.text)
                            .font(.system(size: 14))
                            .foregroundStyle(DB.text)
                            .lineSpacing(3)
                        if message.speaker == .ai {
                            addToMyDayButton(for: message)
                        }
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

            if viewModel.isAILoading {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundStyle(accent)
                        .padding(.top, 10)
                    VStack(alignment: .leading, spacing: 6) {
                        MonoLabel(text: currentProvider.shortName, color: accent, tracking: 1.5, size: 9)
                        TypingDots(color: accent)
                            .padding(.vertical, 2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DB.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                    )
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isAILoading)
    }

    @ViewBuilder
    private func addToMyDayButton(for message: WaitTimeViewModel.AIMessage) -> some View {
        // Only offer this when the answer is about one park; a cross-park
        // answer isn't a plan for one day.
        if let park = selectedPark {
            let mentioned = viewModel.attractionsMentioned(in: message.text, parkId: park.id)
            let newOnes = mentioned.filter { !planStore.contains(attractionId: $0.id) }
            let alreadyTapped = addedMessageIDs.contains(message.id)

            if !mentioned.isEmpty {
                if alreadyTapped || newOnes.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text("ADDED TO MY DAY")
                            .tracking(1.4)
                    }
                    .font(DB.mono(10, weight: .semibold))
                    .foregroundStyle(DB.green)
                    .padding(.top, 8)
                } else {
                    Button {
                        addMentioned(newOnes, to: park, messageID: message.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 11))
                            Text("ADD \(newOnes.count) TO MY DAY")
                                .tracking(1.4)
                        }
                        .font(DB.mono(10, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(accent.opacity(0.12))
                                .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .accessibilityLabel("Add \(newOnes.count) suggested rides to My Day")
                }
            }
        }
    }

    private func addMentioned(_ attractions: [Attraction], to park: Park, messageID: UUID) {
        let startDate = Date()
        for (index, attraction) in attractions.enumerated() {
            planStore.add(
                attraction: attraction,
                park: park,
                note: "From Plan",
                plannedDate: startDate.addingTimeInterval(Double(index) * 45 * 60)
            )
        }
        addedMessageIDs.insert(messageID)
    }

    private func submitQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isTextFieldFocused = false
        let sendText = trimmed
        query = ""
        let height: Int? = childHeightInches > 0 ? childHeightInches : nil
        Task {
            await viewModel.fetchAIResponse(
                for: sendText,
                parks: scopedParks,
                childHeight: height
            )
        }
    }
}

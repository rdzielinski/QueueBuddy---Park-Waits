import SwiftUI
import UIKit
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WaitTimeViewModel

    @AppStorage("userDisplayName") private var userDisplayName: String = ""
    @AppStorage(UserPreferences.Key.tempUnit) private var tempUnitRaw: String = UserPreferences.TempUnit.fahrenheit.rawValue
    @AppStorage(UserPreferences.Key.timeFormat) private var timeFormatRaw: String = UserPreferences.TimeFormat.twelveHour.rawValue
    @AppStorage(UserPreferences.Key.defaultTab) private var defaultTabRaw: Int = QBTab.parks.rawValue
    @AppStorage(UserPreferences.Key.backgroundRefreshEnabled) private var backgroundRefreshEnabled: Bool = true
    @AppStorage(UserPreferences.Key.notificationsEnabled) private var notificationsEnabled: Bool = true
    @AppStorage(UserPreferences.Key.quietHoursEnabled) private var quietHoursEnabled: Bool = false
    @AppStorage(UserPreferences.Key.quietHoursStart) private var quietHoursStart: Int = 22 * 60
    @AppStorage(UserPreferences.Key.quietHoursEnd) private var quietHoursEnd: Int = 8 * 60
    @AppStorage(UserPreferences.Key.defaultThresholdMinutes) private var defaultThresholdMinutes: Int = 15

    @State private var draftName: String = ""
    @State private var showAISettings = false
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false
    @State private var showShareSheet = false
    @State private var confirmReset = false
    @State private var confirmClearCache = false
    @State private var clearedFeedback = false

    private let thresholdOptions = [5, 10, 15, 20, 30, 45, 60]
    private let shareText = "QueueBuddy — live wait times for Orlando theme parks."

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                preferencesSection
                notificationsSection
                appBehaviorSection
                aiSection
                legalSection
                aboutSection
                versionSection
            }
            .scrollContentBackground(.hidden)
            .background(DB.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DB.text)
                }
            }
            .sheet(isPresented: $showAISettings) { AIKeySettingsView() }
            .sheet(isPresented: $showPrivacyPolicy) { PolicyView(kind: .privacy) }
            .sheet(isPresented: $showTerms) { PolicyView(kind: .terms) }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareText])
            }
            .alert("Replay welcome?", isPresented: $confirmReset) {
                Button("Cancel", role: .cancel) { }
                Button("Replay", role: .destructive) {
                    userDisplayName = ""
                    dismiss()
                }
            } message: {
                Text("Your name will be cleared and the onboarding screens will show again next time you open the Parks tab.")
            }
            .alert("Clear cached data?", isPresented: $confirmClearCache) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllCaches()
                }
            } message: {
                Text("This removes saved wait times, trend history, and notification dedup state. Your favorites, name, and AI key are kept.")
            }
            .onAppear { draftName = userDisplayName }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section("Profile") {
            HStack {
                Text("Display name")
                Spacer()
                TextField("Your name", text: $draftName)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .onSubmit { commitName() }
            }
            if draftName.trimmingCharacters(in: .whitespaces) != userDisplayName {
                Button("Save name") { commitName() }
                    .foregroundStyle(DB.amber)
            }
        }
    }

    private func commitName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        userDisplayName = trimmed
        draftName = trimmed
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker("Temperature", selection: $tempUnitRaw) {
                ForEach(UserPreferences.TempUnit.allCases) { unit in
                    Text(unit.symbol).tag(unit.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Picker("Time format", selection: $timeFormatRaw) {
                ForEach(UserPreferences.TimeFormat.allCases) { format in
                    Text(format.label).tag(format.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Picker("Launch on", selection: $defaultTabRaw) {
                ForEach(QBTab.allCases) { tab in
                    Text(tab.label).tag(tab.rawValue)
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle("Allow notifications", isOn: $notificationsEnabled)

            HStack {
                Text("Default threshold")
                Spacer()
                Picker("", selection: $defaultThresholdMinutes) {
                    ForEach(thresholdOptions, id: \.self) { m in
                        Text("\(m) min").tag(m)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(DB.amber)
            }
            .disabled(!notificationsEnabled)

            Toggle("Quiet hours", isOn: $quietHoursEnabled)
                .disabled(!notificationsEnabled)

            if quietHoursEnabled && notificationsEnabled {
                quietHourPicker(label: "From", binding: $quietHoursStart)
                quietHourPicker(label: "To", binding: $quietHoursEnd)
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(notificationsEnabled
                 ? "Quiet hours silence push banners during the chosen window. The in-app Alerts feed still records events."
                 : "All push notifications are muted. Per-attraction alerts you've set up will resume when you turn this back on.")
        }
    }

    private func quietHourPicker(label: String, binding: Binding<Int>) -> some View {
        let date = Binding<Date>(
            get: {
                let cal = Calendar.current
                let now = cal.startOfDay(for: Date())
                return cal.date(byAdding: .minute, value: binding.wrappedValue, to: now) ?? now
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                binding.wrappedValue = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        )
        return DatePicker(label, selection: date, displayedComponents: .hourAndMinute)
    }

    // MARK: - App Behavior

    private var appBehaviorSection: some View {
        Section {
            Toggle("Background refresh", isOn: $backgroundRefreshEnabled)
                .onChange(of: backgroundRefreshEnabled) { _, _ in
                    WaitTimeViewModel.scheduleNextAppRefresh()
                }

            Button {
                confirmReset = true
            } label: {
                Label("Replay welcome screens", systemImage: "arrow.uturn.left")
                    .foregroundStyle(DB.text)
            }

            Button(role: .destructive) {
                confirmClearCache = true
            } label: {
                Label("Clear cached data", systemImage: "trash")
            }

            if clearedFeedback {
                Label("Cache cleared", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        } header: {
            Text("App Behavior")
        } footer: {
            Text("Background refresh lets QueueBuddy fetch new wait times while the app is closed.")
        }
    }

    private func clearAllCaches() {
        WaitCacheStore.clearAll()
        WaitHistoryStore.shared.clearAll()
        NotificationDedupStore.clearAll()
        clearedFeedback = true
        Task {
            // Refetch so the user isn't staring at an empty Parks list
            // once they close Settings.
            await viewModel.loadInitialData()
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run { clearedFeedback = false }
        }
    }

    // MARK: - AI Assistant

    private var aiSection: some View {
        Section("AI Assistant") {
            Button {
                showAISettings = true
            } label: {
                HStack {
                    Label("AI Assistant Settings", systemImage: "sparkles")
                        .foregroundStyle(DB.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DB.muted)
                }
            }
        }
    }

    // MARK: - Legal & Support

    private var legalSection: some View {
        Section("Legal & Support") {
            Button {
                showPrivacyPolicy = true
            } label: {
                rowLabel("Privacy Policy", systemImage: "lock.shield")
            }

            Button {
                showTerms = true
            } label: {
                rowLabel("Terms of Service", systemImage: "doc.text")
            }

            if let url = URL(string: "mailto:rdzielinski98@gmail.com?subject=QueueBuddy%20Support") {
                Link(destination: url) {
                    rowLabel("Email support", systemImage: "envelope")
                }
            }

            Button {
                requestAppStoreReview()
            } label: {
                rowLabel("Rate QueueBuddy", systemImage: "star")
            }

            Button {
                showShareSheet = true
            } label: {
                rowLabel("Share QueueBuddy", systemImage: "square.and.arrow.up")
            }
        }
    }

    private func rowLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(DB.text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DB.muted)
        }
    }

    private func requestAppStoreReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
    }

    // MARK: - About (disclaimer + sources)

    private var aboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                MonoLabel(text: "▲ UNOFFICIAL APP", color: DB.amber, tracking: 2, size: 11)
                Text("QueueBuddy is an independent fan-made app.")
                    .font(DB.heading(15, weight: .semibold))
                    .foregroundStyle(DB.text)
                Text("Not affiliated with, endorsed by, sponsored by, or in any way officially connected to The Walt Disney Company, Walt Disney Parks and Resorts, NBCUniversal, Universal Destinations & Experiences, or any of their subsidiaries or affiliates. All park, attraction, and resort names are trademarks of their respective owners and are used here for descriptive purposes only.")
                    .font(.system(size: 13))
                    .foregroundStyle(DB.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "DATA SOURCES", color: DB.muted, tracking: 2, size: 11)
                Text("Wait times: themeparks.wiki, queue-times.com. Weather: Open-Meteo. AI: Anthropic Claude (your own API key).")
                    .font(.system(size: 13))
                    .foregroundStyle(DB.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        } header: {
            Text("About")
        }
    }

    // MARK: - Version

    private var versionSection: some View {
        Section {
            HStack {
                Text("Version")
                    .foregroundStyle(DB.text)
                Spacer()
                Text(versionString)
                    .font(DB.mono(13))
                    .foregroundStyle(DB.muted)
            }
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}

// MARK: - UIActivityViewController bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

#Preview {
    SettingsView()
        .environmentObject(WaitTimeViewModel())
}

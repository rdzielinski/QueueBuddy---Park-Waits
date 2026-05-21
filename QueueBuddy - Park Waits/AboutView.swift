import SwiftUI

/// About / disclaimers sheet. Surfaces the "not affiliated" notice required
/// for nominative-fair-use of trademarked park names, plus data source
/// attribution and a link into AI Settings.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAISettings = false

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DB.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        disclaimerCard
                        dataSourcesCard
                        linksCard
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DB.text)
                }
            }
            .sheet(isPresented: $showAISettings) {
                AIKeySettingsView()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: "VERSION \(appVersion)", color: DB.muted, tracking: 1.8, size: 11)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("QueueBuddy")
                    .font(DB.displayTitle(32))
                    .foregroundStyle(DB.text)
                    .tracking(-0.6)
                Text(".")
                    .font(DB.displayTitle(32))
                    .foregroundStyle(DB.amber)
            }
            Text("Live wait times for the seven Orlando theme parks.")
                .font(DB.heading(14, weight: .regular))
                .foregroundStyle(DB.muted)
        }
        .padding(.top, 4)
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: "▲ UNOFFICIAL APP", color: DB.amber, tracking: 2, size: 11)

            Text("QueueBuddy is an independent fan-made app.")
                .font(DB.heading(16, weight: .semibold))
                .foregroundStyle(DB.text)

            Text("It is not affiliated with, endorsed by, sponsored by, or in any way officially connected to The Walt Disney Company, Walt Disney Parks and Resorts, NBCUniversal, Universal Destinations & Experiences, or any of their subsidiaries or affiliates.")
                .font(.system(size: 13))
                .foregroundStyle(DB.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("All park names, attraction names, resort names, and related marks referenced in this app are trademarks of their respective owners and are used here for descriptive purposes only.")
                .font(.system(size: 13))
                .foregroundStyle(DB.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DB.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DB.amber.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var dataSourcesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel(text: "DATA SOURCES", color: DB.muted, tracking: 2, size: 11)

            Text("Wait times are aggregated from themeparks.wiki and queue-times.com. Weather data comes from Open-Meteo. The AI assistant is powered by Anthropic Claude and uses your own API key, which stays on this device.")
                .font(.system(size: 13))
                .foregroundStyle(DB.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DB.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DB.line, lineWidth: 1)
                )
        )
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            Button {
                showAISettings = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DB.amber)
                        .frame(width: 22)
                    Text("AI Assistant Settings")
                        .font(DB.heading(15, weight: .medium))
                        .foregroundStyle(DB.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DB.muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DB.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DB.line, lineWidth: 1)
                )
        )
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            MonoLabel(text: "MADE WITH CARE · ORLANDO, FL", color: DB.dim, tracking: 2, size: 10)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }
}

#Preview {
    AboutView()
}

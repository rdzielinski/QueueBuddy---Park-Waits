import SwiftUI

/// Renders a static policy document (Privacy Policy or Terms of Service)
/// as a styled sheet. The actual text lives below as inline constants so
/// the build doesn't depend on bundled resource files.
struct PolicyView: View {
    enum Kind: String {
        case privacy = "Privacy Policy"
        case terms = "Terms of Service"

        var body: String {
            switch self {
            case .privacy: return PolicyText.privacy
            case .terms:   return PolicyText.terms
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    let kind: Kind

    var body: some View {
        NavigationStack {
            ZStack {
                DB.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        MonoLabel(text: "EFFECTIVE \(Self.effectiveDate)", color: DB.muted, tracking: 1.8, size: 11)
                        Text(kind.rawValue)
                            .font(DB.displayTitle(28))
                            .foregroundStyle(DB.text)
                            .tracking(-0.5)
                            .padding(.bottom, 6)

                        ForEach(parsed, id: \.id) { block in
                            switch block {
                            case .heading(_, let text):
                                Text(text)
                                    .font(DB.heading(16, weight: .semibold))
                                    .foregroundStyle(DB.text)
                                    .padding(.top, 8)
                            case .paragraph(_, let text):
                                Text(text)
                                    .font(.system(size: 14))
                                    .foregroundStyle(DB.muted)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            case .bullet(_, let text):
                                HStack(alignment: .top, spacing: 10) {
                                    Text("•")
                                        .font(.system(size: 14))
                                        .foregroundStyle(DB.amber)
                                    Text(text)
                                        .font(.system(size: 14))
                                        .foregroundStyle(DB.muted)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.leading, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(kind.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DB.text)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Lightweight markdown parsing

    private enum Block: Identifiable {
        case heading(UUID, String)
        case paragraph(UUID, String)
        case bullet(UUID, String)
        var id: UUID {
            switch self {
            case .heading(let id, _), .paragraph(let id, _), .bullet(let id, _):
                return id
            }
        }
    }

    private var parsed: [Block] {
        kind.body
            .split(separator: "\n\n", omittingEmptySubsequences: true)
            .map { chunk in
                let line = String(chunk).trimmingCharacters(in: .whitespacesAndNewlines)
                if line.hasPrefix("## ") {
                    return Block.heading(UUID(), String(line.dropFirst(3)))
                } else if line.hasPrefix("- ") {
                    return Block.bullet(UUID(), String(line.dropFirst(2)))
                } else {
                    return Block.paragraph(UUID(), line)
                }
            }
    }

    private static var effectiveDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: Date()).uppercased()
    }
}

// MARK: - Policy text

private enum PolicyText {
    static let privacy = """
## Summary

QueueBuddy does not collect, sell, or share your personal data. Almost everything that powers the app runs on your device.

## Information Stored on Your Device

- The display name you enter during onboarding.
- Your favorited attractions and per-attraction notification preferences.
- Recent wait-time samples used to draw trend charts.
- Your Anthropic API key, if you enable the AI assistant. The key is stored in the iOS Keychain and never leaves your device.

## Location

QueueBuddy requests "while-in-use" location permission to detect when you arrive at one of the supported theme parks. Your location is processed on-device only. It is not transmitted to QueueBuddy's servers or any third party.

## Network Requests

QueueBuddy makes network requests to a small number of third-party services to do its job:

- Wait times, schedules, and Lightning Lane data come from themeparks.wiki and queue-times.com.
- Weather comes from Open-Meteo.
- The AI assistant sends prompts directly from your device to api.anthropic.com using your own API key.
- A small Cloudflare Worker relays APNs push tokens for Live Activity updates. The worker stores only the APNs token needed to deliver notifications you have opted into.

## Advertising

QueueBuddy displays banner ads served by Google AdMob. We request non-personalized ads only, which means ads are not targeted using your personal data or cross-app activity. To serve these ads and prevent fraud, Google's Mobile Ads SDK may process limited device and diagnostic information as described in Google's own privacy disclosures. We do not request App Tracking Transparency permission and do not use the Identifier for Advertisers (IDFA) for tracking.

## Analytics and Tracking

QueueBuddy includes no third-party analytics SDKs. We do not track you across other apps or websites.

## Children

QueueBuddy is not directed to children under 13. We do not knowingly collect data from children.

## Changes

If this policy changes, we will update the effective date and post the new version inside the app.

## Contact

Questions? Email rdzielinski98@gmail.com.
"""

    static let terms = """
## Acceptance

By using QueueBuddy you accept these Terms of Service.

## Wait Times Are Estimates

Wait times displayed in QueueBuddy come from third-party data sources and may be outdated, inaccurate, or unavailable at any time. Plan your visit accordingly; we cannot guarantee real-time accuracy.

## Not Affiliated

QueueBuddy is independent and is not affiliated with, endorsed by, sponsored by, or in any way officially connected to The Walt Disney Company, Walt Disney Parks and Resorts, NBCUniversal, Universal Destinations & Experiences, or any of their subsidiaries or affiliates. All park, attraction, resort, and ride names are trademarks of their respective owners and are used for descriptive purposes only.

## AI Assistant

The AI assistant feature uses Anthropic's Claude API and requires you to supply your own API key. You are responsible for any usage charges Anthropic bills against that key. AI responses can be wrong; do not rely on them for safety, medical, financial, or other consequential decisions.

## No Warranty

QueueBuddy is provided "as-is" and "as available," without warranty of any kind, express or implied. Use at your own risk.

## Limitation of Liability

To the maximum extent permitted by law, QueueBuddy and its developer are not liable for any indirect, incidental, or consequential damages arising from your use of the app — including missed attractions or any reliance on inaccurate wait-time data.

## Changes

These terms may change. Continued use of the app after a change constitutes acceptance of the updated terms.

## Contact

rdzielinski98@gmail.com.
"""
}

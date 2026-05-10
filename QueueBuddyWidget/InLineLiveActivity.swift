import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
import WidgetKit

/// Mirror of the type defined in `QueueBuddy - Park Waits/InLineActivity.swift`.
/// Must keep identical names + property shapes for ActivityKit to match.
struct InLineAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var attractionName: String
        var parkAccentHex: UInt32
        var currentWait: Int?
        var startedAt: Double      // UNIX seconds — matches Cloudflare push payload
        var lastUpdatedAt: Double  // UNIX seconds — matches Cloudflare push payload
    }

    var attractionId: Int
    var parkUUID: String
}

@available(iOS 16.2, *)
struct InLineLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InLineAttributes.self) { context in
            lockScreenView(for: context.state)
                .activityBackgroundTint(WidgetTheme.bg)
                .activitySystemActionForegroundColor(WidgetTheme.amber)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(WidgetTheme.color(fromHex: context.state.parkAccentHex))
                            .frame(width: 6, height: 6)
                        Text("IN LINE")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(WidgetTheme.muted)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let w = context.state.currentWait {
                        Text("\(w) MIN")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(WidgetTheme.tone(for: w))
                    } else {
                        Text("--")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(WidgetTheme.muted)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.attractionName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WidgetTheme.text)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Joined \(elapsedString(since: context.state.startedAt)) ago")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(WidgetTheme.muted)
                }
            } compactLeading: {
                Circle()
                    .fill(WidgetTheme.color(fromHex: context.state.parkAccentHex))
                    .frame(width: 6, height: 6)
            } compactTrailing: {
                if let w = context.state.currentWait {
                    Text("\(w)M")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.tone(for: w))
                } else {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(WidgetTheme.amber)
                }
            } minimal: {
                if let w = context.state.currentWait {
                    Text("\(w)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.tone(for: w))
                } else {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(WidgetTheme.amber)
                }
            }
            .keylineTint(WidgetTheme.color(fromHex: context.state.parkAccentHex))
        }
    }

    @ViewBuilder
    private func lockScreenView(for state: InLineAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(WidgetTheme.color(fromHex: state.parkAccentHex))
                    .frame(width: 6, height: 6)
                    .shadow(color: WidgetTheme.color(fromHex: state.parkAccentHex), radius: 3)
                Text("IN LINE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(WidgetTheme.muted)
                Spacer()
                Text("QUEUEBUDDY")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.dim)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(state.attractionName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WidgetTheme.text)
                    .lineLimit(1)
                Spacer()
                if let w = state.currentWait {
                    Text("\(w)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.tone(for: w))
                    + Text(" MIN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.tone(for: w).opacity(0.8))
                } else {
                    Text("--")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.muted)
                }
            }

            Divider().background(WidgetTheme.muted.opacity(0.2))

            HStack {
                Text("JOINED \(elapsedString(since: state.startedAt).uppercased()) AGO")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.muted)
                Spacer()
                Text("UPDATED \(elapsedString(since: state.lastUpdatedAt).uppercased()) AGO")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.dim)
            }
        }
        .padding(14)
    }
}

@available(iOS 16.2, *)
private func elapsedString(since unixSeconds: Double) -> String {
    let elapsed = max(0, Int(Date().timeIntervalSince1970 - unixSeconds))
    if elapsed < 60 { return "\(elapsed)s" }
    let mins = elapsed / 60
    if mins < 60 { return "\(mins)m" }
    return "\(mins / 60)h \(mins % 60)m"
}
#endif

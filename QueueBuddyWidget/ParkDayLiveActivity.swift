import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
import WidgetKit

// MARK: - Attributes

/// Live Activity content for "a park day" — the lock-screen + Dynamic Island
/// tile showing your next-up favorite wait plus the park identity.
struct ParkDayAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var parkId: Int
        var parkName: String
        var parkAccentHex: UInt32
        var primaryName: String
        var primaryWait: Int?
        var primaryIsOpen: Bool
        var secondaryLines: [String]  // short "Ride · 12 MIN" strings
        var updatedAt: Date
    }

    var sessionName: String
}

// MARK: - Live Activity

@available(iOS 16.1, *)
struct ParkDayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ParkDayAttributes.self) { context in
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
                        Text(context.state.parkName)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(WidgetTheme.muted)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let w = context.state.primaryWait {
                        Text("\(w) MIN")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(WidgetTheme.tone(for: w))
                    } else {
                        Text(context.state.primaryIsOpen ? "OPEN" : "CLSD")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(WidgetTheme.muted)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.primaryName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WidgetTheme.text)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(context.state.secondaryLines.prefix(2), id: \.self) { line in
                            Text(line)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(WidgetTheme.muted)
                                .lineLimit(1)
                        }
                    }
                }
            } compactLeading: {
                Circle()
                    .fill(WidgetTheme.color(fromHex: context.state.parkAccentHex))
                    .frame(width: 6, height: 6)
            } compactTrailing: {
                if let w = context.state.primaryWait {
                    Text("\(w)M")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.tone(for: w))
                } else {
                    Text(context.state.primaryIsOpen ? "•" : "×")
                        .foregroundStyle(WidgetTheme.muted)
                }
            } minimal: {
                if let w = context.state.primaryWait {
                    Text("\(w)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.tone(for: w))
                } else {
                    Image(systemName: "sparkles")
                        .foregroundStyle(WidgetTheme.amber)
                }
            }
            .keylineTint(WidgetTheme.color(fromHex: context.state.parkAccentHex))
        }
    }

    @ViewBuilder
    private func lockScreenView(for state: ParkDayAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(WidgetTheme.color(fromHex: state.parkAccentHex))
                    .frame(width: 6, height: 6)
                    .shadow(color: WidgetTheme.color(fromHex: state.parkAccentHex), radius: 3)
                Text(state.parkName.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.muted)
                Spacer()
                Text("QUEUEBUDDY")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(WidgetTheme.dim)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(state.primaryName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WidgetTheme.text)
                    .lineLimit(1)
                Spacer()
                if let w = state.primaryWait {
                    Text("\(w)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.tone(for: w))
                    + Text(" MIN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.tone(for: w).opacity(0.8))
                } else {
                    Text(state.primaryIsOpen ? "OPEN" : "CLOSED")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.muted)
                }
            }

            if !state.secondaryLines.isEmpty {
                Divider().background(WidgetTheme.muted.opacity(0.2))
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(state.secondaryLines.prefix(3), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(WidgetTheme.muted)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
    }
}
#endif

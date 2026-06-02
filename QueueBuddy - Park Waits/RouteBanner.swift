import SwiftUI

/// Pinned banner that fades in at the top of the app when the Claude
/// routing engine has rerouted the user. Tap to jump to the suggested
/// attraction on the Map tab; tap the × to dismiss.
///
/// Mirrors the lock-screen Live Activity treatment: park-accent tint,
/// "REROUTE" mono header, message body, → next destination line.
struct RouteBanner: View {
    let decision: RouteDecision
    let parkId: Int
    let parkName: String
    let onDismiss: () -> Void

    private var accent: Color { DB.accent(for: parkId) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Text("REROUTE")
                    .font(DB.mono(10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(accent)
                Text("·")
                    .font(DB.mono(10, weight: .semibold))
                    .foregroundStyle(DB.dim)
                Text(parkName.uppercased())
                    .font(DB.mono(10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(DB.muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DB.muted)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss rerouting suggestion")
            }

            Text(decision.lockScreenMessage)
                .font(DB.heading(14, weight: .semibold))
                .foregroundStyle(DB.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent)
                Text(decision.nextDestination.attractionName.uppercased())
                    .font(DB.mono(11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(DB.text)
                    .lineLimit(1)
                Spacer(minLength: 6)
                MonoLabel(
                    text: "\(decision.nextDestination.expectedWaitMinutes) MIN",
                    color: accent,
                    tracking: 1.2,
                    size: 10
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DB.card.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accent.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        )
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { findOnMap() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to find this attraction on the map")
    }

    private func findOnMap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        var info: [String: Any] = ["parkId": parkId]
        if let aid = Int(decision.nextDestination.attractionId) {
            info["attractionId"] = aid
        }
        NotificationCenter.default.post(name: .openMapTab,
                                        object: nil,
                                        userInfo: info)
        onDismiss()
    }
}

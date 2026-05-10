import SwiftUI

/// Departure-board attraction row. Name + land/type metadata on the left,
/// wait chip on the right. Uses the land's route color when provided.
struct AttractionRowCardView: View {
    let attraction: Attraction
    var routeColor: Color? = nil
    var showMetaLine: Bool = true
    @EnvironmentObject var viewModel: WaitTimeViewModel

    private var isClosed: Bool {
        attraction.is_open == false ||
        attraction.status?.lowercased() == "closed" ||
        attraction.status?.lowercased() == "down"
    }

    private var metaLine: String {
        var parts: [String] = []
        if let type = attraction.type, !type.isEmpty {
            parts.append(type.uppercased())
        }
        if let minHeight = attraction.min_height_inches, minHeight > 0 {
            parts.append("\(minHeight)\"+")
        }
        return parts.joined(separator: " · ")
    }

    private var isHot: Bool {
        guard let wait = attraction.wait_time, attraction.is_open == true else { return false }
        return wait >= 60
    }

    private var trendDelta: Int? {
        WaitHistoryStore.shared.recentTrend(for: attraction.id)
    }

    private var trendArrow: (symbol: String, color: Color)? {
        guard attraction.is_open == true, !isClosed else { return nil }
        guard let delta = trendDelta else { return nil }
        if delta >= 5 { return ("arrow.up.right", DB.red) }
        if delta <= -5 { return ("arrow.down.right", DB.green) }
        return nil
    }

    private var sparklineSamples: [WaitHistoryStore.Sample] {
        WaitHistoryStore.shared.history(for: attraction.id)
    }

    private var sparklineTone: Color {
        guard !isClosed else { return DB.muted }
        return DB.waitTone(for: attraction.wait_time)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let routeColor {
                RouteStripe(color: routeColor, width: 14)
            }

            AttractionGlyph(
                attractionId: attraction.id,
                attractionType: attraction.type,
                tint: routeColor ?? DB.amber,
                size: 26
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if isHot {
                        Text("▲")
                            .font(DB.mono(13, weight: .bold))
                            .foregroundStyle(DB.red)
                    }
                    Text(attraction.name)
                        .font(DB.heading(15, weight: .medium))
                        .foregroundStyle(DB.text)
                        .tracking(-0.2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if showMetaLine && !metaLine.isEmpty {
                    Text(metaLine)
                        .font(DB.mono(10))
                        .tracking(1.5)
                        .foregroundStyle(DB.muted)
                }
            }

            Spacer(minLength: 8)

            if let trend = trendArrow {
                Image(systemName: trend.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(trend.color)
                    .accessibilityLabel(trend.symbol.contains("up") ? "Wait rising" : "Wait dropping")
            }

            if sparklineSamples.count >= 3 {
                MiniSparkline(samples: sparklineSamples, tone: sparklineTone)
                    .frame(width: 44, height: 18)
            }

            WaitChip(
                wait: attraction.wait_time,
                isOpen: attraction.is_open ?? true,
                status: attraction.status
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .opacity(isClosed ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var rowAccessibilityLabel: String {
        var parts = [attraction.name]
        if isClosed {
            parts.append("Closed")
        } else if let wait = attraction.wait_time {
            parts.append(wait == 0 ? "Walk-on" : "\(wait) minute wait")
        }
        if let type = attraction.type { parts.append(type) }
        if let trend = trendArrow {
            parts.append(trend.symbol.contains("up") ? "wait rising" : "wait dropping")
        }
        if let minH = attraction.min_height_inches, minH > 0 {
            parts.append("minimum height \(minH) inches")
        }
        return parts.joined(separator: ", ")
    }
}

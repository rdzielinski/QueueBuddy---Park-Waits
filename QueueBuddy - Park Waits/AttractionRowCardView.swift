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

            WaitChip(
                wait: attraction.wait_time,
                isOpen: attraction.is_open ?? true,
                status: attraction.status
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .opacity(isClosed ? 0.55 : 1)
    }
}

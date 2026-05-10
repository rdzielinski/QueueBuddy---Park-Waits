import SwiftUI

/// Departure-board park row: route stripe, glyph, name, open-count + avg wait,
/// and a small flap-digit on the trailing edge showing the avg.
struct ParkCardView: View {
    let park: Park
    @EnvironmentObject var viewModel: WaitTimeViewModel

    private var accent: Color { DB.accent(for: park.id) }

    private var openCount: Int { viewModel.operatingAttractionCount(for: park.id) }

    private var avgWaitValue: Int? {
        guard let attractions = viewModel.attractionsByPark[park.id], !attractions.isEmpty else { return nil }
        let waits = attractions.compactMap { $0.wait_time }
        guard !waits.isEmpty else { return nil }
        return waits.reduce(0, +) / waits.count
    }

    private var isClosed: Bool { viewModel.isParkLikelyClosed(parkId: park.id) }

    private var hoursLine: String? {
        guard let hours = StaticData.parkHours[park.id] else { return nil }
        let now = Date()
        let cal = Calendar.current
        let currentHour = cal.component(.hour, from: now)
        let currentMin = cal.component(.minute, from: now)
        let nowMinutes = currentHour * 60 + currentMin
        let openMinutes = hours.openHour * 60
        let closeMinutes = hours.closeHour * 60

        func formatHour(_ h: Int) -> String {
            let twelve = ((h % 12) == 0) ? 12 : (h % 12)
            let suffix = h >= 12 && h < 24 ? "PM" : "AM"
            return "\(twelve) \(suffix)"
        }

        if nowMinutes < openMinutes {
            return "OPENS \(formatHour(hours.openHour))"
        } else if nowMinutes < closeMinutes {
            return "OPEN UNTIL \(formatHour(hours.closeHour))"
        } else {
            return "CLOSED FOR THE DAY"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Route stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 12)
                .shadow(color: accent.opacity(0.6), radius: 8)

            // Glyph — custom silhouette per park
            ParkGlyph(parkId: park.id, tint: accent, size: 36)

            // Name + status line
            VStack(alignment: .leading, spacing: 4) {
                Text(park.name)
                    .font(DB.heading(17))
                    .foregroundStyle(DB.text)
                    .tracking(-0.3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if isClosed {
                    HStack(spacing: 6) {
                        Circle().fill(DB.muted).frame(width: 5, height: 5)
                        Text("CLOSED TODAY")
                            .font(DB.mono(11))
                            .tracking(1.2)
                            .foregroundStyle(DB.muted)
                    }
                } else {
                    HStack(spacing: 10) {
                        HStack(spacing: 5) {
                            Circle().fill(DB.green).frame(width: 5, height: 5)
                                .shadow(color: DB.green, radius: 3)
                            Text("\(openCount) OPEN")
                                .foregroundStyle(DB.green)
                        }
                        Text("·").foregroundStyle(DB.dim)
                        if let avg = avgWaitValue {
                            Text("AVG \(avg)M").foregroundStyle(DB.muted)
                        } else {
                            Text("AVG --").foregroundStyle(DB.muted)
                        }
                    }
                    .font(DB.mono(11))
                    .tracking(1.2)
                }

                if let hoursLine, !isClosed {
                    Text(hoursLine)
                        .font(DB.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(DB.dim)
                }
            }

            Spacer(minLength: 8)

            // Trailing flap digits
            FlapDigits(value: isClosed ? nil : avgWaitValue, size: 36, tone: accent, label: "AVG")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DB.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    private var cardAccessibilityLabel: String {
        var parts = [park.name]
        if isClosed {
            parts.append("Closed today")
        } else {
            parts.append("\(openCount) attractions open")
            if let avg = avgWaitValue { parts.append("average wait \(avg) minutes") }
        }
        if let hoursLine { parts.append(hoursLine) }
        return parts.joined(separator: ", ")
    }
}

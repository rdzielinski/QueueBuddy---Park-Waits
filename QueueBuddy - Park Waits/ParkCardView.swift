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

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Route stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 12)
                .shadow(color: accent.opacity(0.6), radius: 8)

            // Glyph
            Image(systemName: DB.glyph(for: park.id))
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)

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
    }
}

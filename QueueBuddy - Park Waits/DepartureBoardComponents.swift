import SwiftUI

// MARK: - FlapDigits
// Split-flap board numerals. 2-char display, monospaced, with a subtle
// horizontal split line and tone-tinted glow. Pass nil to show "--".

struct FlapDigits: View {
    let value: Int?
    var size: CGFloat = 48
    var tone: Color = DB.amber
    var label: String? = "MIN"

    private var digits: [Character] {
        let txt: String
        if let value {
            txt = String(format: "%02d", max(0, min(99, value)))
        } else {
            txt = "--"
        }
        return Array(txt)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 3) {
                ForEach(Array(digits.enumerated()), id: \.offset) { _, ch in
                    digitTile(ch)
                }
            }
            if let label {
                Text(label)
                    .font(DB.mono(max(10, size * 0.18), weight: .regular))
                    .tracking(2)
                    .foregroundStyle(DB.muted)
                    .padding(.bottom, size * 0.08)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let base: String
        if let value {
            if value == 0 { base = "Walk-on" }
            else { base = "\(value) minute" + (value == 1 ? "" : "s") }
        } else {
            base = "Not available"
        }
        if let label, label.lowercased() != "min" {
            return "\(base), \(label.lowercased())"
        }
        return base + " wait"
    }

    private func digitTile(_ ch: Character) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: 0x121317), Color(hex: 0x0B0C0F)],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            Text(String(ch))
                .font(.system(size: size * 0.72, weight: .bold, design: .monospaced))
                .foregroundStyle(tone)
                .tracking(-1)
                .shadow(color: tone.opacity(0.5), radius: size * 0.18)

            // Center split line
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(height: 1)
        }
        .frame(width: size * 0.62, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.08, style: .continuous))
    }
}

// MARK: - WaitChip
// Pill showing live wait time with a glowing LED dot. Handles Closed, Show
// (wait==nil while open), and numeric states.

struct WaitChip: View {
    let wait: Int?
    let isOpen: Bool
    let status: String?
    var style: Style = .small

    enum Style { case small, large }

    private var isClosed: Bool {
        isOpen == false ||
        status?.lowercased() == "closed" ||
        status?.lowercased() == "down"
    }

    var body: some View {
        Group {
            if isClosed {
                label(text: "Closed", tone: DB.muted)
                    .background(
                        Capsule().fill(Color.white.opacity(0.04))
                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    )
            } else if wait == nil {
                label(text: "Show", tone: DB.amber)
                    .background(
                        Capsule().fill(DB.amber.opacity(0.10))
                            .overlay(Capsule().stroke(DB.amber.opacity(0.30), lineWidth: 1))
                    )
            } else {
                activeChip
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if isClosed { return "Closed" }
        guard let wait else { return "Show attraction" }
        if wait == 0 { return "Walk-on, no wait" }
        return "\(wait) minute" + (wait == 1 ? "" : "s") + " wait"
    }

    @ViewBuilder
    private var activeChip: some View {
        let tone = DB.waitTone(for: wait)
        HStack(spacing: style == .large ? 10 : 8) {
            Circle()
                .fill(tone)
                .frame(width: style == .large ? 8 : 6,
                       height: style == .large ? 8 : 6)
                .shadow(color: tone, radius: style == .large ? 4 : 3)
            Text("\(wait ?? 0)")
                .font(DB.mono(style == .large ? 18 : 13, weight: .bold))
                .foregroundStyle(tone)
            Text("MIN")
                .font(DB.mono(style == .large ? 11 : 10, weight: .regular))
                .tracking(style == .large ? 1.5 : 1.0)
                .foregroundStyle(tone.opacity(0.8))
        }
        .padding(.vertical, style == .large ? 8 : 5)
        .padding(.horizontal, style == .large ? 14 : 10)
        .background(
            Capsule().fill(tone.opacity(0.08))
                .overlay(Capsule().stroke(tone.opacity(0.28), lineWidth: 1))
        )
    }

    private func label(text: String, tone: Color) -> some View {
        Text(text.uppercased())
            .font(DB.mono(11, weight: .regular))
            .tracking(1.5)
            .foregroundStyle(tone)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
    }
}

// MARK: - RouteStripe
// Small LED + track decoration used next to section labels.

struct RouteStripe: View {
    let color: Color
    var width: CGFloat = 40

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color, radius: 4)
            Rectangle()
                .fill(color.opacity(0.7))
                .frame(width: width, height: 2)
        }
    }
}

// MARK: - StatusStrip
// "● LIVE · X/Y OPEN · UPD 2 min ago" line under the park header.

struct StatusStrip: View {
    let openCount: Int
    let total: Int
    let updatedText: String

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Circle()
                    .fill(DB.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: DB.green, radius: 3)
                Text("LIVE").tracking(1.5)
            }
            Text("·").foregroundStyle(DB.dim)
            Text("\(openCount)/\(total) OPEN").tracking(1.5)
            Text("·").foregroundStyle(DB.dim)
            Text("UPD \(updatedText)").tracking(1.5)
        }
        .font(DB.mono(11, weight: .regular))
        .foregroundStyle(DB.muted)
    }
}

// MARK: - MonoLabel
// Reusable UPPERCASE monospaced label — "→ NEXT DEPARTURES · FOR YOU".

struct MonoLabel: View {
    let text: String
    var color: Color = DB.muted
    var tracking: CGFloat = 2
    var size: CGFloat = 12

    var body: some View {
        Text(text.uppercased())
            .font(DB.mono(size))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

// MARK: - WeatherIcon
// Maps an OpenMeteo icon code (like "01d", "10d") to an SF Symbol.

struct WeatherIcon: View {
    let iconCode: String
    var size: CGFloat = 18
    var color: Color = DB.amber

    private var symbol: String {
        switch iconCode {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.stars.fill"
        case "02d": return "cloud.sun.fill"
        case "02n": return "cloud.moon.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d", "10n": return "cloud.rain.fill"
        case "11d", "11n": return "cloud.bolt.rain.fill"
        case "13d", "13n": return "cloud.snow.fill"
        case "50d", "50n": return "cloud.fog.fill"
        default:            return "cloud.fill"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

// MARK: - OfflineBanner
// Small "NO SIGNAL · last sync X min ago" strip shown when offline.

struct OfflineBanner: View {
    let lastSyncText: String?

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(DB.amber)
                .frame(width: 6, height: 6)
                .shadow(color: DB.amber, radius: 4)
            MonoLabel(text: "NO SIGNAL", color: DB.amber, tracking: 1.8, size: 11)
            if let lastSyncText {
                Text("· last sync \(lastSyncText)")
                    .font(DB.mono(11))
                    .foregroundStyle(DB.muted)
            } else {
                Text("· awaiting data")
                    .font(DB.mono(11))
                    .foregroundStyle(DB.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DB.amber.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DB.amber.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sparkline
// Minimal area-fill line chart of the last 24 hours of wait samples.

struct Sparkline: View {
    let samples: [WaitHistoryStore.Sample]
    let tone: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let values = samples.map { CGFloat($0.minutes) }
            let maxVal = max(values.max() ?? 60, 20)
            let minVal: CGFloat = 0
            let range = max(maxVal - minVal, 1)
            let pts = values.enumerated().map { idx, v -> CGPoint in
                let x = values.count <= 1 ? width : (CGFloat(idx) / CGFloat(values.count - 1)) * width
                let y = height - ((v - minVal) / range) * height
                return CGPoint(x: x, y: y)
            }

            ZStack {
                // Fill
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: CGPoint(x: first.x, y: height))
                    for point in pts { p.addLine(to: point) }
                    p.addLine(to: CGPoint(x: pts.last?.x ?? width, y: height))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [tone.opacity(0.3), tone.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                // Line
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    for point in pts.dropFirst() { p.addLine(to: point) }
                }
                .stroke(tone, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let last = pts.last {
                    Circle()
                        .fill(tone)
                        .frame(width: 6, height: 6)
                        .position(last)
                        .shadow(color: tone, radius: 4)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let last = samples.last else { return "No wait history yet" }
        if let first = samples.first {
            let delta = last.minutes - first.minutes
            let dir = delta > 0 ? "up" : (delta < 0 ? "down" : "flat")
            return "Wait history trending \(dir), now \(last.minutes) minutes"
        }
        return "Now \(last.minutes) minutes"
    }
}

// MARK: - ErrorBanner

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DB.red)
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(DB.text)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DB.red.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DB.red.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

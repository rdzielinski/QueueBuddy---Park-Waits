import SwiftUI

/// Departure-Board design tokens. Dark transit-board aesthetic with
/// monospaced data, route-colored accents per park, and LED-style pills.
enum DB {
    // MARK: - Colors

    static let bg      = Color(hex: 0x0A0B0D)
    static let card    = Color(hex: 0x141519)
    static let card2   = Color(hex: 0x1B1D22)
    static let line    = Color.white.opacity(0.08)

    static let text    = Color(hex: 0xF4F3EE)
    static let muted   = Color(hex: 0xF4F3EE).opacity(0.55)
    static let dim     = Color(hex: 0xF4F3EE).opacity(0.35)

    // Wait-time tiers
    static let amber   = Color(hex: 0xFFB547)
    static let green   = Color(hex: 0x7FD4A0)
    static let red     = Color(hex: 0xFF6B6B)

    // MARK: - Type scale

    /// Large iOS-style title (Parks., park name on detail, hero ride name).
    static func displayTitle(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    /// Section titles / card names.
    static func heading(_ size: CGFloat = 17, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Data labels, UPPERCASE with letter-spacing — the "transit board" voice.
    static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Big chunky monospaced numeral — e.g. inside flap digits, stat tiles.
    static func monoNumeral(_ size: CGFloat = 28, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: - Park palette

    /// Per-park accent color, from the Departure Board design. Fallback is amber.
    static func accent(for parkId: Int) -> Color {
        Color(hex: accentHexValue(for: parkId))
    }

    /// Raw hex value for the park accent, for use in shared caches (widget/watch)
    /// where `Color` can't be serialized directly.
    static func accentHexValue(for parkId: Int) -> UInt32 {
        switch parkId {
        case 6:   return 0x6FA8FF // Magic Kingdom — castle blue
        case 5:   return 0xC8B8FF // EPCOT — sphere lavender
        case 7:   return 0xFF8C7A // Hollywood Studios — reel coral
        case 8:   return 0x7FD4A0 // Animal Kingdom — tree green
        case 65:  return 0xFFB547 // Universal Studios FL — globe amber
        case 64:  return 0xFF6B6B // Islands of Adventure — lighthouse red
        case 334: return 0xB583FF // Epic Universe — portal violet
        default:  return 0xFFB547
        }
    }

    /// Short park code shown as "TERMINAL · XX" on the detail header.
    static func terminalCode(for parkId: Int) -> String {
        switch parkId {
        case 6:   return "MK"
        case 5:   return "EP"
        case 7:   return "HS"
        case 8:   return "AK"
        case 65:  return "USF"
        case 64:  return "IOA"
        case 334: return "EU"
        default:  return "--"
        }
    }

    /// SF Symbol used as the park glyph on cards.
    static func glyph(for parkId: Int) -> String {
        switch parkId {
        case 6:   return "building.columns.fill"
        case 5:   return "globe.americas.fill"
        case 7:   return "film.fill"
        case 8:   return "leaf.fill"
        case 65:  return "star.circle.fill"
        case 64:  return "lighthouse.fill"
        case 334: return "sparkles"
        default:  return "circle.grid.cross.fill"
        }
    }

    // MARK: - Wait-time color tier

    static func waitTone(for wait: Int?) -> Color {
        guard let wait else { return amber }
        switch wait {
        case ...15: return green
        case ...45: return amber
        default:    return red
        }
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double(hex         & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

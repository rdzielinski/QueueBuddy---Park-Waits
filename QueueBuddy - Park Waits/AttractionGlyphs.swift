import SwiftUI

// MARK: - Custom SwiftUI silhouettes
//
// Hand-drawn shapes for the most iconic attractions and park icons. Each
// shape is normalized into a 100×100 rectangle so it scales cleanly to
// any frame.

// ── Attraction silhouettes ──────────────────────────────────────────

/// A stylized castle silhouette (five spires over a base wall), good for
/// Cinderella Castle, Hogwarts Castle, or any castle-themed landmark.
struct CastleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = CGSize(width: rect.width / 100, height: rect.height / 100)
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * s.width, y: rect.minY + y * s.height)
        }
        // Base wall
        p.move(to: pt(10, 95))
        p.addLine(to: pt(10, 55))
        p.addLine(to: pt(22, 55))
        p.addLine(to: pt(22, 42))
        // Flag spike on small left tower
        p.addLine(to: pt(20, 42))
        p.addLine(to: pt(20, 32))
        p.addLine(to: pt(25, 32))
        p.addLine(to: pt(25, 42))
        p.addLine(to: pt(30, 42))
        p.addLine(to: pt(30, 55))
        p.addLine(to: pt(38, 55))
        // Center tall tower
        p.addLine(to: pt(38, 35))
        p.addLine(to: pt(44, 35))
        p.addLine(to: pt(44, 18))
        p.addLine(to: pt(50, 5))
        p.addLine(to: pt(56, 18))
        p.addLine(to: pt(56, 35))
        p.addLine(to: pt(62, 35))
        p.addLine(to: pt(62, 55))
        // Right small tower
        p.addLine(to: pt(70, 55))
        p.addLine(to: pt(70, 42))
        p.addLine(to: pt(75, 42))
        p.addLine(to: pt(75, 32))
        p.addLine(to: pt(80, 32))
        p.addLine(to: pt(80, 42))
        p.addLine(to: pt(78, 42))
        p.addLine(to: pt(78, 55))
        p.addLine(to: pt(90, 55))
        p.addLine(to: pt(90, 95))
        p.closeSubpath()

        // Small door rectangle inset
        p.move(to: pt(42, 95))
        p.addLine(to: pt(42, 75))
        p.addCurve(to: pt(58, 75), control1: pt(42, 68), control2: pt(58, 68))
        p.addLine(to: pt(58, 95))
        p.closeSubpath()
        return p
    }
}

/// Geodesic-ish sphere — a circle with a few diamond facets to read as
/// Spaceship Earth at small sizes.
struct GeodesicSphereShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Outer circle
        p.addEllipse(in: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08))
        // Facets — crisscross to suggest panels
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width * 0.42
        for step in stride(from: -r, through: r, by: r * 0.35) {
            p.move(to: CGPoint(x: c.x + step, y: c.y - r))
            p.addLine(to: CGPoint(x: c.x + step, y: c.y + r))
        }
        for step in stride(from: -r, through: r, by: r * 0.35) {
            p.move(to: CGPoint(x: c.x - r, y: c.y + step))
            p.addLine(to: CGPoint(x: c.x + r, y: c.y + step))
        }
        return p
    }
}

/// Tree silhouette with wide, wispy canopy. Stands in for Tree of Life,
/// Animal Kingdom, Swiss Family Treehouse.
struct TreeCanopyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = CGSize(width: rect.width / 100, height: rect.height / 100)
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * s.width, y: rect.minY + y * s.height)
        }
        // Trunk
        p.move(to: pt(44, 95))
        p.addLine(to: pt(44, 55))
        p.addLine(to: pt(56, 55))
        p.addLine(to: pt(56, 95))
        p.closeSubpath()
        // Canopy — two overlapping blobs
        p.addEllipse(in: CGRect(x: pt(8, 20).x, y: pt(8, 20).y,
                                width: 55 * s.width, height: 45 * s.height))
        p.addEllipse(in: CGRect(x: pt(38, 12).x, y: pt(12, 12).y,
                                width: 55 * s.width, height: 48 * s.height))
        return p
    }
}

/// Tall narrow tower — Tower of Terror. Square top with antenna.
struct TowerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = CGSize(width: rect.width / 100, height: rect.height / 100)
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * s.width, y: rect.minY + y * s.height)
        }
        // Base
        p.move(to: pt(18, 95))
        p.addLine(to: pt(18, 78))
        p.addLine(to: pt(32, 78))
        p.addLine(to: pt(32, 30))
        p.addLine(to: pt(68, 30))
        p.addLine(to: pt(68, 78))
        p.addLine(to: pt(82, 78))
        p.addLine(to: pt(82, 95))
        p.closeSubpath()
        // Roof cap
        p.move(to: pt(30, 30))
        p.addLine(to: pt(50, 15))
        p.addLine(to: pt(70, 30))
        p.closeSubpath()
        // Antenna
        p.move(to: pt(49, 15))
        p.addLine(to: pt(49, 5))
        p.addLine(to: pt(51, 5))
        p.addLine(to: pt(51, 15))
        p.closeSubpath()
        // Window
        p.addRect(CGRect(x: pt(45, 48).x, y: pt(48, 48).y,
                         width: 10 * s.width, height: 14 * s.height))
        return p
    }
}

/// Mountain peaks — Big Thunder, Expedition Everest, Space Mountain.
struct MountainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = CGSize(width: rect.width / 100, height: rect.height / 100)
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * s.width, y: rect.minY + y * s.height)
        }
        p.move(to: pt(5, 88))
        p.addLine(to: pt(30, 40))
        p.addLine(to: pt(45, 62))
        p.addLine(to: pt(62, 20))
        p.addLine(to: pt(78, 55))
        p.addLine(to: pt(95, 88))
        p.closeSubpath()
        // Snow caps
        p.move(to: pt(25, 48))
        p.addLine(to: pt(30, 40))
        p.addLine(to: pt(35, 48))
        p.addLine(to: pt(33, 52))
        p.addLine(to: pt(27, 52))
        p.closeSubpath()
        p.move(to: pt(56, 30))
        p.addLine(to: pt(62, 20))
        p.addLine(to: pt(68, 30))
        p.addLine(to: pt(65, 34))
        p.addLine(to: pt(59, 34))
        p.closeSubpath()
        return p
    }
}

/// Coaster loop — a generic inverted loop track for coasters. Works as a
/// thrill-ride badge.
struct CoasterLoopShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Track rails — stroke these from the outside
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.minY + rect.height * 0.82))
        p.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.95, y: rect.minY + rect.height * 0.82),
            control1: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.0),
            control2: CGPoint(x: rect.minX + rect.width * 0.85, y: rect.minY + rect.height * 0.0)
        )
        // Support posts
        for x in [0.25, 0.5, 0.75] {
            let topY = rect.minY + rect.height * 0.82 - rect.height * 0.05
            p.move(to: CGPoint(x: rect.minX + rect.width * x, y: topY))
            p.addLine(to: CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * 0.92))
        }
        return p
    }
}

/// Rocket — Space Mountain, Mission: SPACE.
struct RocketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = CGSize(width: rect.width / 100, height: rect.height / 100)
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * s.width, y: rect.minY + y * s.height)
        }
        // Body
        p.move(to: pt(50, 5))
        p.addLine(to: pt(65, 30))
        p.addLine(to: pt(65, 75))
        p.addLine(to: pt(75, 88))
        p.addLine(to: pt(60, 85))
        p.addLine(to: pt(55, 95))
        p.addLine(to: pt(45, 95))
        p.addLine(to: pt(40, 85))
        p.addLine(to: pt(25, 88))
        p.addLine(to: pt(35, 75))
        p.addLine(to: pt(35, 30))
        p.closeSubpath()
        // Window
        p.addEllipse(in: CGRect(x: pt(42, 42).x, y: pt(42, 42).y,
                                width: 16 * s.width, height: 16 * s.height))
        return p
    }
}

/// Swirled portal — Epic Universe gateway.
struct PortalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) * 0.42
        for i in 0..<4 {
            let inset = r * (1.0 - Double(i) * 0.22)
            p.addEllipse(in: CGRect(x: c.x - inset, y: c.y - inset,
                                    width: inset * 2, height: inset * 2))
        }
        // center dot
        p.addEllipse(in: CGRect(x: c.x - r * 0.08, y: c.y - r * 0.08,
                                width: r * 0.16, height: r * 0.16))
        return p
    }
}

/// Sailboat hull — Pirates of the Caribbean, Jungle Cruise.
struct SailboatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = CGSize(width: rect.width / 100, height: rect.height / 100)
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * s.width, y: rect.minY + y * s.height)
        }
        // Hull
        p.move(to: pt(10, 72))
        p.addLine(to: pt(90, 72))
        p.addLine(to: pt(80, 88))
        p.addLine(to: pt(20, 88))
        p.closeSubpath()
        // Mast
        p.move(to: pt(48, 72))
        p.addLine(to: pt(48, 15))
        p.addLine(to: pt(52, 15))
        p.addLine(to: pt(52, 72))
        p.closeSubpath()
        // Sail
        p.move(to: pt(52, 20))
        p.addLine(to: pt(80, 60))
        p.addLine(to: pt(52, 60))
        p.closeSubpath()
        p.move(to: pt(48, 28))
        p.addLine(to: pt(28, 60))
        p.addLine(to: pt(48, 60))
        p.closeSubpath()
        return p
    }
}

/// Pyramid — Revenge of the Mummy.
struct PyramidShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = CGSize(width: rect.width / 100, height: rect.height / 100)
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * s.width, y: rect.minY + y * s.height)
        }
        p.move(to: pt(50, 10))
        p.addLine(to: pt(90, 85))
        p.addLine(to: pt(10, 85))
        p.closeSubpath()
        // Horizontal course lines
        for y in [30.0, 50.0, 70.0] {
            let inset = (y - 10) * 0.53
            p.move(to: pt(50 - inset, y))
            p.addLine(to: pt(50 + inset, y))
        }
        return p
    }
}

/// Carousel horse body — generic carousel attractions.
struct CarouselShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = CGSize(width: rect.width / 100, height: rect.height / 100)
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * s.width, y: rect.minY + y * s.height)
        }
        // Canopy
        p.move(to: pt(10, 30))
        p.addLine(to: pt(50, 8))
        p.addLine(to: pt(90, 30))
        p.closeSubpath()
        // Roof peak
        p.addRect(CGRect(x: pt(48, 4).x, y: pt(4, 4).y,
                         width: 4 * s.width, height: 6 * s.height))
        // Base circle
        p.move(to: pt(15, 30))
        p.addLine(to: pt(85, 30))
        p.addLine(to: pt(85, 80))
        p.addLine(to: pt(15, 80))
        p.closeSubpath()
        // Pole
        p.addRect(CGRect(x: pt(48, 30).x, y: pt(0, 30).y,
                         width: 4 * s.width, height: 50 * s.height))
        return p
    }
}

// ── Glyph view ──────────────────────────────────────────────────────

/// Decides which shape or SF Symbol to use for an attraction. Order:
/// 1. Custom `Shape` silhouette for iconic rides (via `customGlyph`).
/// 2. Per-ID SF Symbol from `StaticData.attractionSymbolOverrides`.
/// 3. Type-based SF Symbol fallback.
struct AttractionGlyph: View {
    let attractionId: Int
    let attractionType: String?
    var tint: Color = DB.amber
    var size: CGFloat = 24

    var body: some View {
        if let shape = Self.customShape(for: attractionId) {
            shape
                .fill(tint)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: StaticData.symbol(for: attractionId, type: attractionType))
                .font(.system(size: size * 0.75, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    static func customShape(for id: Int) -> AnyShape? {
        switch id {
        // Castles
        case 13763, 5992, 6682, 5991:      return AnyShape(CastleShape())
        // Spaceship Earth
        case 159:                          return AnyShape(GeodesicSphereShape())
        // Trees
        case 13751, 355:                   return AnyShape(TreeCanopyShape())
        // Towers
        case 123:                          return AnyShape(TowerShape())
        // Mountains
        case 110, 14533, 130, 138, 129:    return AnyShape(MountainShape())
        // Rockets
        case 158, 248:                     return AnyShape(RocketShape())
        // Portals
        case 14690, 14740:                 return AnyShape(PortalShape())
        // Sailboats
        case 137, 134, 1187, 466:          return AnyShape(SailboatShape())
        // Pyramid
        case 6022:                         return AnyShape(PyramidShape())
        // Carousels — Constellation Carousel included here so it gets the
        // carousel shape instead of the portal shape.
        case 161, 5986, 14688:             return AnyShape(CarouselShape())
        // Signature coasters
        case 8721, 13109, 11527, 13605, 6004: return AnyShape(CoasterLoopShape())
        default: return nil
        }
    }
}

// ── Park glyph view ─────────────────────────────────────────────────

/// Park-level silhouette. Castles, spheres, trees — park icons that read
/// as the park, not generic SF Symbols.
struct ParkGlyph: View {
    let parkId: Int
    var tint: Color
    var size: CGFloat = 40

    var body: some View {
        shape
            .fill(tint)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var shape: AnyShape {
        switch parkId {
        case 6:   return AnyShape(CastleShape())             // Magic Kingdom
        case 5:   return AnyShape(GeodesicSphereShape())     // EPCOT — Spaceship Earth
        case 7:   return AnyShape(TowerShape())              // Hollywood Studios
        case 8:   return AnyShape(TreeCanopyShape())         // Animal Kingdom
        case 64:  return AnyShape(CastleShape())             // IOA — Hogwarts Castle stand-in
        case 65:  return AnyShape(GeodesicSphereShape())     // USF — Universal globe
        case 334: return AnyShape(PortalShape())             // Epic Universe
        default:  return AnyShape(GeodesicSphereShape())
        }
    }
}

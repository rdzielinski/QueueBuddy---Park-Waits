//
//  ParkMapView.swift
//  Theme park map with live wait-time overlays in the Departure Board style.
//
//  Drop this file into your project and present it like:
//
//      ParkMapView(parkId: 7, attractions: liveAttractions)
//
//  Requires iOS 17+ for the new MapKit content-builder syntax.
//

import SwiftUI
import MapKit

// MARK: - Wait Time Bucket
//
// Mirrors DB.waitTone's three-tier breakpoints (≤15 green, ≤45 amber,
// >45 red) so the map speaks the same color language as every other
// surface in the app.

enum WaitBucket: Int, CaseIterable {
    case short      // 0–15 min
    case medium     // 16–45 min
    case long       // 46+ min
    case unknown    // no wait / closed

    init(minutes: Int?) {
        guard let m = minutes else { self = .unknown; return }
        switch m {
        case ...15:  self = .short
        case ...45:  self = .medium
        default:     self = .long
        }
    }

    var color: Color {
        switch self {
        case .short:   return DB.green
        case .medium:  return DB.amber
        case .long:    return DB.red
        case .unknown: return DB.muted
        }
    }

    var label: String {
        switch self {
        case .short:   return "SHORT"
        case .medium:  return "MED"
        case .long:    return "LONG"
        case .unknown: return "—"
        }
    }
}

// MARK: - Type & Status filters

enum TypeFilter: String, CaseIterable, Identifiable {
    case attractions = "Attractions"
    case shows       = "Shows"
    case dining      = "Dining"
    var id: String { rawValue }

    /// Maps your StaticData type strings into one of these three buckets.
    static func bucket(for type: String?) -> TypeFilter {
        switch (type ?? "").lowercased() {
        case "show", "theater", "stage", "meet", "film", "3dfilm":
            return .shows
        case "restaurant", "dining":
            return .dining
        default:
            return .attractions
        }
    }
}

enum StatusFilter: String, CaseIterable, Identifiable {
    case open    = "Open"
    case down    = "Down"
    case closed  = "Closed"
    case refurb  = "Refurb"
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .open:   return DB.green
        case .down:   return DB.red
        case .closed: return DB.muted
        case .refurb: return DB.amber
        }
    }

    /// Map an `Attraction`'s status string to one of these.
    /// Matches the LiveStatusType values: OPERATING/DOWN/CLOSED/REFURBISHMENT
    static func bucket(for status: String?, isOpen: Bool) -> StatusFilter {
        switch (status ?? "").uppercased() {
        case "DOWN":           return .down
        case "REFURBISHMENT":  return .refurb
        case "CLOSED":         return .closed
        case "OPERATING":      return .open
        default:               return isOpen ? .open : .closed
        }
    }
}

// MARK: - Park Map View

struct ParkMapView: View {
    let parkId: Int
    let attractions: [Attraction]
    /// When non-nil and the attraction exists in `attractions` with a
    /// known lat/lon, the camera starts tightly framed on that pin
    /// instead of the whole-park overview. One-shot: only consulted at
    /// init, since the camera position is @State after that and the user
    /// can pan freely.
    let focusAttractionId: Int?

    @State private var selectedTypes: Set<TypeFilter> = [.attractions, .shows, .dining]
    @State private var selectedStatuses: Set<StatusFilter> = [.open]
    @State private var selectedAttraction: Attraction?
    @State private var selectedAttractionId: Int?
    @State private var cameraPosition: MapCameraPosition

    init(parkId: Int, attractions: [Attraction], focusAttractionId: Int? = nil) {
        self.parkId = parkId
        self.attractions = attractions
        self.focusAttractionId = focusAttractionId

        let focused: (lat: Double, lon: Double)? = {
            guard let fid = focusAttractionId,
                  let attraction = attractions.first(where: { $0.id == fid }),
                  let lat = attraction.latitude,
                  let lon = attraction.longitude
            else { return nil }
            return (lat, lon)
        }()

        let center: CLLocationCoordinate2D
        let span: MKCoordinateSpan
        if let f = focused {
            center = CLLocationCoordinate2D(latitude: f.lat, longitude: f.lon)
            span = MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        } else {
            center = StaticData.parkCoordinates[parkId]
                .map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                ?? CLLocationCoordinate2D(latitude: 28.4, longitude: -81.55)
            span = MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        }

        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: center, span: span
        )))
    }

    var body: some View {
        VStack(spacing: 14) {
            filterRow
            legend
            mapView
        }
        .padding(.vertical, 8)
        .sheet(item: $selectedAttraction) { attraction in
            AttractionDetailSheet(parkId: parkId, attraction: attraction)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(DB.bg)
        }
    }

    // MARK: - Filtering

    private var filteredAttractions: [Attraction] {
        attractions.filter { a in
            guard a.latitude != nil, a.longitude != nil else { return false }
            let typeOK = selectedTypes.contains(TypeFilter.bucket(for: a.type))
            let statusOK = selectedStatuses.contains(
                StatusFilter.bucket(for: a.status, isOpen: a.is_open ?? false)
            )
            return typeOK && statusOK
        }
    }

    // MARK: - Filter row
    // Single horizontal-scrolling row: type chips, a hairline divider, then
    // status chips. Replaces the previous two-row layout with explicit
    // "Filter by Type" / "Filter by Status" headers.

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TypeFilter.allCases) { type in
                    let count = attractions.filter {
                        TypeFilter.bucket(for: $0.type) == type && $0.latitude != nil
                    }.count
                    FilterChip(
                        label: type.rawValue,
                        count: count,
                        tone: DB.accent(for: parkId),
                        isOn: selectedTypes.contains(type)
                    ) { toggle(type) }
                }

                Rectangle()
                    .fill(DB.line)
                    .frame(width: 1, height: 22)
                    .padding(.horizontal, 4)

                ForEach(StatusFilter.allCases) { status in
                    let count = attractions.filter {
                        StatusFilter.bucket(for: $0.status,
                                            isOpen: $0.is_open ?? false) == status
                    }.count
                    FilterChip(
                        label: status.rawValue,
                        count: count,
                        tone: status.color,
                        isOn: selectedStatuses.contains(status)
                    ) { toggle(status) }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Legend
    // Compact single-line wait-tone key in the departure-board voice.

    private var legend: some View {
        HStack(spacing: 14) {
            MonoLabel(text: "WAITS", color: DB.muted, tracking: 2, size: 10)
            ForEach(WaitBucket.allCases.dropLast(), id: \.rawValue) { bucket in
                HStack(spacing: 5) {
                    Circle()
                        .fill(bucket.color)
                        .frame(width: 6, height: 6)
                        .shadow(color: bucket.color, radius: 3)
                    Text(bucket.label)
                        .font(DB.mono(10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(bucket.color)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    // MARK: - Map

    @ViewBuilder
    private var mapView: some View {
        Map(position: $cameraPosition, selection: $selectedAttractionId) {
            ForEach(filteredAttractions, id: \.id) { attraction in
                Annotation(
                    attraction.name,
                    coordinate: CLLocationCoordinate2D(
                        latitude: attraction.latitude!,
                        longitude: attraction.longitude!
                    ),
                    anchor: .center
                ) {
                    AttractionPin(attraction: attraction)
                        .onTapGesture { selectedAttraction = attraction }
                }
                .tag(attraction.id)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(minHeight: 400)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DB.line, lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Toggle helpers

    private func toggle(_ type: TypeFilter) {
        if selectedTypes.contains(type) { selectedTypes.remove(type) }
        else { selectedTypes.insert(type) }
        // Don't allow zero filters — re-add if empty
        if selectedTypes.isEmpty { selectedTypes = Set(TypeFilter.allCases) }
    }
    private func toggle(_ status: StatusFilter) {
        if selectedStatuses.contains(status) { selectedStatuses.remove(status) }
        else { selectedStatuses.insert(status) }
        if selectedStatuses.isEmpty { selectedStatuses = [.open] }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let count: Int
    let tone: Color
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tone)
                    .frame(width: 6, height: 6)
                    .shadow(color: tone, radius: isOn ? 3 : 0)
                Text(label.uppercased())
                    .font(DB.mono(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(isOn ? DB.text : DB.muted)
                Text(displayCount)
                    .font(DB.mono(10, weight: .bold))
                    .foregroundStyle(tone)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isOn ? tone.opacity(0.08) : Color.white.opacity(0.02))
                    .overlay(
                        Capsule()
                            .stroke(isOn ? tone.opacity(0.35) : DB.line, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var displayCount: String { count >= 99 ? "99+" : "\(count)" }
}

// MARK: - Attraction Pin
//
// LED-style pin: dark capsule/circle on the map, tone-tinted stroke,
// monospace numerals. Reads cleanly against the standard map at the
// current zoom levels.

private struct AttractionPin: View {
    let attraction: Attraction

    private var bucket: WaitBucket {
        WaitBucket(minutes: attraction.wait_time)
    }

    private var statusFilter: StatusFilter {
        StatusFilter.bucket(for: attraction.status,
                            isOpen: attraction.is_open ?? false)
    }

    var body: some View {
        if statusFilter == .open, let wait = attraction.wait_time {
            Text("\(wait)")
                .font(DB.mono(11, weight: .bold))
                .foregroundStyle(bucket.color)
                .frame(minWidth: 22, minHeight: 22)
                .padding(.horizontal, 5)
                .background(
                    Capsule()
                        .fill(DB.bg.opacity(0.92))
                        .overlay(Capsule().stroke(bucket.color.opacity(0.75), lineWidth: 1.5))
                )
                .shadow(color: bucket.color.opacity(0.5), radius: 4)
        } else {
            ZStack {
                Circle()
                    .fill(DB.bg.opacity(0.92))
                    .overlay(Circle().stroke(statusFilter.color.opacity(0.75), lineWidth: 1.5))
                Image(systemName: iconForStatus)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(statusFilter.color)
            }
            .frame(width: 26, height: 26)
            .shadow(color: statusFilter.color.opacity(0.5), radius: 4)
        }
    }

    private var iconForStatus: String {
        switch statusFilter {
        case .down:   return "exclamationmark"
        case .closed: return "xmark"
        case .refurb: return "hammer.fill"
        case .open:   return "checkmark"
        }
    }
}

// MARK: - Detail Sheet

private struct AttractionDetailSheet: View {
    let parkId: Int
    let attraction: Attraction

    private var accent: Color { DB.accent(for: parkId) }
    private var glyph: String { StaticData.symbol(for: attraction.id, type: attraction.type) }

    private var statusFilter: StatusFilter {
        StatusFilter.bucket(for: attraction.status,
                            isOpen: attraction.is_open ?? false)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                badgeRow
                liveChips

                if let desc = attraction.description, !desc.isEmpty {
                    descriptionSection(desc)
                }

                forecastSection
            }
            .padding(20)
        }
        .background(DB.bg)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RouteStripe(color: accent, width: 28)
                MonoLabel(text: "TERMINAL · \(DB.terminalCode(for: parkId))",
                          color: accent, tracking: 2, size: 11)
            }
            HStack(spacing: 12) {
                Image(systemName: glyph)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(accent.opacity(0.30), lineWidth: 1)
                            )
                    )
                Text(attraction.name)
                    .font(DB.heading(20, weight: .semibold))
                    .foregroundStyle(DB.text)
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Badge row

    private var badgeRow: some View {
        HStack(spacing: 8) {
            if statusFilter == .open {
                WaitChip(wait: attraction.wait_time,
                         isOpen: attraction.is_open ?? false,
                         status: attraction.status,
                         style: .large)
            } else {
                statusPill
            }
            if let h = attraction.min_height_inches { heightChip(h) }
            Spacer(minLength: 0)
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusFilter.color)
                .frame(width: 7, height: 7)
                .shadow(color: statusFilter.color, radius: 3)
            Text(statusFilter.rawValue.uppercased())
                .font(DB.mono(12, weight: .bold))
                .tracking(1.5)
        }
        .foregroundStyle(statusFilter.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(statusFilter.color.opacity(0.10))
                .overlay(Capsule().stroke(statusFilter.color.opacity(0.30), lineWidth: 1))
        )
    }

    private func heightChip(_ inches: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "ruler")
                .font(.system(size: 11, weight: .medium))
            Text("\(inches)\"")
                .font(DB.mono(12, weight: .bold))
        }
        .foregroundStyle(DB.muted)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.04))
                .overlay(Capsule().stroke(DB.line, lineWidth: 1))
        )
    }

    // MARK: - Live chips (operating window + Lightning Lane)

    @ViewBuilder
    private var liveChips: some View {
        let hasHours = attraction.operatingStart != nil || attraction.operatingEnd != nil
        let hasReturnTime = attraction.returnTime != nil
        if hasHours || hasReturnTime {
            HStack(spacing: 8) {
                if hasHours { operatingHoursChip }
                if hasReturnTime { returnTimeChip }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var operatingHoursChip: some View {
        let formatter = UserPreferences.timeFormatter()
        let startText = attraction.operatingStart.map { formatter.string(from: $0).lowercased() }
        let endText = attraction.operatingEnd.map { formatter.string(from: $0).lowercased() }
        let timeText: String = {
            switch (startText, endText) {
            case let (.some(s), .some(e)): return "\(s)–\(e)"
            case let (.some(s), .none):    return "from \(s)"
            case let (.none, .some(e)):    return "until \(e)"
            default:                       return ""
            }
        }()
        let closingSoon = attraction.closesSoon
        let tone: Color = closingSoon ? DB.red : DB.muted
        livePill(
            icon: closingSoon ? "clock.badge.exclamationmark" : "clock",
            text: closingSoon ? "Closes \(endText ?? "soon")" : timeText,
            tone: tone
        )
    }

    @ViewBuilder
    private var returnTimeChip: some View {
        if let rt = attraction.returnTime {
            let label: String = {
                switch rt.state {
                case .available:
                    if let start = rt.returnStart {
                        let f = UserPreferences.timeFormatter()
                        return "LL · return \(f.string(from: start).lowercased())"
                    }
                    return "LL available"
                case .temporarilyFull: return "LL paused"
                case .finished: return "LL sold out"
                }
            }()
            let tone: Color = rt.state == .available ? DB.green : DB.muted
            livePill(
                icon: rt.state == .available ? "bolt.fill" : "bolt.slash",
                text: label,
                tone: tone
            )
        }
    }

    private func livePill(icon: String, text: String, tone: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
            Text(text)
                .font(DB.mono(11, weight: .semibold))
        }
        .foregroundStyle(tone)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(tone.opacity(0.10))
                .overlay(Capsule().stroke(tone.opacity(0.30), lineWidth: 1))
        )
    }

    // MARK: - Description

    private func descriptionSection(_ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel(text: "BRIEFING", color: DB.muted, tracking: 2, size: 11)
            Text(desc)
                .font(DB.heading(15, weight: .regular))
                .foregroundStyle(DB.text.opacity(0.85))
        }
    }

    // MARK: - Forecast

    @ViewBuilder
    private var forecastSection: some View {
        if let forecast = attraction.forecast, forecast.count >= 3 {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "FORECAST · NEXT 14 HOURS",
                          color: DB.muted, tracking: 2, size: 11)
                ForecastChart(points: forecast, tone: forecastTone)
                    .frame(height: 110)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DB.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(DB.line, lineWidth: 1)
                            )
                    )
            }
        }
    }

    private var forecastTone: Color {
        guard let w = attraction.wait_time else { return DB.muted }
        return WaitBucket(minutes: w).color
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let demo: [Attraction] = [
        Attraction(id: 5476, name: "Slinky Dog Dash",
                   wait_time: 45, status: "OPERATING", is_open: true,
                   last_updated: nil, type: "coaster",
                   description: "A family-friendly coaster.",
                   min_height_inches: 38,
                   latitude: 28.356245, longitude: -81.562786),
        Attraction(id: 6369, name: "Star Wars: Rise of the Resistance",
                   wait_time: 95, status: "OPERATING", is_open: true,
                   last_updated: nil, type: "darkride",
                   description: "Join the Resistance.",
                   min_height_inches: 40,
                   latitude: 28.355100, longitude: -81.559200),
        Attraction(id: 117, name: "Toy Story Mania!",
                   wait_time: 25, status: "OPERATING", is_open: true,
                   last_updated: nil, type: "shooter",
                   description: nil, min_height_inches: nil,
                   latitude: 28.359000, longitude: -81.560000),
        Attraction(id: 119, name: "Rock 'n' Roller Coaster",
                   wait_time: nil, status: "REFURBISHMENT", is_open: false,
                   last_updated: nil, type: "coaster",
                   description: nil, min_height_inches: 48,
                   latitude: 28.357500, longitude: -81.557400),
    ]
    return ParkMapView(parkId: 7, attractions: demo)
        .preferredColorScheme(.dark)
        .background(DB.bg)
}
#endif

// MARK: - iOS 16 fallback note
//
// If you need to support iOS 16 and earlier, replace the `mapView` body with:
//
//   Map(coordinateRegion: $region, annotationItems: filteredAttractions) { a in
//       MapAnnotation(coordinate: CLLocationCoordinate2D(
//           latitude: a.latitude!, longitude: a.longitude!)) {
//           AttractionPin(attraction: a)
//               .onTapGesture { selectedAttraction = a }
//       }
//   }
//
// where `region` is an @State MKCoordinateRegion. The pin/legend/filter views
// below the map work identically on both.

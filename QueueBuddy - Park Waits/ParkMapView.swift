//
//  ParkMapView.swift
//  Theme park map with live wait-time overlays.
//
//  Drop this file into your project and present it like:
//
//      ParkMapView(parkId: 7, attractions: liveAttractions)
//
//  Requires iOS 17+ for the new MapKit content-builder syntax. If you need
//  iOS 16 support, see the legacy Map() init noted at the bottom of the file.
//

import SwiftUI
import MapKit

// MARK: - Wait Time Bucket

/// Wait-time category that drives marker color. Mirrors the buckets used on
/// themeparks.wiki's interactive map (Short / Medium / Long / Very Long).
enum WaitBucket: Int, CaseIterable {
    case short      // 0-29 min
    case medium     // 30-59 min
    case long       // 60-89 min
    case veryLong   // 90+ min
    case unknown    // no wait time / closed

    init(minutes: Int?) {
        guard let m = minutes else { self = .unknown; return }
        switch m {
        case ..<30:  self = .short
        case 30..<60: self = .medium
        case 60..<90: self = .long
        default:     self = .veryLong
        }
    }

    var color: Color {
        switch self {
        case .short:    return .green
        case .medium:   return .blue
        case .long:     return Color(red: 0.55, green: 0.30, blue: 0.85) // purple
        case .veryLong: return .red
        case .unknown:  return .gray
        }
    }

    var label: String {
        switch self {
        case .short: "Short"
        case .medium: "Medium"
        case .long: "Long"
        case .veryLong: "Very Long"
        case .unknown: "—"
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
        case .open:   .green
        case .down:   .red
        case .closed: .gray
        case .refurb: .orange
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

    @State private var selectedTypes: Set<TypeFilter> = [.attractions, .shows, .dining]
    @State private var selectedStatuses: Set<StatusFilter> = [.open]
    @State private var selectedAttraction: Attraction?
    @State private var cameraPosition: MapCameraPosition

    init(parkId: Int, attractions: [Attraction]) {
        self.parkId = parkId
        self.attractions = attractions
        // Center camera on the park
        let center = StaticData.parkCoordinates[parkId]
            .map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            ?? CLLocationCoordinate2D(latitude: 28.4, longitude: -81.55)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )))
    }

    var body: some View {
        VStack(spacing: 12) {
            filterBar
            legendStrip
            mapView
        }
        .padding(.vertical, 8)
        .sheet(item: $selectedAttraction) { attraction in
            AttractionDetailSheet(attraction: attraction)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Subviews

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

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(.secondary)
                Text("Filter by Type").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(TypeFilter.allCases) { type in
                    let count = attractions.filter {
                        TypeFilter.bucket(for: $0.type) == type && $0.latitude != nil
                    }.count
                    FilterChip(
                        label: type.rawValue.uppercased(),
                        count: count,
                        isOn: selectedTypes.contains(type),
                        countColor: countColorForType(type)
                    ) { toggle(type) }
                }
            }

            HStack {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(.secondary)
                Text("Filter by Status").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(StatusFilter.allCases) { status in
                    let count = attractions.filter {
                        StatusFilter.bucket(for: $0.status,
                                            isOpen: $0.is_open ?? false) == status
                    }.count
                    FilterChip(
                        label: status.rawValue.uppercased(),
                        count: count,
                        isOn: selectedStatuses.contains(status),
                        countColor: status.color
                    ) { toggle(status) }
                }
            }
        }
        .padding(.horizontal)
    }

    private var legendStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            ForEach(WaitBucket.allCases.dropLast(), id: \.rawValue) { bucket in
                HStack(spacing: 4) {
                    Circle().fill(bucket.color).frame(width: 8, height: 8)
                    Text(bucket.label + " Wait")
                        .font(.caption2)
                        .foregroundStyle(bucket.color)
                }
            }
        }
        .padding(.horizontal)
    }

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
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .frame(minHeight: 400)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // Selection state for Map's selection binding (separate from sheet state)
    @State private var selectedAttractionId: Int?

    // MARK: - Helpers

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
    private func countColorForType(_ type: TypeFilter) -> Color {
        switch type {
        case .attractions: .blue
        case .shows:       .purple
        case .dining:      .orange
        }
    }
}

// MARK: - Pin View

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
            // Wait-time badge — colored circle with the number
            ZStack {
                Circle()
                    .fill(bucket.color)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                Text("\(wait)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)
        } else {
            // Status pin for closed/down/refurb attractions
            ZStack {
                Circle()
                    .fill(statusFilter.color)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                Image(systemName: iconForStatus)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)
        }
    }

    private var iconForStatus: String {
        switch statusFilter {
        case .down:   "exclamationmark"
        case .closed: "xmark"
        case .refurb: "hammer.fill"
        case .open:   "checkmark"
        }
    }
}

// MARK: - Detail Sheet

private struct AttractionDetailSheet: View {
    let attraction: Attraction

    private var forecastTone: Color {
        guard let w = attraction.wait_time else { return .gray }
        return WaitBucket(minutes: w).color
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                badgeRow
                liveChips

                if let desc = attraction.description, !desc.isEmpty {
                    Text(desc)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                forecastSection

                if let lat = attraction.latitude, let lon = attraction.longitude {
                    Link(destination: URL(string:
                        "https://maps.apple.com/?ll=\(lat),\(lon)&q=\(attraction.name.urlEncoded)")!
                    ) {
                        Label("Open in Maps", systemImage: "map")
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: StaticData.symbol(for: attraction.id, type: attraction.type))
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
            Text(attraction.name)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
        }
    }

    private var badgeRow: some View {
        HStack(spacing: 8) {
            StatusBadge(status: attraction.status,
                        isOpen: attraction.is_open ?? false)
            if let wait = attraction.wait_time {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("\(wait) min")
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(.tertiary))
            }
            if let h = attraction.min_height_inches {
                HStack(spacing: 4) {
                    Image(systemName: "ruler")
                    Text("\(h)\"")
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(.tertiary))
            }
        }
    }

    /// Live operating window and Lightning Lane / return-time chips, drawn
    /// from the ThemeParks.wiki live payload. Hidden when neither applies
    /// (e.g. queue-times parks still in fallback mode).
    @ViewBuilder
    private var liveChips: some View {
        let hasHours = attraction.operatingStart != nil || attraction.operatingEnd != nil
        let hasReturnTime = attraction.returnTime != nil
        if hasHours || hasReturnTime {
            HStack(spacing: 8) {
                if hasHours { operatingHoursChip }
                if hasReturnTime { returnTimeChip }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var operatingHoursChip: some View {
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mma"
            return f
        }()
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
        let tone: Color = closingSoon ? .red : .primary
        HStack(spacing: 4) {
            Image(systemName: closingSoon ? "clock.badge.exclamationmark" : "clock")
            Text(closingSoon ? "Closes \(endText ?? "soon")" : timeText)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(tone)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(closingSoon ? Color.red.opacity(0.15) : Color.secondary.opacity(0.15)))
    }

    @ViewBuilder
    private var returnTimeChip: some View {
        if let rt = attraction.returnTime {
            let label: String = {
                switch rt.state {
                case .available:
                    if let start = rt.returnStart {
                        let f = DateFormatter()
                        f.dateFormat = "h:mma"
                        return "LL · return \(f.string(from: start).lowercased())"
                    }
                    return "LL available"
                case .temporarilyFull: return "LL paused"
                case .finished: return "LL sold out"
                }
            }()
            let tone: Color = rt.state == .available ? .green : .secondary
            HStack(spacing: 4) {
                Image(systemName: rt.state == .available ? "bolt.fill" : "bolt.slash")
                Text(label)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tone)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(tone.opacity(0.15)))
        }
    }

    /// 14-hour hourly forecast chart, when the API gave us one. We
    /// already render this on the full detail view; on the map sheet it
    /// gives a "should I bother walking over there?" answer at a glance.
    @ViewBuilder
    private var forecastSection: some View {
        if let forecast = attraction.forecast, forecast.count >= 3 {
            VStack(alignment: .leading, spacing: 8) {
                Text("FORECAST · NEXT 14 HOURS")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                ForecastChart(points: forecast, tone: forecastTone)
                    .frame(height: 110)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
            }
        }
    }
}

private struct StatusBadge: View {
    let status: String?
    let isOpen: Bool

    var body: some View {
        let f = StatusFilter.bucket(for: status, isOpen: isOpen)
        HStack(spacing: 4) {
            Circle().fill(f.color).frame(width: 8, height: 8)
            Text(f.rawValue.uppercased())
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(f.color.opacity(0.15)))
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let count: Int
    let isOn: Bool
    let countColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption.weight(.semibold))
                Text(displayCount)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(countColor))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary.opacity(0.3)),
                            lineWidth: isOn ? 2 : 1)
            )
            .opacity(isOn ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
    }

    private var displayCount: String { count >= 99 ? "99+" : "\(count)" }
}

// MARK: - Helpers

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
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

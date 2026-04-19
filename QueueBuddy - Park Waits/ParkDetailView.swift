import SwiftUI
import MapKit
import CoreLocation

extension Park {
    var coordinate: CLLocationCoordinate2D? {
        StaticData.parkCoordinates[self.id].map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }
}

struct ParkDetailView: View {
    @EnvironmentObject private var viewModel: WaitTimeViewModel
    @Environment(\.dismiss) private var dismiss
    let park: Park

    @State private var selectedFilter: AttractionFilter = .all
    @State private var attractionForNotification: Attraction?
    @State private var tipIndex: Int = 0
    @State private var landOverrides: [String: Bool] = [:]

    private var accent: Color { DB.accent(for: park.id) }
    private var landOverridesKey: String { "landOverrides-\(park.id)" }

    private let parkTips: [Int: [String]] = [
        6: [
            "Rope drop Tiana's Bayou Adventure or Seven Dwarfs Mine Train — both spike fast after 10 AM.",
            "TRON Lightcycle / Run dropped its virtual queue in late 2024; now just a standard standby line.",
            "Use Lightning Lane Multi Pass for Space Mountain and Big Thunder to save an hour.",
            "Grab a Dole Whip in Adventureland — the stand by Swiss Family Treehouse moves faster than the Pineapple Lanai.",
            "Catch Country Bear Musical Jamboree in Frontierland — the 2024 reboot is a fresh take worth seeing.",
            "If you see Villains Land construction walls near Frontierland — that's for the 2027 expansion."
        ],
        5: [
            "Test Track's 2025 retro redesign reopened last summer — morning is the only time the line is short.",
            "Guardians: Cosmic Rewind is still standby + Lightning Lane (virtual queue retired).",
            "World Showcase opens at 11 AM — do Future World rides first, then grab lunch in Mexico or Japan.",
            "Remy's Ratatouille Adventure has a single rider line right next to standby — use it.",
            "The Journey of Water walk-through in front of The Seas is great in late afternoon heat.",
            "Best fireworks spot for Luminous is the Japan or Italy pavilion waterfront."
        ],
        7: [
            "Rise of the Resistance rope drops as low as 30 minutes if you're at the turnstile by 30 min before open.",
            "Mickey & Minnie's Runaway Railway and Slinky Dog Dash are the Lightning Lane priority — book first.",
            "Grab a Ronto Wrap at Ronto Roasters in Galaxy's Edge — best quick service in the park.",
            "Tower of Terror and Rock 'n' Roller Coaster both have single rider — use it for Rock 'n' Roller Coaster.",
            "The new Fantasmic! returned in 2023 — arrive 45 min early for a center seat.",
            "Muppet*Vision 3D closed June 2025; that plot is slated to become the Monsters Inc. land."
        ],
        8: [
            "Flight of Passage still has the longest wait in the park — rope drop or ride after 9 PM.",
            "Na'vi River Journey is best in late morning when the Flight of Passage crowd clears.",
            "Kilimanjaro Safaris pays off most at park open and at dusk when animals are active.",
            "DinoLand is closing in phases — catch DINOSAUR before it's gone for the Tropical Americas retheme.",
            "Rivers of Light ended, but Festival of the Lion King is still the showstopper — arrive 20 min early.",
            "Refill water bottles at the station near Expedition Everest — it's the quickest fill in the park."
        ],
        64: [
            "Hagrid's Magical Creatures Motorbike Adventure is shortest first thing or during the nighttime show.",
            "VelociCoaster single rider moves fast and usually saves 40+ minutes at peak.",
            "Incredible Hulk's single rider is reliably shorter than standby on busy days.",
            "Jurassic Park River Adventure is the best afternoon cool-down — you will get soaked.",
            "Cast a spell with your interactive wand in Hogsmeade — the Dervish and Banges scene is often empty."
        ],
        65: [
            "Diagon Alley is magical after dark — save it for the evening and catch the dragon's fire.",
            "Gringotts and the Mummy both have single rider lines that move quickly.",
            "The Mega Movie Parade runs most afternoons — check the Universal app for today's showtime.",
            "Ollivanders in Diagon Alley can have a 30-40 min wait; the Hogsmeade one is usually shorter.",
            "Butterbeer ice cream at Florean Fortescue's is better than the frozen Butterbeer — don't @ me."
        ],
        334: [
            "Stardust Racers in Celestial Park is the headliner — rope drop or hit it after 9 PM.",
            "Harry Potter and the Battle at the Ministry uses a virtual queue on busy days — join it the moment you scan in.",
            "Mine-Cart Madness in Donkey Kong Country has a single rider queue that's often a 10-min wait.",
            "Super Nintendo World is busiest 12-5 — swap for Dark Universe or Isle of Berk midday.",
            "Curse of the Werewolf is a hybrid coaster/dark ride — single rider line saves 30+ minutes.",
            "The Celestial Park nighttime fountain show is a hidden gem — grab a spot 20 min early."
        ]
    ]

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func currentTip() -> String? {
        guard let tips = parkTips[park.id], !tips.isEmpty else { return nil }
        return tips[tipIndex % tips.count]
    }

    private func personalizedRecommendations() -> [Attraction] {
        guard let attractions = viewModel.attractionsByPark[park.id] else { return [] }
        let open = attractions.filter { $0.is_open == true }
        return Array(open
            .filter { ($0.wait_time ?? 1000) < 30 }
            .sorted { ($0.wait_time ?? Int.max) < ($1.wait_time ?? Int.max) }
            .prefix(3))
    }

    private func isLandExpanded(_ landName: String) -> Bool {
        if let override = landOverrides[landName] { return override }
        return !StaticData.isSeasonalLand(landName)
    }

    private func toggleLand(_ landName: String) {
        let newValue = !isLandExpanded(landName)
        landOverrides[landName] = newValue
        if let data = try? JSONEncoder().encode(landOverrides) {
            UserDefaults.standard.set(data, forKey: landOverridesKey)
        }
        triggerHaptic()
    }

    private func loadLandOverrides() {
        if let data = UserDefaults.standard.data(forKey: landOverridesKey),
           let dict = try? JSONDecoder().decode([String: Bool].self, from: data) {
            landOverrides = dict
        }
    }

    /// Order ride-centric lands first and seasonal ones last, each by name.
    private func sortedLandGroups() -> [LandDisplayGroup] {
        let groups = viewModel.attractionsByLand(for: park.id)
        return groups.sorted { a, b in
            let sa = StaticData.isSeasonalLand(a.name)
            let sb = StaticData.isSeasonalLand(b.name)
            if sa != sb { return !sa }
            return a.name < b.name
        }
    }

    private func landColor(for name: String) -> Color {
        // Simple stable hash → hue mapping so each land reads distinct.
        let h = abs(name.hashValue) % 360
        return Color(hue: Double(h) / 360.0, saturation: 0.55, brightness: 0.92)
    }

    var body: some View {
        ZStack {
            DB.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    navRow
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    terminalHeader
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)

                    let recs = personalizedRecommendations()
                    if !recs.isEmpty {
                        recommendationsBlock(recs)
                            .padding(.bottom, 22)
                    }

                    let landGroups = sortedLandGroups()
                    if landGroups.isEmpty && !viewModel.isLoading {
                        emptyLands
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(landGroups) { group in
                            landBlock(group)
                                .padding(.bottom, 18)
                        }
                    }

                    Color.clear.frame(height: 100)
                }
            }
            .refreshable {
                async let weather: Void = viewModel.fetchWeather(for: park)
                async let waits: Void = viewModel.refreshPark(park)
                _ = await (weather, waits)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $attractionForNotification) { attraction in
            NotificationSettingView(attraction: attraction)
                .environmentObject(viewModel)
        }
        .task {
            await viewModel.fetchWeather(for: park)
        }
        .onAppear {
            loadLandOverrides()
            viewModel.activeParkId = park.id
        }
        .onDisappear {
            if viewModel.activeParkId == park.id {
                viewModel.activeParkId = nil
            }
        }
    }

    // MARK: - Sections

    private var navRow: some View {
        HStack {
            Button {
                triggerHaptic()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Text("‹")
                    Text("PARKS").tracking(1.5)
                }
                .font(DB.mono(12, weight: .regular))
                .foregroundStyle(DB.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.white.opacity(0.05))
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(AttractionFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("☰")
                    Text("FILTER").tracking(1.5)
                }
                .font(DB.mono(12, weight: .regular))
                .foregroundStyle(DB.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.white.opacity(0.05))
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
            }
        }
    }

    private var terminalHeader: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DB.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .overlay(
                    RadialGradient(
                        colors: [accent.opacity(0.15), .clear],
                        center: .topLeading,
                        startRadius: 0, endRadius: 260
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    RouteStripe(color: accent, width: 28)
                    Text("TERMINAL · \(DB.terminalCode(for: park.id))")
                        .font(DB.mono(11))
                        .tracking(2)
                        .foregroundStyle(accent)
                }
                Text(park.name)
                    .font(DB.displayTitle(30))
                    .foregroundStyle(DB.text)
                    .tracking(-0.6)
                    .lineLimit(2)
                    .padding(.bottom, 8)

                StatusStrip(
                    openCount: viewModel.operatingAttractionCount(for: park.id),
                    total: viewModel.attractionsByPark[park.id]?.count ?? 0,
                    updatedText: freshestUpdateText
                )

                HStack(spacing: 10) {
                    weatherCard
                    tipCard
                }
                .padding(.top, 14)
            }
            .padding(18)
        }
    }

    private var weatherCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                MonoLabel(text: "WX", color: DB.muted, tracking: 1.5, size: 10)
                Spacer()
                if let wx = viewModel.weatherByPark[park.id] {
                    WeatherIcon(iconCode: wx.icon, size: 14, color: accent)
                }
            }
            if let wx = viewModel.weatherByPark[park.id] {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(wx.temperature))°")
                        .font(DB.mono(22, weight: .bold))
                        .foregroundStyle(DB.text)
                    Text("F")
                        .font(DB.mono(13))
                        .foregroundStyle(DB.muted)
                }
                Text(wx.description.capitalized)
                    .font(DB.mono(11))
                    .foregroundStyle(DB.muted)
                    .lineLimit(1)
            } else {
                Text("--°")
                    .font(DB.mono(22, weight: .bold))
                    .foregroundStyle(DB.muted)
                Text("Loading…")
                    .font(DB.mono(11))
                    .foregroundStyle(DB.dim)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DB.card2)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private var freshestUpdateText: String {
        let attractions = viewModel.attractionsByPark[park.id] ?? []
        let dates = attractions.compactMap { $0.last_updated }
            .compactMap { ISO8601DateFormatter().date(from: $0) }
        guard let newest = dates.max() else { return "live" }
        let mins = Int(Date().timeIntervalSince(newest) / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins/60)h ago"
    }

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                MonoLabel(text: "● TIP OF THE HOUR", color: DB.amber, tracking: 1.5, size: 10)
                Spacer()
                Button {
                    tipIndex += 1
                    triggerHaptic()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                        .foregroundStyle(DB.amber)
                }
                .buttonStyle(.plain)
            }
            if let tip = currentTip() {
                Text(tip)
                    .font(.system(size: 12))
                    .foregroundStyle(DB.text)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DB.card2)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private func recommendationsBlock(_ recs: [Attraction]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel(text: "→ NEXT DEPARTURES · FOR YOU", color: DB.muted)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(recs.enumerated()), id: \.element.id) { idx, attraction in
                    NavigationLink(value: attraction) {
                        AttractionRowCardView(
                            attraction: attraction,
                            routeColor: accent,
                            showMetaLine: true
                        )
                    }
                    .buttonStyle(.plain)
                    if idx < recs.count - 1 {
                        Rectangle().fill(DB.line).frame(height: 1)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DB.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
        }
    }

    private func landBlock(_ group: LandDisplayGroup) -> some View {
        let isSeasonal = StaticData.isSeasonalLand(group.name)
        let expanded = isLandExpanded(group.name)
        let color = landColor(for: group.name)
        let filtered = group.attractions
            .sorted {
                let aOpen = $0.is_open == true
                let bOpen = $1.is_open == true
                if aOpen != bOpen { return aOpen }
                return ($0.wait_time ?? Int.max) < ($1.wait_time ?? Int.max)
            }
            .filter { a in
                switch selectedFilter {
                case .all: return true
                case .operating: return a.is_open == true
                case .shortWait: return (a.wait_time ?? 1000) < 20
                case .moderateWait:
                    guard let w = a.wait_time else { return false }
                    return w >= 20 && w <= 60
                case .longWait: return (a.wait_time ?? 0) > 60
                }
            }

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                toggleLand(group.name)
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .shadow(color: color, radius: 4)
                    Text(group.name.uppercased())
                        .font(DB.mono(12))
                        .tracking(2)
                        .foregroundStyle(DB.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isSeasonal {
                        Text("SEASONAL")
                            .font(DB.mono(9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(DB.amber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(DB.amber.opacity(0.12))
                            )
                    }
                    Spacer()
                    Text("\(filtered.count)")
                        .font(DB.mono(11))
                        .foregroundStyle(DB.dim)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.15), value: expanded)
                        .foregroundStyle(DB.dim)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            if expanded {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, attraction in
                        NavigationLink(value: attraction) {
                            AttractionRowCardView(
                                attraction: attraction,
                                routeColor: color,
                                showMetaLine: true
                            )
                        }
                        .buttonStyle(.plain)
                        #if !os(tvOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                viewModel.toggleFavorite(attractionId: attraction.id)
                                triggerHaptic()
                            } label: {
                                Label(
                                    viewModel.isFavorited(attractionId: attraction.id) ? "Unfavorite" : "Favorite",
                                    systemImage: viewModel.isFavorited(attractionId: attraction.id) ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                attractionForNotification = attraction
                                triggerHaptic()
                            } label: {
                                Label("Notify", systemImage: "bell.fill")
                            }
                            .tint(.purple)
                        }
                        #endif

                        if idx < filtered.count - 1 {
                            Rectangle().fill(DB.line).frame(height: 1)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(DB.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
            }
        }
    }

    private var emptyLands: some View {
        VStack(spacing: 10) {
            MonoLabel(text: "● NO ATTRACTIONS", color: DB.muted)
            Text("We couldn't find live attractions for this park right now.")
                .font(.system(size: 13))
                .foregroundStyle(DB.muted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DB.card)
        )
    }
}

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
    @StateObject private var planStore = ParkDayPlanStore.shared
    let park: Park

    @State private var selectedFilter: AttractionFilter = .all
    @State private var selectedTypeFilter: AttractionTypeFilter = .all
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
            "Construction walls can change walkway patterns near Frontierland — check the map before crossing the park.",
            "PeopleMover is the easiest reset in the park — 10 min, AC-cooled, almost never a wait.",
            "Carousel of Progress is fully air-conditioned and a quiet 21-minute break midday.",
            "Pirates of the Caribbean and Haunted Mansion drop hardest right at open and during fireworks.",
            "Mickey's PhilharMagic is the best rainy-day pick — short wait, big show.",
            "Be Our Guest is signature-only now; book at the 60-day mark or skip it.",
            "Liberty Tree Tavern's all-you-care-to-eat Thanksgiving plate is the sleeper meal of the park.",
            "Watch fireworks from the Tomorrowland walkway by Astro Orbiter — clearer view, fewer crowds than the hub.",
            "Walt Disney World Railroad reopened in 2023 — full loop is 20 min and a fast way to swap lands."
        ],
        5: [
            "Test Track is easiest early in the morning before Future World crowds settle in.",
            "Guardians: Cosmic Rewind is still standby + Lightning Lane (virtual queue retired).",
            "World Showcase opens at 11 AM — do Future World rides first, then grab lunch in Mexico or Japan.",
            "Remy's Ratatouille Adventure has a single rider line right next to standby — use it.",
            "The Journey of Water walk-through in front of The Seas is great in late afternoon heat.",
            "Best fireworks spot for Luminous is the Japan or Italy pavilion waterfront.",
            "Frozen Ever After in Norway is World Showcase's longest wait — hit it the second the showcase opens.",
            "Mission: SPACE Orange spins; Green is the family version. Don't pick wrong by accident.",
            "Living with the Land is a quiet 14-minute boat ride and the best midday AC break in Future World.",
            "Soarin' is most comfortable from row 1 — row 3 can be queasy for some riders.",
            "Festival kiosks rotate by season — Food & Wine (Aug-Nov) is the busiest by a wide margin.",
            "Connections Cafe has the best Future World seating for a long sit — quieter than Sunshine Seasons.",
            "The Imagination! pavilion is dated, but Figment merch and the ride remain a cult favorite.",
            "Ride Spaceship Earth in the last 30 min of the day — it's almost always a walk-on."
        ],
        7: [
            "Rise of the Resistance rope drops as low as 30 minutes if you're at the turnstile by 30 min before open.",
            "Mickey & Minnie's Runaway Railway and Slinky Dog Dash are the Lightning Lane priority — book first.",
            "Grab a Ronto Wrap at Ronto Roasters in Galaxy's Edge — best quick service in the park.",
            "Tower of Terror and Rock 'n' Roller Coaster both have single rider — use it for Rock 'n' Roller Coaster.",
            "The new Fantasmic! returned in 2023 — arrive 45 min early for a center seat.",
            "Animation Courtyard and nearby show spaces can shift as Hollywood Studios changes — check same-day show listings.",
            "Tower of Terror randomizes its drop sequence — every ride feels different.",
            "Star Tours randomizes its destination, so re-rides aren't repeats.",
            "Smugglers Run lets you pick your role at the console; pilot has the best view.",
            "Toy Story Mania is rarely longer than 25 min after 7 PM — save it for the evening.",
            "Indiana Jones Stunt Spectacular still runs daily; sit in the back rows for shade.",
            "Sci-Fi Dine-In is the most uniquely themed table service in the park — book at 60 days out.",
            "Walt Disney Presents has rare quiet AC seating and a small interactive walk-through.",
            "Beauty and the Beast Sing-Along (Theater of the Stars) is a hidden morning show worth catching."
        ],
        8: [
            "Flight of Passage still has the longest wait in the park — rope drop or ride after 9 PM.",
            "Na'vi River Journey is best in late morning when the Flight of Passage crowd clears.",
            "Kilimanjaro Safaris pays off most at park open and at dusk when animals are active.",
            "Animal Kingdom construction phases can change walking routes — check the park map before crossing to the back of the park.",
            "Rivers of Light ended, but Festival of the Lion King is still the showstopper — arrive 20 min early.",
            "Refill water bottles at the station near Expedition Everest — it's the quickest fill in the park.",
            "Expedition Everest typically drops below 30 min after 4 PM — wait it out instead of riding at open.",
            "Maharajah Jungle Trek is best early — animals retreat to shade once the sun's high.",
            "Pandora at night is unmissable — bioluminescent walkways come alive ~30 min after sunset.",
            "Discovery Island Trails are usually empty and have authentic peacock encounters.",
            "Tiffins on Discovery Island is the best signature dining at AK — book early.",
            "Festival of the Lion King's first show of the day is least crowded.",
            "Park closes earlier than other Disney parks — plan dinner offsite or at Disney Springs.",
            "Tree of Life animal carvings are scattered along Discovery Island — bring a flashlight at dusk."
        ],
        64: [
            "Hagrid's Magical Creatures Motorbike Adventure is shortest first thing or during the nighttime show.",
            "VelociCoaster single rider moves fast and usually saves 40+ minutes at peak.",
            "Incredible Hulk's single rider is reliably shorter than standby on busy days.",
            "Jurassic Park River Adventure is the best afternoon cool-down — you will get soaked.",
            "Cast a spell with your interactive wand in Hogsmeade — the Dervish and Banges scene is often empty.",
            "Hogwarts Express is one-way only — you need a Park-to-Park ticket for both directions.",
            "Forbidden Journey is one of the most under-appreciated dark rides in Orlando — ride at least once.",
            "Skull Island: Reign of Kong has elaborate queue theming — go even if the ride itself is just OK.",
            "Bluto's Bilge-Rat Barges is the wetter water ride at IOA — bring a poncho or extra clothes.",
            "Cat in the Hat in Seuss Landing is a quick AC break and a great toddler pick.",
            "Storm Force Accelatron rarely has a wait; solid spinner for kids near Hulk.",
            "Doctor Doom's Fearfall is often a walk-on after dinner — the drop tower most people skip.",
            "Three Broomsticks shepherd's pie is the best Wizarding World quick service meal.",
            "Hogsmeade gets festive in winter — check for the holiday show projection on the castle."
        ],
        65: [
            "Diagon Alley is magical after dark — save it for the evening and catch the dragon's fire.",
            "Gringotts and the Mummy both have single rider lines that move quickly.",
            "The Mega Movie Parade runs most afternoons — check the Universal app for today's showtime.",
            "Ollivanders in Diagon Alley can have a 30-40 min wait; the Hogsmeade one is usually shorter.",
            "Butterbeer ice cream at Florean Fortescue's is better than the frozen Butterbeer — don't @ me.",
            "E.T. Adventure is the park's last original opening-day ride — short wait and a strong nostalgia hit.",
            "The Bourne Stuntacular is a 30-min indoor show that's a perfect midday cooldown.",
            "King's Cross photo op has zero wait first thing in the morning — go before Diagon opens.",
            "Animal Actors on Location is a relaxing seated show and a guaranteed AC break.",
            "Knockturn Alley has hidden interactive wand spots — most guests miss them entirely.",
            "Fast & Furious: Supercharged is widely considered the weakest queue payoff — skip if pressed for time.",
            "Florean Fortescue's gets a line for ice cream by 1 PM — go before noon.",
            "Revenge of the Mummy is rarely over 30 min after 5 PM — let the morning crowd thin out.",
            "Race Through New York Starring Jimmy Fallon's queue room has a working barbershop quartet."
        ],
        334: [
            "Stardust Racers in Celestial Park is the headliner — rope drop or hit it after 9 PM.",
            "Harry Potter and the Battle at the Ministry uses a virtual queue on busy days — join it the moment you scan in.",
            "Mine-Cart Madness in Donkey Kong Country has a single rider queue that's often a 10-min wait.",
            "Super Nintendo World is busiest 12-5 — swap for Dark Universe or Isle of Berk midday.",
            "Curse of the Werewolf is a hybrid coaster/dark ride — single rider line saves 30+ minutes.",
            "The Celestial Park nighttime fountain show is a hidden gem — grab a spot 20 min early.",
            "The Battle at the Ministry queue uses an elevator system — the queue itself is part of the show.",
            "Power-Up Bands at Super Nintendo World are sold separately and required for interactive elements.",
            "Dragon Racer's Rally is dual-track; the right side has sharper banking than the left.",
            "Yoshi's Adventure is family-friendly with great views down into Bowser's Castle.",
            "Mario Kart's AR queue is best experienced wearing a Power-Up Band — without one you miss half the layer.",
            "Stella Nova in Celestial Park rotates lighting at night — different colors each hour.",
            "The Untrainable Dragon show in Isle of Berk is the strongest dedicated stage show in Orlando right now.",
            "Atlantic — the table service in Celestial Park — is the best signature dining at Epic Universe."
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

    /// Bias recommendations toward indoor rides when it's hot out.
    private var isHotOutside: Bool {
        guard let temp = viewModel.weatherByPark[park.id]?.temperature else { return false }
        return temp >= 88
    }

    private func personalizedRecommendations() -> [Attraction] {
        guard let attractions = viewModel.attractionsByPark[park.id] else { return [] }
        let open = attractions.filter { $0.is_open == true }
        let candidates = open
            .filter { ($0.wait_time ?? 1000) < 30 }
            .filter { !$0.name.localizedCaseInsensitiveContains("single rider") }
        let hot = isHotOutside
        let sorted = candidates.sorted { a, b in
            if hot {
                let aIndoor = StaticData.isLikelyIndoor(type: a.type) ? 0 : 1
                let bIndoor = StaticData.isLikelyIndoor(type: b.type) ? 0 : 1
                if aIndoor != bIndoor { return aIndoor < bIndoor }
            }
            return (a.wait_time ?? Int.max) < (b.wait_time ?? Int.max)
        }
        return Array(sorted.prefix(3))
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

    private var mapAttractions: [Attraction] {
        viewModel.attractionsByPark[park.id] ?? StaticData.getStaticAttractions(for: park.id)
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
                triggerHaptic()
            }
            .simultaneousGesture(backSwipeGesture)
        }
        .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .swipeBackEnabled()
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
                Picker("Type", selection: $selectedTypeFilter) {
                    ForEach(AttractionTypeFilter.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                Divider()
                Picker("Wait", selection: $selectedFilter) {
                    ForEach(AttractionFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("☰")
                    Text(filterLabel).tracking(1.5)
                }
                .font(DB.mono(12, weight: .regular))
                .foregroundStyle(hasActiveFilter ? accent : DB.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(hasActiveFilter ? accent.opacity(0.1) : Color.white.opacity(0.05))
                        .overlay(Capsule().stroke(hasActiveFilter ? accent.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1))
                )
            }
        }
    }

    private var hasActiveFilter: Bool {
        selectedFilter != .all || selectedTypeFilter != .all
    }

    private var filterLabel: String {
        if selectedTypeFilter != .all { return selectedTypeFilter.rawValue.uppercased() }
        if selectedFilter != .all { return selectedFilter.rawValue.uppercased() }
        return "FILTER"
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

                ViewThatFits(in: .horizontal) {
                    statusStrip(horizontal: true)
                    statusStrip(horizontal: false)
                }

                HStack(spacing: 10) {
                    if let hours = viewModel.parkHoursText(for: park.id) {
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(hours)
                        }
                        .font(DB.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(DB.muted)
                        .accessibilityLabel("Park hours \(hours)")
                    }
                    if let ee = viewModel.earlyEntryWindow(parkId: park.id) {
                        earlyEntryPill(start: ee.0)
                    }
                    if let crowd = viewModel.crowdLevel(for: park.id) {
                        crowdBadge(crowd)
                    }
                    Spacer()
                }
                .padding(.top, 4)

                lightningLaneStrip
                    .padding(.top, 8)

                parkActionRow

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        weatherCard
                        tipCard
                    }
                    VStack(spacing: 10) {
                        weatherCard
                        tipCard
                    }
                }
                .padding(.top, 14)
            }
            .padding(18)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(terminalAccessibilityLabel)
    }

    private var terminalAccessibilityLabel: String {
        var parts = [park.name]
        let open = viewModel.operatingAttractionCount(for: park.id)
        let total = viewModel.attractionsByPark[park.id]?.count ?? 0
        parts.append("\(open) of \(total) attractions open")
        if let hours = viewModel.parkHoursText(for: park.id) { parts.append("Hours \(hours)") }
        if let crowd = viewModel.crowdLevel(for: park.id) { parts.append("Crowd level \(crowd.label.lowercased())") }
        if let wx = viewModel.weatherByPark[park.id] { parts.append("\(Int(wx.temperature)) degrees, \(wx.description)") }
        return parts.joined(separator: ". ")
    }

    private var parkActionRow: some View {
        HStack(spacing: 10) {
            Button {
                let attractions = viewModel.attractionsByPark[park.id] ?? []
                planStore.addTopPicks(from: attractions, park: park)
                triggerHaptic()
            } label: {
                Label("Add Best Waits", systemImage: "wand.and.stars")
                    .font(DB.mono(11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: 0x0A0B0D))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add the shortest open waits at \(park.name) to My Day")

            NavigationLink {
                ParkMapView(parkId: park.id, attractions: mapAttractions)
                    .navigationTitle(park.name)
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                    Label("Map", systemImage: "map.fill")
                        .font(DB.mono(11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(DB.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open the \(park.name) attraction map")
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private func statusStrip(horizontal: Bool) -> some View {
        if horizontal {
            StatusStrip(
                openCount: viewModel.operatingAttractionCount(for: park.id),
                total: viewModel.attractionsByPark[park.id]?.count ?? 0,
                updatedText: freshestUpdateText
            )
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(DB.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: DB.green, radius: 3)
                    Text("LIVE").tracking(1.5)
                    Text("·").foregroundStyle(DB.dim)
                    Text("\(viewModel.operatingAttractionCount(for: park.id))/\(viewModel.attractionsByPark[park.id]?.count ?? 0) OPEN")
                        .tracking(1.5)
                }
                Text("UPD \(freshestUpdateText)")
                    .tracking(1.5)
                    .foregroundStyle(DB.muted)
            }
            .font(DB.mono(11, weight: .regular))
            .foregroundStyle(DB.muted)
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
                Text("● TIP OF THE HOUR")
                    .font(DB.mono(10))
                    .tracking(1.2)
                    .foregroundStyle(DB.amber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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

    /// "EARLY ENTRY 8:30 AM" pill shown when the park has a live Early
    /// Entry ticketed event today. Resort-guest users use this to plan
    /// arrival; everyone else gets a heads-up to skip the queue.
    private func earlyEntryPill(start: Date) -> some View {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return HStack(spacing: 4) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 10))
            Text("EARLY \(f.string(from: start).uppercased())")
        }
        .font(DB.mono(10, weight: .semibold))
        .tracking(1.2)
        .foregroundStyle(DB.amber)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(DB.amber.opacity(0.14))
                .overlay(Capsule().stroke(DB.amber.opacity(0.32), lineWidth: 1))
        )
        .accessibilityLabel("Early Entry starting at \(f.string(from: start))")
    }

    /// Horizontally-scrolling row of Lightning Lane / Genie+ purchase
    /// options for today, with live availability + pricing. Hidden when
    /// the park doesn't expose LL data (queue-times parks, or before LL
    /// goes live for the day).
    @ViewBuilder
    private var lightningLaneStrip: some View {
        let options = viewModel.lightningLane(parkId: park.id)
        if !options.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options) { option in
                        lightningLaneChip(option)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Lightning Lane options")
        }
    }

    private func lightningLaneChip(_ option: LightningLanePurchase) -> some View {
        let tone: Color = option.available ? DB.green : DB.muted
        return HStack(spacing: 6) {
            Image(systemName: option.available ? "bolt.fill" : "bolt.slash")
                .font(.system(size: 10, weight: .semibold))
            VStack(alignment: .leading, spacing: 0) {
                Text(option.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                if let price = option.priceFormatted {
                    Text(option.available ? price : "Sold out")
                        .font(.system(size: 10))
                        .foregroundStyle(tone.opacity(0.85))
                }
            }
        }
        .foregroundStyle(tone)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(tone.opacity(0.12))
                .overlay(Capsule().stroke(tone.opacity(0.3), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(option.name) \(option.available ? (option.priceFormatted ?? "available") : "sold out")")
    }

    private func crowdBadge(_ level: CrowdLevel) -> some View {
        let color = DB.crowdColor(for: level)
        return HStack(spacing: 5) {
            Image(systemName: level.symbol)
                .font(.system(size: 10))
            Text(level.label)
        }
        .font(DB.mono(10, weight: .semibold))
        .tracking(1.2)
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(color.opacity(0.12))
                .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
        )
        .accessibilityLabel("Crowd level: \(level.label.lowercased())")
    }

    private var backSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard value.startLocation.x < 32 else { return }
                guard value.translation.width > 90 else { return }
                guard abs(value.translation.height) < 80 else { return }
                triggerHaptic()
                dismiss()
            }
    }

    private func recommendationsBlock(_ recs: [Attraction]) -> some View {
        let label = isHotOutside
            ? "→ NEXT DEPARTURES · COOL & INDOOR"
            : "→ NEXT DEPARTURES · FOR YOU"
        return VStack(alignment: .leading, spacing: 10) {
            MonoLabel(text: label, color: isHotOutside ? DB.amber : DB.muted)
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
                guard selectedTypeFilter.matches(a.type) else { return false }
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
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        landHeaderTitle(group.name, color: color, isSeasonal: isSeasonal)
                        Spacer()
                        landHeaderTrailing(expanded: expanded, count: filtered.count)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        landHeaderTitle(group.name, color: color, isSeasonal: isSeasonal)
                        HStack(spacing: 8) {
                            Spacer()
                            landHeaderTrailing(expanded: expanded, count: filtered.count)
                        }
                    }
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

    @ViewBuilder
    private func landHeaderTitle(_ name: String, color: Color, isSeasonal: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color, radius: 4)
            Text(name.uppercased())
                .font(DB.mono(12))
                .tracking(2)
                .foregroundStyle(DB.text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
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
        }
    }

    private func landHeaderTrailing(expanded: Bool, count: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(count)")
                .font(DB.mono(11))
                .foregroundStyle(DB.dim)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .rotationEffect(.degrees(expanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.15), value: expanded)
                .foregroundStyle(DB.dim)
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

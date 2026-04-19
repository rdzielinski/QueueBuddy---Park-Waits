import SwiftUI

struct WatchHomeView: View {
    @State private var parks: [WatchCache.CachedPark] = []

    private var favoriteAttractions: [(park: WatchCache.CachedPark, attraction: WatchCache.CachedAttraction)] {
        let favoritesData = UserDefaults.standard.data(forKey: "favorites")
        let favorites: Set<Int> = favoritesData
            .flatMap { try? JSONDecoder().decode(Set<Int>.self, from: $0) }
            ?? []
        var pairs: [(WatchCache.CachedPark, WatchCache.CachedAttraction)] = []
        for park in parks {
            for a in park.attractions where favorites.contains(a.id) {
                pairs.append((park, a))
            }
        }
        return pairs.sorted { ($0.1.waitMinutes ?? Int.max) < ($1.1.waitMinutes ?? Int.max) }
    }

    var body: some View {
        List {
            Section {
                if let sync = WatchCache.lastSync {
                    Text("Updated \(relative(sync))")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(WatchTheme.muted)
                        .listRowBackground(Color.clear)
                }
            }

            if favoriteAttractions.isEmpty {
                Section {
                    Text("No favorites yet")
                        .font(.system(size: 14))
                    Text("Star rides in QueueBuddy on iPhone to see them here.")
                        .font(.system(size: 11))
                        .foregroundStyle(WatchTheme.muted)
                }
                .listRowBackground(Color.clear)
            } else {
                Section("Favorites") {
                    ForEach(favoriteAttractions, id: \.attraction.id) { pair in
                        NavigationLink {
                            WatchAttractionDetailView(pair: pair)
                        } label: {
                            WatchAttractionRow(pair: pair)
                        }
                        .listRowBackground(WatchTheme.card)
                    }
                }
            }

            if !parks.isEmpty {
                Section("Parks") {
                    ForEach(parks) { park in
                        NavigationLink {
                            WatchParkView(park: park)
                        } label: {
                            WatchParkRow(park: park)
                        }
                        .listRowBackground(WatchTheme.card)
                    }
                }
            }
        }
        .navigationTitle("QueueBuddy")
        .onAppear { parks = WatchCache.loadParks() }
    }

    private func relative(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }
}

struct WatchAttractionRow: View {
    let pair: (park: WatchCache.CachedPark, attraction: WatchCache.CachedAttraction)

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(WatchTheme.color(fromHex: pair.park.accentHex))
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(pair.attraction.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(pair.park.name)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(WatchTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
            waitBadge
        }
    }

    @ViewBuilder
    private var waitBadge: some View {
        if !pair.attraction.isOpen {
            Text("CLSD")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(WatchTheme.muted)
        } else if let w = pair.attraction.waitMinutes {
            Text("\(w)M")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(WatchTheme.tone(for: w))
        } else {
            Text("SHOW")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(WatchTheme.amber)
        }
    }
}

struct WatchParkRow: View {
    let park: WatchCache.CachedPark
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(WatchTheme.color(fromHex: park.accentHex))
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(park.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text("\(park.openCount) OPEN · AVG \(park.avgWait.map(String.init) ?? "--")M")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(WatchTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

struct WatchParkView: View {
    let park: WatchCache.CachedPark

    var body: some View {
        List {
            Section {
                Text(park.name)
                    .font(.system(size: 15, weight: .bold))
                Text("\(park.openCount)/\(park.totalCount) OPEN")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(WatchTheme.muted)
            }
            .listRowBackground(Color.clear)

            ForEach(park.attractions.sorted { ($0.waitMinutes ?? Int.max) < ($1.waitMinutes ?? Int.max) }) { a in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(a.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        if let h = a.minHeightInches, h > 0 {
                            Text("\(h)\"+")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(WatchTheme.muted)
                        }
                    }
                    Spacer()
                    if !a.isOpen {
                        Text("CLSD").font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(WatchTheme.muted)
                    } else if let w = a.waitMinutes {
                        Text("\(w)M").font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(WatchTheme.tone(for: w))
                    } else {
                        Text("SHOW").font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(WatchTheme.amber)
                    }
                }
                .listRowBackground(WatchTheme.card)
            }
        }
        .navigationTitle("Park")
    }
}

struct WatchAttractionDetailView: View {
    let pair: (park: WatchCache.CachedPark, attraction: WatchCache.CachedAttraction)

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(WatchTheme.color(fromHex: pair.park.accentHex))
                    .frame(width: 6, height: 6)
                Text(pair.park.name.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WatchTheme.muted)
                    .lineLimit(1)
                Spacer()
            }

            Text(pair.attraction.name)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(3)
                .multilineTextAlignment(.center)

            if !pair.attraction.isOpen {
                Text("CLOSED")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(WatchTheme.muted)
            } else if let w = pair.attraction.waitMinutes {
                let tone = WatchTheme.tone(for: w)
                Text("\(w)")
                    .font(.system(size: 52, weight: .heavy, design: .monospaced))
                    .foregroundStyle(tone)
                    .shadow(color: tone, radius: 6)
                Text("MINUTES")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(tone.opacity(0.8))
            } else {
                Text("SHOW")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(WatchTheme.amber)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .navigationBarTitleDisplayMode(.inline)
    }
}

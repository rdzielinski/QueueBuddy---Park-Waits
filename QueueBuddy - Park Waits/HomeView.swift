import SwiftUI
import CoreLocation

struct HomeView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @StateObject private var network = NetworkMonitor.shared
    @StateObject private var location = LocationManager.shared
    @Binding var searchText: String
    @Binding var selectedTab: Int
    @AppStorage("userDisplayName") private var userDisplayName: String = ""
    @State private var showOnboarding = false
    @State private var autoOpenedParkId: Int? = nil

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    /// Parks whose name matches the search query.
    private var matchingParks: [Park] {
        guard isSearching else { return [] }
        return viewModel.resortGroups.flatMap { $0.parks }
            .filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    /// Attractions whose name matches the search query. Ranked so that
    /// prefix matches float above substring matches, then shortest waits.
    private var matchingAttractions: [(attraction: Attraction, park: Park)] {
        guard isSearching else { return [] }
        let q = trimmedQuery.lowercased()
        let allParks = viewModel.resortGroups.flatMap { $0.parks }
        var hits: [(Attraction, Park, Int)] = []
        for (parkId, attractions) in viewModel.attractionsByPark {
            guard let park = allParks.first(where: { $0.id == parkId }) else { continue }
            for a in attractions {
                let lower = a.name.lowercased()
                guard lower.contains(q) else { continue }
                let prefixBoost = lower.hasPrefix(q) ? 0 : 1
                hits.append((a, park, prefixBoost))
            }
        }
        return hits
            .sorted {
                if $0.2 != $1.2 { return $0.2 < $1.2 }                       // prefix matches first
                let aOpen = $0.0.is_open == true, bOpen = $1.0.is_open == true
                if aOpen != bOpen { return aOpen }                            // open before closed
                return ($0.0.wait_time ?? Int.max) < ($1.0.wait_time ?? Int.max)
            }
            .map { ($0.0, $0.1) }
    }

    /// Attraction with the longest live wait across all parks.
    private var hottestAttraction: (attraction: Attraction, park: Park)? {
        let all = viewModel.attractionsByPark
        var best: (Attraction, Park)?
        var bestWait = -1
        for (parkId, attractions) in all {
            guard let park = viewModel.resortGroups.flatMap({ $0.parks }).first(where: { $0.id == parkId }) else { continue }
            for a in attractions where a.is_open == true {
                if let w = a.wait_time, w > bestWait {
                    bestWait = w
                    best = (a, park)
                }
            }
        }
        return best
    }

    private var headerSubtitle: String {
        let df = DateFormatter()
        df.dateFormat = "EEE · MMM d"
        let dateStr = df.string(from: Date()).uppercased()
        return dateStr
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DB.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title
                        header
                        if !network.isOnline {
                            OfflineBanner(lastSyncText: network.lastSyncText)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }
                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }
                        if let here = location.nearestPark, location.isInsidePark, !isSearching {
                            youAreHereBanner(for: here)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }
                        if !isSearching {
                            hottestHero
                                .padding(.horizontal, 16)
                                .padding(.bottom, 18)
                        }
                        terminalSearch
                            .padding(.horizontal, 16)
                            .padding(.bottom, 22)

                        if isSearching {
                            searchResults
                                .padding(.bottom, 22)
                        } else {
                            ForEach(viewModel.resortGroups) { group in
                                resortSection(group: group)
                                    .padding(.bottom, 22)
                            }
                        }

                        Color.clear.frame(height: 120) // tab bar spacer
                    }
                }
                .refreshable {
                    await viewModel.refreshAllWaits()
                }

                if viewModel.isLoading && viewModel.resortGroups.isEmpty {
                    loadingOverlay
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Park.self) { park in
                ParkDetailView(park: park)
            }
            .navigationDestination(for: Attraction.self) { attraction in
                AttractionDetailView(attraction: attraction)
            }
            .task { [viewModel] in
                guard viewModel.resortGroups.isEmpty else { return }
                await viewModel.loadInitialData()
            }
            .onChange(of: searchText) { _, newValue in
                if viewModel.searchTerm != newValue {
                    viewModel.searchTerm = newValue
                }
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(userDisplayName: $userDisplayName, isPresented: $showOnboarding)
            }
        }
        .onAppear {
            if userDisplayName.isEmpty {
                showOnboarding = true
            }
            location.requestNearestPark()
        }
    }

    // MARK: - Sections

    private func youAreHereBanner(for park: Park) -> some View {
        NavigationLink(value: park) {
            HStack(spacing: 10) {
                Circle()
                    .fill(DB.accent(for: park.id))
                    .frame(width: 6, height: 6)
                    .shadow(color: DB.accent(for: park.id), radius: 4)
                MonoLabel(text: "YOU'RE AT", color: DB.muted, tracking: 1.8, size: 10)
                Text(park.name)
                    .font(DB.heading(14, weight: .semibold))
                    .foregroundStyle(DB.text)
                Spacer()
                Text("OPEN →").tracking(1.5)
                    .font(DB.mono(11, weight: .semibold))
                    .foregroundStyle(DB.accent(for: park.id))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DB.accent(for: park.id).opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DB.accent(for: park.id).opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: headerSubtitle + " · ALL SYSTEMS LIVE", color: DB.muted)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("Parks")
                    .font(DB.displayTitle(38))
                    .foregroundStyle(DB.text)
                    .tracking(-0.8)
                Text(".")
                    .font(DB.displayTitle(38))
                    .foregroundStyle(DB.amber)
            }
            if !userDisplayName.isEmpty {
                Text("Good \(greetingTime()), \(userDisplayName).")
                    .font(DB.mono(12))
                    .tracking(1.2)
                    .foregroundStyle(DB.muted)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var hottestHero: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DB.card2, DB.card],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(DB.amber.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    RadialGradient(
                        colors: [DB.amber.opacity(0.09), .clear],
                        center: .topTrailing,
                        startRadius: 0, endRadius: 220
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )

            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "▲ HOTTEST RIGHT NOW", color: DB.amber, tracking: 2, size: 11)

                if let hot = hottestAttraction, let wait = hot.attraction.wait_time {
                    Text(hot.attraction.name)
                        .font(DB.heading(22, weight: .semibold))
                        .foregroundStyle(DB.text)
                        .tracking(-0.4)
                        .lineLimit(2)

                    MonoLabel(text: hot.park.name, color: DB.muted, tracking: 1.5, size: 11)
                        .padding(.bottom, 6)

                    HStack(alignment: .bottom) {
                        FlapDigits(
                            value: wait,
                            size: 52,
                            tone: DB.waitTone(for: wait),
                            label: "MIN"
                        )
                        Spacer()
                        NavigationLink(value: hot.attraction) {
                            HStack(spacing: 4) {
                                Text("VIEW").tracking(1.5)
                                Text("→")
                            }
                            .font(DB.mono(11, weight: .semibold))
                            .foregroundStyle(DB.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(Color.white.opacity(0.06))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Waits aren't in yet")
                        .font(DB.heading(20, weight: .semibold))
                        .foregroundStyle(DB.text)
                    MonoLabel(text: "Pull to refresh · SYNCING...", color: DB.muted)
                        .padding(.top, 4)
                }
            }
            .padding(18)
        }
    }

    private var terminalSearch: some View {
        HStack(spacing: 10) {
            Text(">")
                .font(DB.mono(14, weight: .bold))
                .foregroundStyle(DB.amber)
            TextField(
                "",
                text: $searchText,
                prompt: Text("search attractions…")
                    .foregroundStyle(DB.muted)
                    .font(DB.mono(14))
            )
            .font(DB.mono(14))
            .foregroundStyle(DB.text)
            .tint(DB.amber)
            .autocorrectionDisabled(true)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DB.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DB.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var searchResults: some View {
        let attractions = matchingAttractions
        let parks = matchingParks

        if attractions.isEmpty && parks.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(DB.muted)
                MonoLabel(text: "NO MATCHES", color: DB.muted)
                Text("Nothing found for “\(trimmedQuery)”")
                    .font(.system(size: 13))
                    .foregroundStyle(DB.muted)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                if !parks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            MonoLabel(text: "/ PARKS", color: DB.muted, tracking: 2, size: 12)
                            Spacer()
                            MonoLabel(text: "\(parks.count)", color: DB.dim, tracking: 1.5, size: 11)
                        }
                        .padding(.horizontal, 20)

                        VStack(spacing: 10) {
                            ForEach(parks) { park in
                                NavigationLink(value: park) {
                                    ParkCardView(park: park)
                                        .environmentObject(viewModel)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                if !attractions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            MonoLabel(text: "/ ATTRACTIONS", color: DB.muted, tracking: 2, size: 12)
                            Spacer()
                            MonoLabel(text: "\(attractions.count)", color: DB.dim, tracking: 1.5, size: 11)
                        }
                        .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ForEach(Array(attractions.enumerated()), id: \.element.attraction.id) { idx, pair in
                                NavigationLink(value: pair.attraction) {
                                    searchAttractionRow(attraction: pair.attraction, park: pair.park)
                                }
                                .buttonStyle(.plain)
                                if idx < attractions.count - 1 {
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
        }
    }

    /// Attraction row tuned for search — shows the park name underneath so
    /// you can tell "Rise of the Resistance" at Hollywood Studios from
    /// anything else.
    private func searchAttractionRow(attraction: Attraction, park: Park) -> some View {
        HStack(alignment: .center, spacing: 12) {
            RouteStripe(color: DB.accent(for: park.id), width: 14)

            AttractionGlyph(
                attractionId: attraction.id,
                attractionType: attraction.type,
                tint: DB.accent(for: park.id),
                size: 26
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(attraction.name)
                    .font(DB.heading(15, weight: .medium))
                    .foregroundStyle(DB.text)
                    .tracking(-0.2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 6) {
                    Text(park.name.uppercased())
                        .font(DB.mono(10))
                        .tracking(1.5)
                        .foregroundStyle(DB.muted)
                    if let land = StaticData.attractionToLandMapping[attraction.id] {
                        Text("·").foregroundStyle(DB.dim)
                        Text(land.uppercased())
                            .font(DB.mono(10))
                            .tracking(1.5)
                            .foregroundStyle(DB.dim)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }

            Spacer(minLength: 8)

            WaitChip(
                wait: attraction.wait_time,
                isOpen: attraction.is_open ?? true,
                status: attraction.status
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func resortSection(group: ResortGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonoLabel(text: "/ \(group.name)", color: DB.muted, tracking: 2, size: 12)
                Spacer()
                MonoLabel(
                    text: "\(group.parks.reduce(0) { $0 + viewModel.operatingAttractionCount(for: $1.id) }) OPEN",
                    color: DB.dim, tracking: 1.5, size: 11
                )
            }
            .padding(.horizontal, 20)

            VStack(spacing: 10) {
                ForEach(group.parks) { park in
                    NavigationLink(value: park) {
                        ParkCardView(park: park)
                            .environmentObject(viewModel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 14) {
            MonoLabel(text: "● SYNCING LIVE DATA", color: DB.amber)
            ProgressView()
                .progressViewStyle(.circular)
                .tint(DB.amber)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DB.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DB.line, lineWidth: 1)
                )
        )
    }

    private func greetingTime() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<18: return "afternoon"
        default: return "evening"
        }
    }
}

import SwiftUI

/// Top-level Map tab. Picks a park with a dropdown menu in the header and
/// embeds the existing ParkMapView underneath. Persists the last-viewed
/// park to UserDefaults so reopening the tab brings you back to the same
/// map, and listens for `.openMapTab` deep links from elsewhere in the
/// app (e.g. an attraction's "Find on Map" button).
struct MapTabView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @AppStorage("mapTabParkId") private var selectedParkId: Int = 6 // Magic Kingdom

    private var allParks: [Park] {
        viewModel.resortGroups.flatMap { $0.parks }
    }

    private var currentPark: Park? {
        allParks.first { $0.id == selectedParkId }
    }

    private var currentAttractions: [Attraction] {
        viewModel.attractionsByPark[selectedParkId] ?? []
    }

    private var mappableCount: Int {
        currentAttractions.filter { $0.latitude != nil && $0.longitude != nil }.count
    }

    private var accent: Color {
        DB.accent(for: selectedParkId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DB.bg.ignoresSafeArea()

                VStack(spacing: 14) {
                    header
                    parkPicker

                    if allParks.isEmpty {
                        loadingState
                    } else if currentAttractions.isEmpty {
                        emptyParkState
                    } else {
                        // `.id(selectedParkId)` forces ParkMapView to
                        // rebuild when the user switches parks so the
                        // camera re-centers on the new park.
                        ParkMapView(parkId: selectedParkId,
                                    attractions: currentAttractions)
                            .id(selectedParkId)
                    }
                }
                // Leave room for the BottomAdBanner (~50pt) and the
                // floating DepartureTabBar (~60pt incl. padding).
                .padding(.bottom, 110)
            }
            .onAppear { ensureSelectedParkIsValid() }
            .onChange(of: allParks.map(\.id)) { _, _ in
                ensureSelectedParkIsValid()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(
                text: "\(mappableCount) PINNED · CHOOSE TERMINAL",
                color: DB.muted
            )
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("Map")
                    .font(DB.displayTitle(34))
                    .foregroundStyle(DB.text)
                    .tracking(-0.8)
                Text(".")
                    .font(DB.displayTitle(34))
                    .foregroundStyle(accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Park picker

    private var parkPicker: some View {
        Menu {
            ForEach(viewModel.resortGroups) { group in
                Section(group.name) {
                    ForEach(group.parks) { park in
                        Button {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            selectedParkId = park.id
                        } label: {
                            Label(park.name,
                                  systemImage: DB.glyph(for: park.id))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: DB.glyph(for: selectedParkId))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                MonoLabel(
                    text: "VIEWING · \(currentPark?.name.uppercased() ?? "—")",
                    color: accent,
                    tracking: 1.8,
                    size: 12
                )
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DB.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(accent.opacity(0.30), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty / loading states

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(DB.muted)
            MonoLabel(text: "WAITING FOR PARK DATA", color: DB.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyParkState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "mappin.slash")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(DB.muted)
            MonoLabel(text: "NO ATTRACTIONS LOADED FOR THIS PARK",
                      color: DB.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    /// If the persisted selection is gone (data not loaded yet, or the
    /// park list changed), fall back to the first available park so the
    /// header / picker never read as "—".
    private func ensureSelectedParkIsValid() {
        guard !allParks.isEmpty else { return }
        if !allParks.contains(where: { $0.id == selectedParkId }) {
            selectedParkId = allParks.first?.id ?? 6
        }
    }
}

#if DEBUG
#Preview {
    MapTabView()
        .environmentObject(WaitTimeViewModel())
        .preferredColorScheme(.dark)
}
#endif

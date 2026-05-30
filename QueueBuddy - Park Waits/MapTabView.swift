import SwiftUI

/// Top-level Map tab. Picks a park with a dropdown menu in the header and
/// embeds the existing ParkMapView underneath. Persists the last-viewed
/// park to UserDefaults so reopening the tab brings you back to the same
/// map, and listens for `.openMapTab` deep links from elsewhere in the
/// app (e.g. an attraction's "Find on Map" button).
struct MapTabView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @AppStorage("mapTabParkId") private var selectedParkId: Int = 6 // Magic Kingdom

    /// One-shot focus attraction. Written by MainTabView when a deep link
    /// arrives with userInfo["attractionId"]. Cleared after this view
    /// passes it to ParkMapView so re-visiting the Map tab doesn't keep
    /// re-centering on the same pin.
    @AppStorage("mapTabFocusAttractionId") private var focusAttractionId: Int = 0

    /// Bumped on every focus request. Included in ParkMapView's `.id` so
    /// the same park can be re-focused on a different attraction (which
    /// would otherwise look like the same view to SwiftUI).
    @AppStorage("mapTabFocusGeneration") private var focusGen: Int = 0

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

                VStack(spacing: 8) {
                    parkPicker

                    if allParks.isEmpty {
                        loadingState
                    } else if currentAttractions.isEmpty {
                        emptyParkState
                    } else {
                        // `.id` combines parkId + focusGen so the camera
                        // re-centers both when the user switches parks
                        // (parkId changes) and when a deep link asks to
                        // focus on a new attraction in the *same* park
                        // (focusGen changes).
                        ParkMapView(
                            parkId: selectedParkId,
                            attractions: currentAttractions,
                            focusAttractionId: focusAttractionId > 0 ? focusAttractionId : nil
                        )
                        .id("\(selectedParkId)-\(focusGen)")
                    }
                }
                .padding(.top, 8)
                // Leave room for the BottomAdBanner (~50pt) and the
                // floating DepartureTabBar (~50pt incl. padding).
                .padding(.bottom, 100)
            }
            .onAppear { ensureSelectedParkIsValid() }
            .onChange(of: allParks.map(\.id)) { _, _ in
                ensureSelectedParkIsValid()
            }
            .onChange(of: focusGen) { _, _ in
                // ParkMapView captured the focused attraction in its init
                // already (it's an init-only @State for the camera). Clear
                // the marker shortly after so leaving the tab and coming
                // back uses the default park-center zoom instead of
                // re-focusing on the same pin. The delay is just enough
                // to ensure ParkMapView's init has run.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if focusAttractionId != 0 {
                        focusAttractionId = 0
                    }
                }
            }
        }
    }

    // MARK: - Park picker
    // Doubles as the screen's only header — the tab bar already says
    // "Map", so a separate display title would just steal vertical space
    // from the actual map.

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
                    text: currentPark?.name.uppercased() ?? "—",
                    color: accent,
                    tracking: 1.8,
                    size: 12
                )
                Spacer(minLength: 0)
                MonoLabel(
                    text: "\(mappableCount) PINNED",
                    color: DB.muted,
                    tracking: 1.2,
                    size: 10
                )
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

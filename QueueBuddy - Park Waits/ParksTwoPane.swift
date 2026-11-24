import SwiftUI

// Two-pane Parks layout for big screens: the iPhone Duo's inner display
// (both orientations) and iPad. The parks list stays on the left; the
// selected park, and any ride opened from it, fill the right pane.
//
// The Duo reports the phone idiom and a compact horizontal size class in
// unfolded portrait (669pt wide), so the switch is driven by the actual
// container size rather than the size class.

enum ParksLayout {
    /// Wide enough for a list beside a phone-width detail, and tall enough
    /// that it isn't just a regular iPhone turned sideways.
    static func isWide(_ size: CGSize) -> Bool {
        size.width >= 600 && size.height >= 500
    }

    static func sidebarWidth(for totalWidth: CGFloat) -> CGFloat {
        min(max(totalWidth * 0.42, 320), 400)
    }

    /// Readable cap for single-column tabs on wide screens.
    static let readableWidth: CGFloat = 720
}

// MARK: - Environment

/// Something a Parks-list row can open.
enum ParksDestination: Hashable {
    case park(Park)
    case attraction(Attraction)
}

private struct ParksSelectKey: EnvironmentKey {
    static let defaultValue: ((ParksDestination) -> Void)? = nil
}

private struct ParksSelectedParkIdKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

private struct IsParksDetailRootKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ParksShownReporterKey: EnvironmentKey {
    static let defaultValue: ((ParksDestination) -> Void)? = nil
}

extension EnvironmentValues {
    /// Set in the two-pane layout: list rows call this instead of pushing.
    var parksSelect: ((ParksDestination) -> Void)? {
        get { self[ParksSelectKey.self] }
        set { self[ParksSelectKey.self] = newValue }
    }

    /// The park showing in the detail pane, for highlighting its list row.
    var parksSelectedParkId: Int? {
        get { self[ParksSelectedParkIdKey.self] }
        set { self[ParksSelectedParkIdKey.self] = newValue }
    }

    /// True for the park detail at the root of the right pane, which has
    /// nothing to go back to.
    var isParksDetailRoot: Bool {
        get { self[IsParksDetailRootKey.self] }
        set { self[IsParksDetailRootKey.self] = newValue }
    }

    /// Park and ride screens report themselves when they appear, so a fold
    /// or unfold can carry the open screen across layouts.
    var parksShownReporter: ((ParksDestination) -> Void)? {
        get { self[ParksShownReporterKey.self] }
        set { self[ParksShownReporterKey.self] = newValue }
    }
}

// MARK: - Links

/// A NavigationLink in the single-column layout, a selection button in the
/// two-pane layout. Both are buttons, so `.buttonStyle` applies either way.
struct ParksLink<Label: View>: View {
    let destination: ParksDestination
    @ViewBuilder let label: () -> Label
    @Environment(\.parksSelect) private var select

    init(park: Park, @ViewBuilder label: @escaping () -> Label) {
        self.destination = .park(park)
        self.label = label
    }

    init(attraction: Attraction, @ViewBuilder label: @escaping () -> Label) {
        self.destination = .attraction(attraction)
        self.label = label
    }

    var body: some View {
        if let select {
            Button { select(destination) } label: { label() }
        } else {
            switch destination {
            case .park(let park):
                NavigationLink(value: park) { label() }
            case .attraction(let attraction):
                NavigationLink(value: attraction) { label() }
            }
        }
    }
}

// MARK: - Parks tab

/// The Parks tab in either layout. HomeView keeps the same structural
/// position in both, so its scroll position and search survive a fold.
struct ParksTab: View {
    @Binding var searchText: String
    @Binding var selectedTab: Int
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @ObservedObject private var location = LocationManager.shared

    /// Single-column navigation stack.
    @State private var path = NavigationPath()
    /// Two-pane selection.
    @State private var selectedPark: Park?
    @State private var detailPath: [Attraction] = []
    /// False while the pane shows the default park nobody picked; that one
    /// isn't carried into the single-column stack on fold.
    @State private var selectionIsExplicit = false
    /// Last park/ride screen that appeared (either layout).
    @State private var lastPark: Park?
    @State private var lastAttraction: Attraction?

    var body: some View {
        GeometryReader { geo in
            let wide = ParksLayout.isWide(geo.size)
            HStack(spacing: 0) {
                HomeView(searchText: $searchText, selectedTab: $selectedTab, path: $path)
                    .environment(\.parksSelect, wide ? { select($0) } : nil)
                    .environment(\.parksSelectedParkId, wide ? selectedPark?.id : nil)
                    .frame(width: wide ? ParksLayout.sidebarWidth(for: geo.size.width) : geo.size.width)

                if wide {
                    Rectangle().fill(DB.line).frame(width: 1).ignoresSafeArea()
                    detailPane
                }
            }
            .environment(\.parksShownReporter, { report($0) })
            .onChange(of: wide, initial: true) { _, isWide in
                isWide ? moveToTwoPane() : moveToSingleColumn()
            }
            .onChange(of: path.count) { _, count in
                // Popped back to the list: nothing is open any more.
                if count == 0 { lastPark = nil; lastAttraction = nil }
                if count == 1, lastPark != nil { lastAttraction = nil }
            }
            .onChange(of: viewModel.resortGroups.count) { _, _ in
                if wide, selectedPark == nil { selectedPark = defaultPark }
            }
            .onChange(of: location.isInsidePark) { _, _ in
                // Location usually resolves after the first layout; follow
                // it until the user picks a park themselves.
                if wide, !selectionIsExplicit, let park = defaultPark, park.id != selectedPark?.id {
                    selectedPark = park
                }
            }
        }
    }

    private var detailPane: some View {
        NavigationStack(path: $detailPath) {
            Group {
                if let park = selectedPark {
                    ParkDetailView(park: park)
                        .environment(\.isParksDetailRoot, true)
                } else {
                    placeholder
                }
            }
            .navigationDestination(for: Attraction.self) { attraction in
                AttractionDetailView(attraction: attraction)
            }
        }
        .id(selectedPark?.id)
        .frame(maxWidth: .infinity)
    }

    private var placeholder: some View {
        ZStack {
            DB.bg.ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(DB.muted)
                MonoLabel(text: "SELECT A PARK", color: DB.muted, tracking: 2, size: 11)
            }
        }
    }

    // MARK: Selection

    private func select(_ destination: ParksDestination) {
        selectionIsExplicit = true
        switch destination {
        case .park(let park):
            if selectedPark?.id == park.id {
                detailPath = []  // re-tap: back to the park's root
            } else {
                selectedPark = park
                detailPath = []
            }
        case .attraction(let attraction):
            let park = park(for: attraction) ?? selectedPark
            if selectedPark?.id != park?.id { selectedPark = park }
            detailPath = [attraction]
        }
    }

    private func report(_ destination: ParksDestination) {
        switch destination {
        case .park(let park):
            lastPark = park
            lastAttraction = nil
        case .attraction(let attraction):
            lastAttraction = attraction
            let owner = park(for: attraction)
            if lastPark?.id != owner?.id { lastPark = owner }
        }
    }

    // MARK: Fold / unfold

    private func moveToTwoPane() {
        if !path.isEmpty {
            selectionIsExplicit = true
            selectedPark = lastPark ?? lastAttraction.flatMap(park(for:))
            detailPath = lastAttraction.map { [$0] } ?? []
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { path = NavigationPath() }
        }
        if selectedPark == nil {
            selectedPark = defaultPark
            selectionIsExplicit = false
        }
    }

    private func moveToSingleColumn() {
        guard selectionIsExplicit, let park = selectedPark else { return }
        var newPath = NavigationPath()
        newPath.append(park)
        if let attraction = detailPath.last { newPath.append(attraction) }
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { path = newPath }
    }

    // MARK: Helpers

    private var allParks: [Park] { viewModel.resortGroups.flatMap(\.parks) }

    private func park(for attraction: Attraction) -> Park? {
        guard let parkId = viewModel.attractionsByPark
            .first(where: { $0.value.contains { $0.id == attraction.id } })?.key
        else { return nil }
        return allParks.first { $0.id == parkId }
    }

    /// The park the user is standing in, else the first listed.
    private var defaultPark: Park? {
        if location.isInsidePark, let here = location.nearestPark { return here }
        return allParks.first
    }
}

extension View {
    /// Caps a single-column screen at a readable width on wide displays,
    /// centred, with the app background filling the margins.
    func readableWidth() -> some View {
        frame(maxWidth: ParksLayout.readableWidth)
            .frame(maxWidth: .infinity)
            .background(DB.bg.ignoresSafeArea())
    }
}

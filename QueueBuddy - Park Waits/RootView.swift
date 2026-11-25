import SwiftUI
import UserNotifications
import UIKit
import CoreLocation

/// Cross-tab navigation event posted when something deep in the view tree
/// (e.g. an attraction detail) wants to switch to the Map tab.
/// userInfo keys:
///   - "parkId": Int (optional) — pre-selects the park to show
///   - "attractionId": Int (optional) — pre-centers the map camera on
///     that attraction with a tighter zoom, one-shot
extension Notification.Name {
    static let openMapTab = Notification.Name("queuebuddy.openMapTab")
}

struct RootView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @StateObject private var notificationDelegate = NotificationDelegate()
    @State private var isSplashActive = true
    @State private var hingeHalfOpen = false
    @State private var placement: ScreenPlacement?

    var body: some View {
        ZStack {
            if isSplashActive {
                SplashScreenView(isActive: $isSplashActive)
            } else {
                MainTabView()
                    .environmentObject(viewModel)
            }
        }
        .background {
            ScreenPlacementReader { placement = $0 }
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
        .modifier(HingeReader(isHalfOpen: $hingeHalfOpen))
        .environment(\.foldCrease, FoldCrease.current(halfOpen: hingeHalfOpen, placement: placement))
        .onAppear {
            UNUserNotificationCenter.current().delegate = notificationDelegate
        }
    }
}

/// The primary destinations as named in the departure-board design.
enum QBTab: Int, CaseIterable, Identifiable {
    case parks, map, favorites, alerts, plan
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .parks:     return "Parks"
        case .map:       return "Map"
        case .favorites: return "Favorites"
        case .alerts:    return "Alerts"
        case .plan:      return "Plan"
        }
    }

    var systemImage: String {
        switch self {
        case .parks:     return "square.grid.2x2.fill"
        case .map:       return "map.fill"
        case .favorites: return "star.fill"
        case .alerts:    return "bell.badge.fill"
        case .plan:      return "sparkles"
        }
    }
}

struct MainTabView: View {
    @AppStorage(UserPreferences.Key.defaultTab) private var defaultTabRaw: Int = QBTab.parks.rawValue
    @State private var selectedTab: QBTab = .parks
    @State private var searchText: String = ""
    @EnvironmentObject var viewModel: WaitTimeViewModel

    private var accent: Color {
        if let id = viewModel.activeParkId { return DB.accent(for: id) }
        return DB.amber
    }

    var body: some View {
        // Native adaptive tab bar: a bottom bar on regular iPhones and the
        // Duo's unfolded portrait, the system's right-edge rail on the Duo
        // cover screen, a sidebar/top bar on iPad. Each tab keeps its own
        // state across switches.
        TabView(selection: $selectedTab) {
            Tab(QBTab.parks.label, systemImage: QBTab.parks.systemImage, value: QBTab.parks) {
                page {
                    ParksTab(
                        searchText: $searchText,
                        selectedTab: Binding(
                            get: { selectedTab.rawValue },
                            set: { selectedTab = QBTab(rawValue: $0) ?? .parks }
                        )
                    )
                }
            }
            Tab(QBTab.map.label, systemImage: QBTab.map.systemImage, value: QBTab.map) {
                page { MapTabView() }
            }
            Tab(QBTab.favorites.label, systemImage: QBTab.favorites.systemImage, value: QBTab.favorites) {
                page { FavoritedAttractionsView(searchText: $searchText).readableWidth() }
            }
            Tab(QBTab.alerts.label, systemImage: QBTab.alerts.systemImage, value: QBTab.alerts) {
                page { NotificationListView().readableWidth() }
            }
            Tab(QBTab.plan.label, systemImage: QBTab.plan.systemImage, value: QBTab.plan) {
                page { AIPlaygroundView().readableWidth() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(accent)
        .animation(.easeInOut(duration: 0.25), value: viewModel.activeParkId)
        .overlay(alignment: .top) {
            // Reroute banner overlay — anchored at top, hidden when the
            // routing engine hasn't fired or the user has dismissed.
            VStack {
                if let decision = viewModel.latestRouteDecision,
                   let pid = viewModel.latestRouteDecisionParkId {
                    RouteBanner(
                        decision: decision,
                        parkId: pid,
                        parkName: parkName(for: pid),
                        onDismiss: { viewModel.acknowledgeRouteDecision() }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.latestRouteDecision?.id)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Honor the saved "launch on" preference, falling back to
            // Parks when the persisted value isn't a valid tab.
            selectedTab = QBTab(rawValue: defaultTabRaw) ?? .parks
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMapTab)) { notif in
            handleOpenMapTab(notif)
        }
    }

    /// Shared chrome for every tab: app background and the ad slot, which
    /// sits above the tab bar and pushes scroll content up with it.
    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .environmentObject(viewModel)
            .safeAreaInset(edge: .bottom, spacing: 0) { BottomAdBanner() }
            .background(DB.bg.ignoresSafeArea())
    }

    private func parkName(for parkId: Int) -> String {
        viewModel.resortGroups.flatMap(\.parks)
            .first(where: { $0.id == parkId })?
            .name ?? "Park"
    }

    /// Deep link from anywhere in the app (e.g. an attraction's
    /// "Find on Map" button or the reroute banner). Pre-selects the
    /// requested park before flipping the tab so MapTabView's
    /// @AppStorage has the right value when it mounts. If an
    /// attractionId came along, stores it AND bumps the focus
    /// generation counter so MapTabView's view-id changes even when
    /// the user requests a focus for an attraction in the park they're
    /// already viewing.
    private func handleOpenMapTab(_ notif: Notification) {
        let defaults = UserDefaults.standard
        if let parkId = notif.userInfo?["parkId"] as? Int {
            defaults.set(parkId, forKey: "mapTabParkId")
        }
        if let attractionId = notif.userInfo?["attractionId"] as? Int {
            defaults.set(attractionId, forKey: "mapTabFocusAttractionId")
            let gen = defaults.integer(forKey: "mapTabFocusGeneration")
            defaults.set(gen &+ 1, forKey: "mapTabFocusGeneration")
        }
        selectedTab = .map
    }
}

struct ColorfulBackground: View {
    var body: some View {
        DB.bg.ignoresSafeArea()
    }
}

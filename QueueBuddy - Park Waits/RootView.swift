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

    var body: some View {
        ZStack {
            if isSplashActive {
                SplashScreenView(isActive: $isSplashActive)
            } else {
                MainTabView()
                    .environmentObject(viewModel)
            }
        }
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

    var body: some View {
        ZStack(alignment: .bottom) {
            DB.bg.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .parks:
                    HomeView(
                        searchText: $searchText,
                        selectedTab: Binding(
                            get: { selectedTab.rawValue },
                            set: { selectedTab = QBTab(rawValue: $0) ?? .parks }
                        )
                    )
                case .map:
                    MapTabView()
                case .favorites:
                    FavoritedAttractionsView(searchText: $searchText)
                case .alerts:
                    NotificationListView()
                case .plan:
                    AIPlaygroundView()
                }
            }
            .transition(.opacity)
            .environmentObject(viewModel)

            VStack(spacing: 0) {
                BottomAdBanner()
                DepartureTabBar(selected: $selectedTab)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

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
                Spacer(minLength: 0)
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

struct DepartureTabBar: View {
    @Binding var selected: QBTab
    @EnvironmentObject var viewModel: WaitTimeViewModel

    private var accent: Color {
        if let id = viewModel.activeParkId { return DB.accent(for: id) }
        return DB.amber
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(QBTab.allCases) { tab in
                Button {
                    if selected != tab {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        selected = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                        Text(tab.label.uppercased())
                            .font(DB.mono(10, weight: .semibold))
                            .tracking(1.5)
                    }
                    .foregroundStyle(selected == tab ? accent : DB.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DB.card.opacity(0.72))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            }
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.activeParkId)
    }
}

struct ColorfulBackground: View {
    var body: some View {
        DB.bg.ignoresSafeArea()
    }
}

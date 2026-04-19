import SwiftUI
import UserNotifications
import UIKit
import CoreLocation

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

/// The four primary destinations as named in the departure-board design.
enum QBTab: Int, CaseIterable, Identifiable {
    case parks, favorites, alerts, plan
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .parks:     return "Parks"
        case .favorites: return "Favorites"
        case .alerts:    return "Alerts"
        case .plan:      return "Plan"
        }
    }

    var systemImage: String {
        switch self {
        case .parks:     return "square.grid.2x2.fill"
        case .favorites: return "star.fill"
        case .alerts:    return "bell.badge.fill"
        case .plan:      return "sparkles"
        }
    }
}

struct MainTabView: View {
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

            DepartureTabBar(selected: $selectedTab)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
        .preferredColorScheme(.dark)
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

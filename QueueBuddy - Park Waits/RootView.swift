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

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var searchText = ""
    @State private var myDayMapCenter: CLLocationCoordinate2D? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
           

            FavoritedAttractionsView(searchText: $searchText)
                .tabItem { Label("Favorites", systemImage: "star.fill") }
                .tag(1)

            NotificationListView()
                .tabItem { Label("Notifications", systemImage: "bell.badge.fill") }
                .tag(2)

            HomeView(searchText: $searchText, selectedTab: $selectedTab, myDayMapCenter: $myDayMapCenter)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            
            AIPlaygroundView()
                .tabItem { Label("AI", systemImage: "sparkles") }
                .tag(3)

            MyDayMapView(centerOnCoordinate: $myDayMapCenter)
                .tabItem { Label("My Day", systemImage: "map.fill") }
                .tag(4)
        }
        .onChange(of: selectedTab) { _, _ in
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
}

struct ColorfulBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.purple.opacity(0.18),
                Color.blue.opacity(0.15),
                Color.green.opacity(0.13),
                Color.yellow.opacity(0.10),
                Color.orange.opacity(0.10),
                Color.pink.opacity(0.13)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

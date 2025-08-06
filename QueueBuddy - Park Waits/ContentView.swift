import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var viewModel = WaitTimeViewModel()
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var myDayMapCenter: CLLocationCoordinate2D? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                searchText: $searchText,
                selectedTab: $selectedTab,
                myDayMapCenter: $myDayMapCenter
            )
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            FavoritedAttractionsView(searchText: $searchText)
                .tabItem { Label("Favorites", systemImage: "star.fill") }
                .tag(1)

            NotificationListView()
                .tabItem { Label("Notifications", systemImage: "bell.badge.fill") }
                .tag(2)

            AIPlaygroundView()
                .tabItem { Label("AI", systemImage: "sparkles") }
                .tag(3)

            MyDayMapView(centerOnCoordinate: $myDayMapCenter)
                .tabItem { Label("My Day", systemImage: "map.fill") }
                .tag(4)
        }
        .environmentObject(viewModel)
        .onAppear {
            Task { await viewModel.loadInitialData() }
        }
    }
}


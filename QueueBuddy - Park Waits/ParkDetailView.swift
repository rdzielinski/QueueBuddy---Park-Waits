import SwiftUI
import MapKit
import CoreLocation

extension Park {
    var coordinate: CLLocationCoordinate2D? {
        StaticData.parkCoordinates[self.id].map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }
}

struct ParkDetailView: View {
    @EnvironmentObject private var viewModel: WaitTimeViewModel
    let park: Park

    @Binding var selectedTab: Int
    @Binding var myDayMapCenter: CLLocationCoordinate2D?

    @State private var selectedFilter: AttractionFilter = .all
    @State private var attractionForNotification: Attraction?
    @State private var tipIndex: Int = 0
    @State private var showTip: Bool = false

    private let parkTips: [Int: [String]] = [
        6: [
            "Arrive early for shortest lines at Space Mountain and Seven Dwarfs Mine Train.",
            "Use the railroad to quickly get between lands.",
            "Mobile order food to skip the lines at quick service restaurants.",
            "The parade route fills up fast—grab a spot 30 minutes early for the best view.",
            "Try the Dole Whip in Adventureland for a refreshing treat."
        ],
        5: [
            "Try the single rider line at Test Track for a faster experience.",
            "The World Showcase is less crowded before noon.",
            "Guardians of the Galaxy: Cosmic Rewind uses a virtual queue—join it as soon as it opens.",
            "The best spot for fireworks is between the two gift shops at the entrance to World Showcase.",
            "Frozen Ever After is a great ride for all ages—visit during lunchtime for a shorter wait."
        ],
        7: [
            "Head to Star Wars: Rise of the Resistance at rope drop for the best chance at a short wait.",
            "Slinky Dog Dash and Tower of Terror have the longest waits—ride early or late.",
            "Use the Disney app to check showtimes for Indiana Jones and Beauty and the Beast.",
            "For a quick snack, try the Totchos at Woody’s Lunch Box.",
            "Mickey & Minnie's Runaway Railway is a fun family ride—look for hidden Mickeys in the queue!"
        ],
        8: [
            "Pandora rides have the longest waits—visit at park open or close for the best experience.",
            "Kilimanjaro Safaris is best in the morning when animals are most active.",
            "Don’t miss the Festival of the Lion King show—arrive 15 minutes early for good seats.",
            "There are water bottle refill stations near Expedition Everest and Pandora.",
            "Try the Night Blossom drink in Pandora for a unique treat."
        ],
        64: [
            "Hagrid’s Motorbike Adventure often has the longest wait—try during parades or late evening.",
            "The single rider line for The Incredible Hulk Coaster is usually much faster.",
            "Jurassic Park River Adventure is a great way to cool off in the afternoon.",
            "Download the Universal app for real-time showtimes and mobile food ordering.",
            "Pose for a photo with Spider-Man in Marvel Super Hero Island!"
        ],
        65: [
            "Diagon Alley is less crowded in the evening—enjoy the lights and atmosphere.",
            "The Mummy and Gringotts have single rider lines that move quickly.",
            "Don’t miss the interactive wand experiences in Diagon Alley.",
            "Universal’s Superstar Parade is best viewed from the Hollywood area.",
            "Try the Butterbeer ice cream for a sweet treat."
        ],
        334: [
            "Epic Universe is now open! Try Starfall Racers and Donkey Kong: Mine Cart Madness early in the day.",
            "Super Nintendo World is busiest in the afternoon—visit in the morning for shorter waits.",
            "Download the Universal app for Epic Universe-specific maps and showtimes.",
            "Many attractions use virtual queues—check the app for availability and join as soon as you enter the park.",
            "The Ministry of Magic ride is a must for Harry Potter fans—look for hidden details in the queue!",
            "Check out the nighttime spectacular in Celestial Park for an unforgettable end to your day."
        ]
    ]

    private func currentTip() -> String? {
        guard let tips = parkTips[park.id], !tips.isEmpty else { return nil }
        return tips[tipIndex % tips.count]
    }

    private func personalizedRecommendations() -> [Attraction] {
        guard let attractions = viewModel.attractionsByPark[park.id] else { return [] }
        return attractions
            .sorted {
                let aOpen = $0.is_open == true && ($0.status?.lowercased() != "closed" && $0.status?.lowercased() != "down")
                let bOpen = $1.is_open == true && ($1.status?.lowercased() != "closed" && $1.status?.lowercased() != "down")
                if aOpen != bOpen { return aOpen }
                return ($0.wait_time ?? Int.max) < ($1.wait_time ?? Int.max)
            }
            .filter { $0.is_open == true && ($0.wait_time ?? 1000) < 20 }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        List {
            // Map button at the top
            Section {
                Button {
                    if let coord = park.coordinate {
                        myDayMapCenter = coord
                        selectedTab = 4 // Switch to My Day tab
                    }
                } label: {
                    Label("View Park on Map", systemImage: "map.fill")
                        .font(.headline)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }

            // Weather display
            if let forecast = viewModel.weatherByPark[park.id] {
                Section {
                    WeatherView(forecast: forecast)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .padding(.top)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: forecast.temperature)
                }
            } else {
                Section {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }
            }

            // Park tip/insider info (cycle through tips)
            if let tip = currentTip() {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.max.fill")
                            .foregroundColor(.yellow)
                            .font(.title2)
                            .scaleEffect(showTip ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: showTip)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Button {
                            tipIndex += 1
                            triggerHapticFeedback()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.accentColor)
                                .padding(8)
                                .background(Circle().fill(Color.accentColor.opacity(0.12)))
                        }
                        .accessibilityLabel("Show another tip")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.yellow.opacity(0.13))
                            .shadow(color: Color.yellow.opacity(0.08), radius: 6, x: 0, y: 2)
                    )
                    .onAppear { showTip = true }
                }
            }

            // Personalized recommendations with swipe and tap
            let recommendations = personalizedRecommendations()
            if !recommendations.isEmpty {
                Section(header: Text("Recommended For You").font(.headline)) {
                    ForEach(recommendations) { attraction in
                        NavigationLink(value: attraction) {
                            AttractionRowCardView(attraction: attraction)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                viewModel.toggleFavorite(attractionId: attraction.id)
                                triggerHapticFeedback()
                            } label: {
                                Label(
                                    viewModel.isFavorited(attractionId: attraction.id) ? "Unfavorite" : "Favorite",
                                    systemImage: viewModel.isFavorited(attractionId: attraction.id) ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                attractionForNotification = attraction
                                triggerHapticFeedback()
                            } label: {
                                Label("Notify", systemImage: "bell.fill")
                            }
                            .tint(.purple)
                        }
                    }
                }
            }

            // Attraction sections
            let landGroups = viewModel.attractionsByLand(for: park.id)
            if landGroups.isEmpty && !viewModel.isLoading {
                Section {
                    ContentUnavailableView("No Attraction Data", systemImage: "magnifyingglass")
                        .padding()
                }
            } else {
                ForEach(landGroups) { group in
                    Section(header:
                        Text(group.name)
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 5)
                    ) {
                        ForEach(
                            group.attractions
                                .sorted {
                                    let aOpen = $0.is_open == true && ($0.status?.lowercased() != "closed" && $0.status?.lowercased() != "down")
                                    let bOpen = $1.is_open == true && ($1.status?.lowercased() != "closed" && $1.status?.lowercased() != "down")
                                    if aOpen != bOpen { return aOpen }
                                    return ($0.wait_time ?? Int.max) < ($1.wait_time ?? Int.max)
                                }
                                .filter { attraction in
                                    switch selectedFilter {
                                    case .all: return true
                                    case .operating: return attraction.is_open == true
                                    case .shortWait: return (attraction.wait_time ?? 1000) < 20
                                    case .moderateWait:
                                        if let wait = attraction.wait_time { return wait >= 20 && wait <= 60 } else { return false }
                                    case .longWait: return (attraction.wait_time ?? 0) > 60
                                    }
                                }
                        ) { attraction in
                            NavigationLink(value: attraction) {
                                AttractionRowCardView(attraction: attraction)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets())
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    viewModel.toggleFavorite(attractionId: attraction.id)
                                    triggerHapticFeedback()
                                } label: {
                                    Label(
                                        viewModel.isFavorited(attractionId: attraction.id) ? "Unfavorite" : "Favorite",
                                        systemImage: viewModel.isFavorited(attractionId: attraction.id) ? "star.slash" : "star.fill"
                                    )
                                }
                                .tint(.yellow)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    attractionForNotification = attraction
                                    triggerHapticFeedback()
                                } label: {
                                    Label("Notify", systemImage: "bell.fill")
                                }
                                .tint(.purple)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(park.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Filter By", selection: $selectedFilter) {
                        ForEach(AttractionFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: { Image(systemName: "line.3.horizontal.decrease.circle").font(.title2) }
            }
        }
        .sheet(item: $attractionForNotification) { attraction in
            NotificationSettingView(attraction: attraction)
                .environmentObject(viewModel)
        }
        .task {
            await viewModel.fetchWeather(for: park)
        }
        .refreshable {
            await viewModel.fetchWeather(for: park)
            await viewModel.loadInitialData()
        }
        .background(
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.10),
                    Color.blue.opacity(0.08),
                    Color.green.opacity(0.07),
                    Color.yellow.opacity(0.06),
                    Color.orange.opacity(0.06),
                    Color.pink.opacity(0.07),
                    Color(.systemBackground)
                ]),
                center: .top,
                startRadius: 100,
                endRadius: 700
            )
            .ignoresSafeArea()
        )
    }
}

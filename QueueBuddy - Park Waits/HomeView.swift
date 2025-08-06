import SwiftUI
import CoreLocation

struct HomeView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @Binding var searchText: String
    @Binding var selectedTab: Int
    @Binding var myDayMapCenter: CLLocationCoordinate2D?
    @AppStorage("userDisplayName") private var userDisplayName: String = ""
    @State private var animateGradient = false
    @State private var showOnboarding = false

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 20)]

    private var filteredParks: [Park] {
        if searchText.isEmpty {
            return viewModel.resortGroups.flatMap { $0.parks }
        } else {
            return viewModel.resortGroups.flatMap { $0.parks }
                .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var groupedResortGroups: [ResortGroup] {
        if searchText.isEmpty {
            return viewModel.resortGroups
        } else {
            var grouped: [String: [Park]] = [:]
            for park in filteredParks {
                if let groupName = viewModel.resortGroups.first(where: { $0.parks.contains(park) })?.name {
                    grouped[groupName, default: []].append(park)
                }
            }
            return grouped.map { ResortGroup(name: $0.key, parks: $0.value) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.purple.opacity(0.10),
                        Color.blue.opacity(0.08),
                        Color.green.opacity(0.07),
                        Color.yellow.opacity(0.06),
                        Color.orange.opacity(0.06),
                        Color.pink.opacity(0.07),
                        Color(.systemBackground)
                    ]),
                    startPoint: animateGradient ? .topLeading : .bottomTrailing,
                    endPoint: animateGradient ? .bottomTrailing : .topLeading
                )
                .ignoresSafeArea()
                .hueRotation(.degrees(animateGradient ? 20 : 0))
                .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: animateGradient)
                .onAppear { animateGradient = true }

                VStack(spacing: 0) {
                    HStack {
                        Text("Good \(greetingTime()), \(userDisplayName.isEmpty ? "friend" : userDisplayName)! 👋")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    SearchBar(text: $searchText, placeholder: "Search attractions")
                        .padding(.horizontal)
                        .padding(.top, 4)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            ForEach(groupedResortGroups) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: group.name.contains("Disney") ? "sparkles" : "flame.fill")
                                            .foregroundColor(group.name.contains("Disney") ? .purple : .orange)
                                            .font(.title2)
                                        Text(group.name)
                                            .font(.title.bold())
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)

                                    LazyVGrid(columns: columns, spacing: 20) {
                                        ForEach(group.parks) { park in
                                            NavigationLink(value: park) {
                                                ParkCardView(park: park)
                                                    .environmentObject(viewModel)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical, 24)
                    }
                }
                .navigationTitle("Theme Parks")
                .overlay {
                    if viewModel.isLoading {
                        ProgressView("Loading Parks...")
                            .progressViewStyle(.circular)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                    }
                }
                .navigationDestination(for: Park.self) { park in
                    ParkDetailView(
                        park: park,
                        selectedTab: $selectedTab,
                        myDayMapCenter: $myDayMapCenter
                    )
                }
                .navigationDestination(for: Attraction.self) { attraction in
                    AttractionDetailView(attraction: attraction)
                }
                .task { [viewModel] in
                    guard viewModel.resortGroups.isEmpty else { return }
                    await viewModel.loadInitialData()
                }
                .onChange(of: searchText) { newValue in
                    if viewModel.searchTerm != newValue {
                        viewModel.searchTerm = newValue
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(userDisplayName: $userDisplayName, isPresented: $showOnboarding)
                }
            }
        }
        .onAppear {
            if userDisplayName.isEmpty {
                showOnboarding = true
            }
        }
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

import SwiftUI

struct FavoritedAttractionsView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @Binding var searchText: String

    private var favoritedAttractions: [Attraction] {
        viewModel.attractionsByPark.values
            .flatMap { $0 }
            .filter { viewModel.isFavorited(attractionId: $0.id) }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $searchText, placeholder: "Search favorites")
                    .padding(.horizontal)
                    .padding(.top, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if favoritedAttractions.isEmpty {
                            ContentUnavailableView("No Favorites Yet", systemImage: "star.slash")
                                .padding(.top, 40)
                        } else {
                            ForEach(favoritedAttractions) { attraction in
                                NavigationLink(value: attraction) {
                                    AttractionRowCardView(attraction: attraction)
                                        .environmentObject(viewModel)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        viewModel.toggleFavorite(attractionId: attraction.id)
                                        triggerHapticFeedback()
                                    } label: {
                                        Label("Unfavorite", systemImage: "star.slash")
                                    }
                                    .tint(.yellow)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        // Optionally, add notification logic here
                                    } label: {
                                        Label("Notify", systemImage: "bell.fill")
                                    }
                                    .tint(.purple)
                                }
                            }
                        }
                    }
                    .padding(.top, 16)
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
                .navigationTitle("Favorites")
                .refreshable {
                    await viewModel.loadInitialData()
                }
            }
        }
    }
}

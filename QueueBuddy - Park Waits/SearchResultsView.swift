import SwiftUI

struct SearchResultsView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var attractionForNotification: Attraction?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                // Filter Picker
                Picker("Filter", selection: $viewModel.currentFilter) {
                    ForEach(AttractionFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                .onChange(of: viewModel.currentFilter) { _, _ in triggerHapticFeedback() }
                
                // Sort Picker
                Picker("Sort", selection: $viewModel.currentSort) {
                    ForEach(AttractionSort.allCases) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: viewModel.currentSort) { _, _ in triggerHapticFeedback() }
                
                // List of search results
                List {
                    if viewModel.globalSearchResults.isEmpty && !viewModel.searchTerm.isEmpty {
                        ContentUnavailableView("No Results for \"\(viewModel.searchTerm)\"", systemImage: "magnifyingglass")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(viewModel.globalSearchResults) { attraction in
                            NavigationLink(value: attraction) {
                                AttractionRowView(attraction: attraction)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 2)
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
                .listStyle(.plain)
            }
            .navigationTitle("Search Attractions")
            .navigationDestination(for: Attraction.self) { attraction in
                AttractionDetailView(attraction: attraction)
            }
            .searchable(text: $viewModel.searchTerm, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by name")
            .sheet(item: $attractionForNotification) { attraction in
                NotificationSettingView(attraction: attraction)
                    .environmentObject(viewModel)
            }
        }
    }
}

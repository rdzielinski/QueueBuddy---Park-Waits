import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FavoritedAttractionsView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @Binding var searchText: String

    private var favoritedAttractions: [Attraction] {
        viewModel.attractionsByPark.values
            .flatMap { $0 }
            .filter { viewModel.isFavorited(attractionId: $0.id) }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { ($0.wait_time ?? Int.max) < ($1.wait_time ?? Int.max) }
    }

    /// Park accent color for a favorited attraction's home park.
    private func accent(for attractionId: Int) -> Color {
        let parkId = viewModel.attractionsByPark
            .first(where: { $0.value.contains(where: { $0.id == attractionId }) })?.key
        return parkId.map { DB.accent(for: $0) } ?? DB.amber
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DB.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        searchBar
                            .padding(.horizontal, 16)

                        if favoritedAttractions.isEmpty {
                            emptyState
                                .padding(.top, 40)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(favoritedAttractions.enumerated()), id: \.element.id) { idx, attraction in
                                    NavigationLink(value: attraction) {
                                        AttractionRowCardView(
                                            attraction: attraction,
                                            routeColor: accent(for: attraction.id),
                                            showMetaLine: true
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    #if !os(tvOS)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button {
                                            viewModel.toggleFavorite(attractionId: attraction.id)
                                            triggerHaptic()
                                        } label: {
                                            Label("Unfavorite", systemImage: "star.slash")
                                        }
                                        .tint(.yellow)
                                    }
                                    #endif
                                    if idx < favoritedAttractions.count - 1 {
                                        Rectangle().fill(DB.line).frame(height: 1)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(DB.card)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 16)
                        }

                        Color.clear.frame(height: 120)
                    }
                }
                .refreshable {
                    await viewModel.refreshAllWaits()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Attraction.self) { attraction in
                AttractionDetailView(attraction: attraction)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: "\(favoritedAttractions.count) SAVED", color: DB.muted)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("Favorites")
                    .font(DB.displayTitle(34))
                    .foregroundStyle(DB.text)
                    .tracking(-0.8)
                Text(".")
                    .font(DB.displayTitle(34))
                    .foregroundStyle(DB.amber)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Text(">")
                .font(DB.mono(14, weight: .bold))
                .foregroundStyle(DB.amber)
            TextField(
                "",
                text: $searchText,
                prompt: Text("filter favorites…")
                    .foregroundStyle(DB.muted)
                    .font(DB.mono(14))
            )
            .font(DB.mono(14))
            .foregroundStyle(DB.text)
            .tint(DB.amber)
            .autocorrectionDisabled(true)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DB.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DB.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "star.slash")
                .font(.system(size: 30))
                .foregroundStyle(DB.amber.opacity(0.7))
            MonoLabel(text: "NO FAVORITES YET", color: DB.muted)
            Text("Tap the ★ on any attraction to save it here.")
                .font(.system(size: 13))
                .foregroundStyle(DB.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

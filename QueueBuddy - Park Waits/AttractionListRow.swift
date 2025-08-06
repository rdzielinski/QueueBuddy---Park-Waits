import SwiftUI

struct AttractionListRow: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    let attraction: Attraction
    var showNotificationAction: Bool = true
    @Binding var notificationAttraction: Attraction?
    
    func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    var body: some View {
        NavigationLink(value: attraction) {
            AttractionRowView(attraction: attraction)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                viewModel.toggleFavorite(attractionId: attraction.id)
                triggerHapticFeedback()
            } label: {
                if viewModel.isFavorited(attractionId: attraction.id) {
                    Label("Unfavorite", systemImage: "star.slash.fill")
                } else {
                    Label("Favorite", systemImage: "star.fill")
                }
            }
            .tint(.yellow)

            if showNotificationAction {
                Button {
                    notificationAttraction = attraction
                    triggerHapticFeedback()
                } label: {
                    Label("Notify", systemImage: "bell.fill")
                }
                .tint(.purple)
            }
        }
    }
}

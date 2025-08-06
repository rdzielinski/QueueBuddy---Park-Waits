import SwiftUI

struct ParkStatsAndToggleView: View {
    @EnvironmentObject private var viewModel: WaitTimeViewModel
    let park: Park

    var body: some View {
        let vm = viewModel

        HStack(spacing: 20) {
            // Favorite toggle must use attractionId:
            Button {
                vm.toggleFavorite(attractionId: park.id)
            } label: {
                Image(systemName:
                    vm.favoriteAttractionIds.contains(park.id) ? "heart.fill" : "heart"
                )
            }

            // Correct usage of averageWaitTime as a function:
            Text("Avg Wait: \(vm.averageWaitTime(for: park.id))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

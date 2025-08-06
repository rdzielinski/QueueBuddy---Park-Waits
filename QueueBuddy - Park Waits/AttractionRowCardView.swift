import SwiftUI

struct AttractionRowCardView: View {
    let attraction: Attraction
    @EnvironmentObject var viewModel: WaitTimeViewModel

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: attraction.type ?? "questionmark.circle.fill")
                .font(.title2)
                .frame(width: 36, height: 36)
                .foregroundColor(.accentColor)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(attraction.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                if attraction.is_open == false {
                    Text("Closed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(attraction.waitTimeDisplay)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(WaitTimeViewModel.statusColor(status: attraction.status, waitTime: attraction.wait_time, isOpen: attraction.is_open).opacity(0.18))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.85))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }
}

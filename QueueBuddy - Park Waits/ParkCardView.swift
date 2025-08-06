import SwiftUI

struct ParkCardView: View {
    let park: Park
    @EnvironmentObject var viewModel: WaitTimeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(park.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.7))
            }
            if viewModel.isParkLikelyClosed(parkId: park.id) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(.red)
                    Text("Park is likely closed")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            } else {
                HStack(spacing: 12) {
                    Label("\(viewModel.operatingAttractionCount(for: park.id)) open", systemImage: "figure.walk.motion")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                    Label(viewModel.averageWaitTime(for: park.id), systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.7),
                    Color.purple.opacity(0.6),
                    Color.accentColor.opacity(0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .hoverEffect(.highlight)
    }
}

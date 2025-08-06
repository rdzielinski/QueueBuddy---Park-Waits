import SwiftUI

struct AttractionRowView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    let attraction: Attraction
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(WaitTimeViewModel.statusColor(status: attraction.status, waitTime: attraction.wait_time, isOpen: attraction.is_open))
                .frame(width: 6)

            HStack(spacing: 12) {
                // FIXED: Provide a default value for the symbol in case it's nil.
                // This resolves the "must be unwrapped" error.
                Image(systemName: StaticData.getSFならSymbol(for: attraction.id))
                    .font(.title2)
                    .frame(width: 30)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(attraction.name)
                        .font(.headline)
                        .lineLimit(1)
                    
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(in: Capsule())
                    .backgroundStyle(WaitTimeViewModel.statusColor(status: attraction.status, waitTime: attraction.wait_time, isOpen: attraction.is_open).opacity(0.2))
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}


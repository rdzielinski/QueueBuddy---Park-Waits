import SwiftUI

struct ParkRowView: View {
    let park: Park
    @EnvironmentObject var viewModel: WaitTimeViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(park.name)
                    .font(.body.weight(.medium))
                
                Text("Open: \(viewModel.operatingAttractionCount(for: park.id)) | Avg Wait: \(viewModel.averageWaitTime(for: park.id))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .background(ColorfulBackground())
    }
}

struct ResortGroupSectionView: View {
    let resortGroup: ResortGroup
    @EnvironmentObject var viewModel: WaitTimeViewModel

    var body: some View {
        ZStack {
            ColorfulBackground()
            Section(header: Text(resortGroup.name).font(.headline)) {
                ForEach(resortGroup.parks) { park in
                    NavigationLink(value: park) {
                        ParkRowView(park: park)
                    }
                }
            }
        }
    }
}


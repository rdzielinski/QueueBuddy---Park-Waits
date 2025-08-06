// ManualWaitTimeEntryView.swift

import SwiftUI

struct ManualWaitTimeEntryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WaitTimeViewModel
    let attraction: Attraction
    @State private var manualMinutes: Double = 30

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Manually Add Wait Time for")
                    .font(.headline)
                Text(attraction.name)
                    .font(.title).bold()
                    .multilineTextAlignment(.center)
                Spacer()
                VStack {
                    Text("\(Int(manualMinutes)) minutes")
                        .font(.largeTitle)
                        .bold()
                    Slider(value: $manualMinutes, in: 0...180, step: 5)
                        .tint(.accentColor)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(15)
                Spacer()
                Button("Add Wait Time") {
                    viewModel.addWaitTime(manualMinutes * 60, forEntityId: attraction.id)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(15)
            }
            .padding()
            .navigationTitle("Add Wait Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

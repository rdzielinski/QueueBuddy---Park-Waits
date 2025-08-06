import SwiftUI

struct NotificationSettingView: View {
    @EnvironmentObject private var viewModel: WaitTimeViewModel
    // This gives the view the ability to dismiss itself.
    @Environment(\.dismiss) var dismiss
    
    let attraction: Attraction
    @State private var thresholdMinutes: Double = 15

    // REMOVED: The old @Binding var isPresented: Bool is no longer needed.

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        Text("Notify me when wait is")
                            .font(.headline)
                        Text("≤ \(Int(thresholdMinutes)) min")
                            .font(.largeTitle.bold())
                            .foregroundColor(.accentColor)
                        Slider(value: $thresholdMinutes, in: 1...120, step: 5)
                            .tint(.accentColor)
                        HStack {
                            Text("1 min").font(.caption)
                            Spacer()
                            Text("120 min").font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                }
                Section {
                    Button("Save Notification") {
                        viewModel.addNotification(for: attraction, threshold: Int(thresholdMinutes))
                        // Call dismiss() to close the sheet.
                        dismiss()
                    }
                }
            }
            .navigationTitle("Notification Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Call dismiss() to close the sheet.
                        dismiss()
                    }
                }
            }
            .onAppear {
                // This logic correctly pre-fills the slider if a notification already exists.
                if let preference = viewModel.notificationPreferences.first(where: { $0.id == attraction.id }) {
                    thresholdMinutes = Double(preference.thresholdMinutes)
                }
            }
        }
    }
}

import SwiftUI

struct NotificationListView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @State private var editingPreference: NotificationPreference?

    private var notificationPreferences: [NotificationPreference] {
        viewModel.notificationPreferences.sorted { $0.attractionName < $1.attractionName }
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text("Notifications")
                    .font(.largeTitle.bold())
                    .padding(.top, 16)
                List {
                    if notificationPreferences.isEmpty {
                        ContentUnavailableView("No Notifications Set", systemImage: "bell.slash")
                    } else {
                        ForEach(notificationPreferences) { preference in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(preference.attractionName).font(.headline)
                                    Text("Notify when wait is \(preference.thresholdMinutes) min or less")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    editingPreference = preference
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Edit notification for \(preference.attractionName)")
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    viewModel.removeNotification(for: preference.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .sheet(item: $editingPreference) { preference in
                    EditNotificationPreferenceView(preference: preference)
                        .environmentObject(viewModel)
                }
            }
        }
    }
}

struct EditNotificationPreferenceView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @Environment(\.dismiss) var dismiss

    let preference: NotificationPreference
    @State private var thresholdMinutes: Double

    init(preference: NotificationPreference) {
        self.preference = preference
        _thresholdMinutes = State(initialValue: Double(preference.thresholdMinutes))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Notify me when wait is ≤ \(Int(thresholdMinutes)) minutes") {
                    Slider(value: $thresholdMinutes, in: 1...120, step: 1)
                }
                Section {
                    Button("Save") {
                        if let attraction = viewModel.attractionsByPark.values.flatMap({ $0 }).first(where: { $0.id == preference.id }) {
                            viewModel.addNotification(for: attraction, threshold: Int(thresholdMinutes))
                        }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Edit Notification")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

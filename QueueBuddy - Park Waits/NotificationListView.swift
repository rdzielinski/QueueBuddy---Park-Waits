import SwiftUI

struct NotificationListView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @State private var editingPreference: NotificationPreference?

    private var notificationPreferences: [NotificationPreference] {
        viewModel.notificationPreferences.sorted { $0.attractionName < $1.attractionName }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DB.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        if notificationPreferences.isEmpty {
                            emptyState
                                .padding(.top, 40)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(notificationPreferences.enumerated()), id: \.element.id) { idx, pref in
                                    row(for: pref)
                                    if idx < notificationPreferences.count - 1 {
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
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editingPreference) { preference in
                EditNotificationPreferenceView(preference: preference)
                    .environmentObject(viewModel)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: "\(notificationPreferences.count) ACTIVE", color: DB.muted)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("Alerts")
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

    private func row(for preference: NotificationPreference) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 14))
                .foregroundStyle(DB.amber)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(DB.amber.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(preference.attractionName)
                    .font(DB.heading(15, weight: .medium))
                    .foregroundStyle(DB.text)
                    .lineLimit(1)
                Text("NOTIFY WHEN ≤ \(preference.thresholdMinutes) MIN")
                    .font(DB.mono(10))
                    .tracking(1.5)
                    .foregroundStyle(DB.muted)
            }

            Spacer()

            Button { editingPreference = preference } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(DB.muted)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Color.white.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        #if !os(tvOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.removeNotification(for: preference.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.slash")
                .font(.system(size: 30))
                .foregroundStyle(DB.amber.opacity(0.7))
            MonoLabel(text: "NO ALERTS SET", color: DB.muted)
            Text("Tap the bell on any attraction to get notified when the wait drops.")
                .font(.system(size: 13))
                .foregroundStyle(DB.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
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
            ZStack {
                DB.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    MonoLabel(text: "EDIT ALERT", color: DB.amber)
                    Text(preference.attractionName)
                        .font(DB.displayTitle(24))
                        .foregroundStyle(DB.text)
                        .tracking(-0.4)

                    VStack(alignment: .leading, spacing: 10) {
                        MonoLabel(text: "NOTIFY WHEN WAIT ≤ \(Int(thresholdMinutes)) MIN", color: DB.muted)
                        #if os(tvOS)
                        Picker("", selection: $thresholdMinutes) {
                            ForEach(1...120, id: \.self) { v in Text("\(v) min").tag(Double(v)) }
                        }
                        #else
                        Slider(value: $thresholdMinutes, in: 1...120, step: 1)
                            .tint(DB.amber)
                        #endif
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DB.card)
                    )

                    Button {
                        if let attraction = viewModel.attractionsByPark.values.flatMap({ $0 }).first(where: { $0.id == preference.id }) {
                            viewModel.addNotification(for: attraction, threshold: Int(thresholdMinutes))
                        }
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(DB.heading(16, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x0A0B0D))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(DB.amber)
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DB.muted)
                }
            }
        }
    }
}

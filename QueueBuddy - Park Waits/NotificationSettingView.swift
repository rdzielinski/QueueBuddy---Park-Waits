import SwiftUI

struct NotificationSettingView: View {
    @EnvironmentObject private var viewModel: WaitTimeViewModel
    @Environment(\.dismiss) var dismiss

    let attraction: Attraction
    @State private var thresholdMinutes: Double = 15

    var body: some View {
        NavigationStack {
            ZStack {
                DB.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    MonoLabel(text: "NEW ALERT", color: DB.amber)
                    Text(attraction.name)
                        .font(DB.displayTitle(24))
                        .foregroundStyle(DB.text)
                        .tracking(-0.4)

                    VStack(alignment: .leading, spacing: 14) {
                        MonoLabel(text: "NOTIFY ME WHEN WAIT IS", color: DB.muted)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("≤")
                                .font(DB.mono(28, weight: .bold))
                                .foregroundStyle(DB.muted)
                            FlapDigits(value: Int(thresholdMinutes), size: 56, tone: DB.amber, label: "MIN")
                        }
                        #if os(tvOS)
                        Picker("", selection: $thresholdMinutes) {
                            ForEach(Array(stride(from: 5.0, through: 120.0, by: 5.0)), id: \.self) { v in
                                Text("\(Int(v)) min").tag(v)
                            }
                        }
                        #else
                        Slider(value: $thresholdMinutes, in: 1...120, step: 5)
                            .tint(DB.amber)
                        #endif
                        HStack {
                            MonoLabel(text: "1 MIN", color: DB.dim, tracking: 1.5, size: 10)
                            Spacer()
                            MonoLabel(text: "120 MIN", color: DB.dim, tracking: 1.5, size: 10)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DB.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                    )

                    Button {
                        viewModel.addNotification(for: attraction, threshold: Int(thresholdMinutes))
                        dismiss()
                    } label: {
                        Text("Save Notification")
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
            .onAppear {
                if let pref = viewModel.notificationPreferences.first(where: { $0.id == attraction.id }) {
                    thresholdMinutes = Double(pref.thresholdMinutes)
                }
            }
        }
    }
}

import SwiftUI

struct ManualWaitTimeEntryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: WaitTimeViewModel
    let attraction: Attraction
    @State private var manualMinutes: Double = 30

    var body: some View {
        NavigationStack {
            ZStack {
                DB.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    MonoLabel(text: "REPORT YOUR WAIT", color: DB.amber)
                    Text(attraction.name)
                        .font(DB.displayTitle(24))
                        .foregroundStyle(DB.text)
                        .tracking(-0.4)

                    VStack(spacing: 16) {
                        FlapDigits(value: Int(manualMinutes), size: 72, tone: DB.amber, label: "MIN")
                            .frame(maxWidth: .infinity)
                        #if os(tvOS)
                        HStack(spacing: 40) {
                            Button {
                                if manualMinutes > 0 { manualMinutes -= 5 }
                            } label: {
                                Image(systemName: "minus.circle.fill").font(.largeTitle)
                            }
                            .disabled(manualMinutes <= 0)
                            Button {
                                if manualMinutes < 180 { manualMinutes += 5 }
                            } label: {
                                Image(systemName: "plus.circle.fill").font(.largeTitle)
                            }
                            .disabled(manualMinutes >= 180)
                        }
                        #else
                        Slider(value: $manualMinutes, in: 0...180, step: 5)
                            .tint(DB.amber)
                        #endif
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(DB.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                    )

                    Button {
                        viewModel.addWaitTime(manualMinutes * 60, forEntityId: attraction.id)
                        dismiss()
                    } label: {
                        Text("Submit")
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

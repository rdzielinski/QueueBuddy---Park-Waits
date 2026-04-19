import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @Binding var userDisplayName: String
    @Binding var isPresented: Bool

    @AppStorage("preferredParkId") private var preferredParkId: Int = 0
    @AppStorage("childHeightInches") private var childHeightInches: Int = 0

    @State private var tempDisplayName: String = ""
    @State private var step: Int = 0

    private var allParks: [Park] {
        viewModel.resortGroups.flatMap { $0.parks }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DB.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    MonoLabel(text: progressLabel, color: DB.amber)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(stepTitle)
                            .font(DB.displayTitle(30))
                            .foregroundStyle(DB.text)
                            .tracking(-0.6)
                            .animation(nil, value: step)
                        Text(".")
                            .font(DB.displayTitle(30))
                            .foregroundStyle(DB.amber)
                    }

                    switch step {
                    case 0: nameStep
                    case 1: parkStep
                    default: heightStep
                    }

                    Spacer()

                    Button(action: advance) {
                        HStack {
                            Text(step == 2 ? "FINISH" : "CONTINUE").tracking(1.5)
                            Image(systemName: "arrow.right")
                        }
                        .font(DB.mono(13, weight: .bold))
                        .foregroundStyle(Color(hex: 0x0A0B0D))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DB.amber.opacity(canAdvance ? 1 : 0.4))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAdvance)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { finish() }
                        .foregroundStyle(DB.muted)
                }
                if step > 0 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Back") { step -= 1 }
                            .foregroundStyle(DB.muted)
                    }
                }
            }
            .onAppear { tempDisplayName = userDisplayName }
        }
    }

    // MARK: - Steps

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What should we call you on the board?")
                .font(.system(size: 15))
                .foregroundStyle(DB.muted)
            HStack(spacing: 10) {
                Text(">")
                    .font(DB.mono(16, weight: .bold))
                    .foregroundStyle(DB.amber)
                TextField(
                    "",
                    text: $tempDisplayName,
                    prompt: Text("your name or nickname").foregroundStyle(DB.muted)
                )
                .font(DB.mono(14))
                .foregroundStyle(DB.text)
                .tint(DB.amber)
                #if !os(tvOS)
                .textFieldStyle(.plain)
                #endif
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DB.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    private var parkStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which park do you visit most?")
                .font(.system(size: 15))
                .foregroundStyle(DB.muted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(allParks) { park in
                    Button {
                        preferredParkId = park.id
                    } label: {
                        HStack(spacing: 10) {
                            Circle().fill(DB.accent(for: park.id))
                                .frame(width: 8, height: 8)
                                .shadow(color: DB.accent(for: park.id), radius: 3)
                            Text(park.name)
                                .font(DB.heading(13, weight: .medium))
                                .foregroundStyle(DB.text)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            if preferredParkId == park.id {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(DB.accent(for: park.id))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DB.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            preferredParkId == park.id ? DB.accent(for: park.id).opacity(0.6) : Color.white.opacity(0.06),
                                            lineWidth: preferredParkId == park.id ? 1.5 : 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var heightStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Traveling with a kid? Set their height for better ride picks.")
                .font(.system(size: 15))
                .foregroundStyle(DB.muted)

            HStack(spacing: 12) {
                FlapDigits(
                    value: childHeightInches == 0 ? nil : childHeightInches,
                    size: 56, tone: DB.amber,
                    label: "INCHES"
                )
                Spacer()
                if childHeightInches > 0 {
                    Text("\(childHeightInches)\" ≈ \(Int((Double(childHeightInches) * 2.54).rounded())) cm")
                        .font(DB.mono(11))
                        .foregroundStyle(DB.muted)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DB.card)
            )

            #if !os(tvOS)
            Slider(
                value: Binding(
                    get: { Double(childHeightInches) },
                    set: { childHeightInches = Int($0) }
                ),
                in: 0...60,
                step: 1
            )
            .tint(DB.amber)
            HStack {
                MonoLabel(text: "NO KIDS", color: DB.dim, tracking: 1.5, size: 10)
                Spacer()
                MonoLabel(text: "60\"", color: DB.dim, tracking: 1.5, size: 10)
            }
            #endif
        }
    }

    // MARK: - State

    private var progressLabel: String {
        switch step {
        case 0: return "STEP 1 OF 3"
        case 1: return "STEP 2 OF 3"
        default: return "STEP 3 OF 3"
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Welcome"
        case 1: return "Home park"
        default: return "Height"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return !tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: return true
        }
    }

    private func advance() {
        if step < 2 {
            step += 1
        } else {
            finish()
        }
    }

    private func finish() {
        userDisplayName = tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        isPresented = false
    }
}

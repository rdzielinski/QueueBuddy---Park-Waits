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
                                    SwipeToDeleteRow {
                                        viewModel.removeNotification(for: pref.id)
                                    } content: {
                                        row(for: pref)
                                    }
                                    if idx < notificationPreferences.count - 1 {
                                        Rectangle().fill(DB.line).frame(height: 1)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(DB.card)
                            )
                            // Clip so the revealed delete action stays inside
                            // the rounded card; keep the hairline stroke on top.
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                        }

                        Color.clear.frame(height: 120)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .swipeBackEnabled()
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

/// Wraps a row so it can be swiped left to reveal a red Delete action.
/// Built by hand (rather than `swipeActions`, which only works inside a
/// `List`) so the Alerts screen keeps its custom carded layout while still
/// supporting swipe-to-delete down to the iOS 18 deployment target.
private struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    /// Committed resting offset: 0 when closed, -revealWidth when the
    /// delete button is held open.
    @State private var offset: CGFloat = 0
    /// Live finger translation while a horizontal drag is in flight.
    @GestureState private var drag: CGFloat = 0

    private let revealWidth: CGFloat = 88
    private let fullSwipeThreshold: CGFloat = 220

    /// Only ever moves leftward (negative); clamps at 0 so the row can't be
    /// dragged to the right past its resting position.
    private var totalOffset: CGFloat {
        min(0, offset + drag)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    onDelete()
                }
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: revealWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
            }
            .buttonStyle(.plain)
            .opacity(totalOffset < 0 ? 1 : 0)

            content()
                .background(DB.card)
                // When open, swallow taps anywhere on the row to close it
                // (so the user doesn't accidentally trigger the edit button).
                .overlay {
                    if offset < 0 {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    offset = 0
                                }
                            }
                    }
                }
                .offset(x: totalOffset)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .updating($drag) { value, state, _ in
                    // Treat as a swipe only when motion is mostly horizontal,
                    // so vertical scrolling still wins inside the ScrollView.
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    state = value.translation.width
                }
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let predicted = offset + value.translation.width
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        if -predicted > fullSwipeThreshold {
                            offset = 0
                            onDelete()
                        } else if -predicted > revealWidth / 2 {
                            offset = -revealWidth
                        } else {
                            offset = 0
                        }
                    }
                }
        )
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
            .swipeBackEnabled()
        }
    }
}

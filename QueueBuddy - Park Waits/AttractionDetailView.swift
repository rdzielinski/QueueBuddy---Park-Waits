import SwiftUI
import UIKit

private enum ActiveSheet: Identifiable {
    case notification, manualEntry
    var id: Int {
        switch self {
        case .notification: return 0
        case .manualEntry: return 1
        }
    }
}

/// Departure-board attraction detail: route-colored hero with giant flap digits,
/// stat grid, about copy, and a wait-report prompt.
struct AttractionDetailView: View {
    @EnvironmentObject private var viewModel: WaitTimeViewModel
    @Environment(\.dismiss) private var dismiss
    let attraction: Attraction

    @State private var activeSheet: ActiveSheet? = nil

    private var parkId: Int? {
        viewModel.attractionsByPark.first(where: { $0.value.contains(where: { $0.id == attraction.id }) })?.key
    }

    private var parkName: String {
        guard let pid = parkId,
              let park = viewModel.resortGroups.flatMap({ $0.parks }).first(where: { $0.id == pid }) else {
            return "PARKS"
        }
        return park.name.uppercased()
    }

    private var accent: Color {
        if let pid = parkId { return DB.accent(for: pid) }
        return DB.amber
    }

    private var waitTone: Color {
        if attraction.is_open == false { return DB.muted }
        return DB.waitTone(for: attraction.wait_time)
    }

    private var landName: String? {
        StaticData.attractionToLandMapping[attraction.id]
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    var body: some View {
        ZStack {
            DB.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    navRow
                        .padding(.horizontal, 14)
                        .padding(.top, 8)

                    hero
                        .padding(.horizontal, 16)

                    statsGrid
                        .padding(.horizontal, 16)

                    aboutBlock
                        .padding(.horizontal, 16)

                    trendingBlock
                        .padding(.horizontal, 16)

                    reportWaitPrompt
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .notification:
                NotificationSettingView(attraction: attraction)
                    .environmentObject(viewModel)
            case .manualEntry:
                ManualWaitTimeEntryView(attraction: attraction)
                    .environmentObject(viewModel)
            }
        }
    }

    // MARK: - Sections

    private var navRow: some View {
        HStack {
            Button {
                triggerHaptic()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Text("‹")
                    Text(parkName).tracking(1.5)
                }
                .font(DB.mono(12))
                .foregroundStyle(DB.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.white.opacity(0.05))
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                iconButton(systemName: viewModel.isFavorited(attractionId: attraction.id) ? "star.fill" : "star",
                           tint: DB.amber) {
                    viewModel.toggleFavorite(attractionId: attraction.id)
                    triggerHaptic()
                }
                iconButton(systemName: viewModel.isNotificationSet(for: attraction.id) ? "bell.fill" : "bell",
                           tint: viewModel.isNotificationSet(for: attraction.id) ? DB.amber : DB.muted) {
                    if viewModel.isNotificationSet(for: attraction.id) {
                        viewModel.removeNotification(for: attraction.id)
                    } else {
                        activeSheet = .notification
                    }
                    triggerHaptic()
                }
            }
        }
    }

    private func iconButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(Color.white.opacity(0.05))
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(
                    colors: [DB.card2, DB.card],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(waitTone.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    RadialGradient(
                        colors: [waitTone.opacity(0.16), .clear],
                        center: .topTrailing,
                        startRadius: 0, endRadius: 240
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    RouteStripe(color: accent, width: 22)
                    if let landName {
                        Text(landName.uppercased())
                            .font(DB.mono(11))
                            .tracking(2)
                            .foregroundStyle(accent)
                            .lineLimit(1)
                    }
                }
                HStack(alignment: .top, spacing: 14) {
                    AttractionGlyph(
                        attractionId: attraction.id,
                        attractionType: attraction.type,
                        tint: accent,
                        size: 48
                    )
                    Text(attraction.name)
                        .font(DB.displayTitle(26))
                        .foregroundStyle(DB.text)
                        .tracking(-0.6)
                        .lineLimit(3)
                }

                if !metaLine.isEmpty {
                    MonoLabel(text: metaLine, color: DB.muted, tracking: 1.5, size: 11)
                        .padding(.bottom, 14)
                } else {
                    Color.clear.frame(height: 14)
                }

                HStack(alignment: .bottom) {
                    FlapDigits(
                        value: attraction.is_open == false ? nil : attraction.wait_time,
                        size: 64,
                        tone: waitTone,
                        label: attraction.is_open == false ? "CLOSED" : "MIN WAIT"
                    )
                    Spacer()
                    if let updated = attraction.last_updated, let fresh = relativeUpdate(updated) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("UPDATED").tracking(1.5)
                            Text(fresh).tracking(1.5)
                        }
                        .font(DB.mono(10))
                        .foregroundStyle(DB.dim)
                        .padding(.bottom, 10)
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        activeSheet = .notification
                        triggerHaptic()
                    } label: {
                        Text("Notify me when open ≤ 30 min")
                            .font(DB.heading(14, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x0A0B0D))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(waitTone)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        activeSheet = .manualEntry
                        triggerHaptic()
                    } label: {
                        Image(systemName: "timer")
                            .font(.system(size: 16))
                            .foregroundStyle(DB.text)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
            }
            .padding(20)
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        if let type = attraction.type, !type.isEmpty { parts.append(type.uppercased()) }
        if let minH = attraction.min_height_inches, minH > 0 { parts.append("\(minH)\" MIN") }
        return parts.joined(separator: " · ")
    }

    private func relativeUpdate(_ iso: String) -> String? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return nil }
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "JUST NOW" }
        if mins < 60 { return "\(mins) MIN AGO" }
        let hrs = mins / 60
        return "\(hrs)H AGO"
    }

    private var statsGrid: some View {
        let rows: [(String, String)] = {
            var out: [(String, String)] = []
            if let type = attraction.type, !type.isEmpty {
                out.append(("TYPE", type.uppercased()))
            } else {
                out.append(("TYPE", "—"))
            }
            if let minH = attraction.min_height_inches, minH > 0 {
                let cm = Int((Double(minH) * 2.54).rounded())
                out.append(("HEIGHT", "\(minH)\" / \(cm)cm"))
            } else {
                out.append(("HEIGHT", "ANY"))
            }
            out.append(("STATUS", attraction.is_open == false ? "CLOSED" : "OPEN"))
            if let w = attraction.wait_time, attraction.is_open != false {
                let tier = w <= 15 ? "SHORT" : (w <= 45 ? "MODERATE" : "LONG")
                out.append(("QUEUE", tier))
            } else {
                out.append(("QUEUE", "—"))
            }
            return out
        }()

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: 4) {
                    MonoLabel(text: row.0, color: DB.muted, tracking: 1.5, size: 10)
                    Text(row.1)
                        .font(DB.mono(15, weight: .semibold))
                        .foregroundStyle(DB.text)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DB.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )
            }
        }
    }

    @ViewBuilder
    private var trendingBlock: some View {
        let history = WaitHistoryStore.shared.history(for: attraction.id)
        if history.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MonoLabel(text: "→ TRENDING · LAST 24 HOURS", color: DB.muted)
                    Spacer()
                    if let delta = WaitHistoryStore.shared.trendDelta(for: attraction.id) {
                        HStack(spacing: 4) {
                            Image(systemName: delta > 0 ? "arrow.up" : (delta < 0 ? "arrow.down" : "minus"))
                            Text(delta == 0 ? "FLAT" : "\(abs(delta))M vs 1H AGO")
                        }
                        .font(DB.mono(10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(delta > 0 ? DB.red : (delta < 0 ? DB.green : DB.muted))
                    }
                }
                Sparkline(samples: history, tone: waitTone)
                    .frame(height: 80)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(DB.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                    )
            }
        }
    }

    @ViewBuilder
    private var aboutBlock: some View {
        if let desc = attraction.description, !desc.isEmpty, desc != "No additional details available." {
            VStack(alignment: .leading, spacing: 10) {
                MonoLabel(text: "→ ABOUT", color: DB.muted)
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundStyle(DB.text)
                    .lineSpacing(4)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(DB.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                    )
            }
        }
    }

    private var reportWaitPrompt: some View {
        Button {
            activeSheet = .manualEntry
            triggerHaptic()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    MonoLabel(text: "IN LINE?", color: DB.muted, tracking: 1.5, size: 10)
                    Text("Report your actual wait")
                        .font(.system(size: 14))
                        .foregroundStyle(DB.text)
                }
                Spacer()
                Text("Enter →")
                    .font(DB.mono(13))
                    .foregroundStyle(DB.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.white.opacity(0.06))
                    )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

import WidgetKit
import SwiftUI

// MARK: - Entry

struct FavoritesWaitEntry: TimelineEntry {
    let date: Date
    let favorites: [(park: WaitCacheReader.CachedPark, attraction: WaitCacheReader.CachedAttraction)]
    let lastSync: Date?
}

// MARK: - Provider

struct FavoritesWaitProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritesWaitEntry {
        FavoritesWaitEntry(date: .now, favorites: [], lastSync: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritesWaitEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesWaitEntry>) -> Void) {
        let entry = buildEntry()
        // Refresh every 10 minutes — the main app writes to the cache on each
        // background refresh, so the widget just re-reads from disk.
        let next = Date().addingTimeInterval(10 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func buildEntry() -> FavoritesWaitEntry {
        FavoritesWaitEntry(
            date: .now,
            favorites: WaitCacheReader.loadFavoriteAttractions(limit: 4),
            lastSync: WaitCacheReader.lastSync
        )
    }
}

// MARK: - Views

struct FavoritesWaitWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: FavoritesWaitEntry

    var body: some View {
        ZStack {
            WidgetTheme.bg
            content
                .padding(family == .systemSmall ? 10 : 14)
        }
        .foregroundStyle(WidgetTheme.text)
        .containerBackground(WidgetTheme.bg, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:  smallLayout
        case .systemMedium: mediumLayout
        case .systemLarge:  largeLayout
        default:            mediumLayout
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle().fill(WidgetTheme.green).frame(width: 5, height: 5)
                .shadow(color: WidgetTheme.green, radius: 3)
            Text("LIVE · QUEUEBUDDY")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(WidgetTheme.muted)
            Spacer()
        }
    }

    @ViewBuilder
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if let top = entry.favorites.first {
                Text(top.attraction.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                if let w = top.attraction.waitMinutes {
                    Text("\(w)")
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.tone(for: w))
                        .tracking(-1)
                    + Text(" MIN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.tone(for: w).opacity(0.8))
                } else {
                    Text(top.attraction.isOpen ? "OPEN" : "CLOSED")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidgetTheme.muted)
                }
                Text(top.park.name.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(WidgetTheme.muted)
                    .lineLimit(1)
            } else {
                emptyBody
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.favorites.isEmpty {
                emptyBody
            } else {
                ForEach(Array(entry.favorites.prefix(3).enumerated()), id: \.offset) { _, pair in
                    row(for: pair)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if entry.favorites.isEmpty {
                emptyBody
            } else {
                ForEach(Array(entry.favorites.prefix(5).enumerated()), id: \.offset) { _, pair in
                    row(for: pair)
                }
            }
            Spacer()
        }
    }

    private func row(for pair: (park: WaitCacheReader.CachedPark, attraction: WaitCacheReader.CachedAttraction)) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(WidgetTheme.color(fromHex: pair.park.accentHex))
                .frame(width: 5, height: 5)
                .shadow(color: WidgetTheme.color(fromHex: pair.park.accentHex), radius: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(pair.attraction.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(pair.park.name)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(WidgetTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
            waitPill(for: pair.attraction)
        }
    }

    @ViewBuilder
    private func waitPill(for a: WaitCacheReader.CachedAttraction) -> some View {
        if !a.isOpen {
            Text("CLSD")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(WidgetTheme.muted)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.06)))
        } else if let w = a.waitMinutes {
            let tone = WidgetTheme.tone(for: w)
            Text("\(w) MIN")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(tone)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(tone.opacity(0.15)))
        } else {
            Text("SHOW")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(WidgetTheme.amber)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(WidgetTheme.amber.opacity(0.12)))
        }
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No favorites yet")
                .font(.system(size: 13, weight: .semibold))
            Text("Open QueueBuddy and star any ride.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(WidgetTheme.muted)
        }
    }
}

// MARK: - Widget

struct FavoritesWaitWidget: Widget {
    let kind = "FavoritesWaitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritesWaitProvider()) { entry in
            FavoritesWaitWidgetView(entry: entry)
        }
        .configurationDisplayName("Favorite Waits")
        .description("Live wait times for your starred attractions.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

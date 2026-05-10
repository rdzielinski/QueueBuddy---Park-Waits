import WidgetKit
import SwiftUI

struct BestWaitsEntry: TimelineEntry {
    let date: Date
    let waits: [(park: WaitCacheReader.CachedPark, attraction: WaitCacheReader.CachedAttraction)]
    let lastSync: Date?
}

struct BestWaitsProvider: TimelineProvider {
    func placeholder(in context: Context) -> BestWaitsEntry {
        BestWaitsEntry(date: .now, waits: [], lastSync: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BestWaitsEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BestWaitsEntry>) -> Void) {
        let entry = buildEntry()
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(10 * 60))))
    }

    private func buildEntry() -> BestWaitsEntry {
        BestWaitsEntry(
            date: .now,
            waits: WaitCacheReader.loadBestWaits(limit: 5),
            lastSync: WaitCacheReader.lastSync
        )
    }
}

struct BestWaitsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BestWaitsEntry

    var body: some View {
        ZStack {
            WidgetTheme.bg
            VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 9) {
                header
                if entry.waits.isEmpty {
                    emptyBody
                } else if family == .systemSmall, let top = entry.waits.first {
                    topWait(top)
                } else {
                    ForEach(Array(entry.waits.prefix(family == .systemMedium ? 3 : 5).enumerated()), id: \.offset) { _, pair in
                        waitRow(pair)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(family == .systemSmall ? 10 : 14)
        }
        .foregroundStyle(WidgetTheme.text)
        .containerBackground(WidgetTheme.bg, for: .widget)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle().fill(WidgetTheme.green).frame(width: 5, height: 5)
                .shadow(color: WidgetTheme.green, radius: 3)
            Text("BEST WAITS")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(WidgetTheme.muted)
            Spacer()
        }
    }

    private func topWait(_ pair: (park: WaitCacheReader.CachedPark, attraction: WaitCacheReader.CachedAttraction)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pair.attraction.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
            Text(pair.attraction.waitMinutes.map { "\($0)" } ?? "OPEN")
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .foregroundStyle(WidgetTheme.tone(for: pair.attraction.waitMinutes))
                .tracking(-1)
            Text(pair.park.name.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(WidgetTheme.muted)
                .lineLimit(1)
        }
    }

    private func waitRow(_ pair: (park: WaitCacheReader.CachedPark, attraction: WaitCacheReader.CachedAttraction)) -> some View {
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
            Text(pair.attraction.waitMinutes.map { "\($0) MIN" } ?? "OPEN")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(WidgetTheme.tone(for: pair.attraction.waitMinutes))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(WidgetTheme.tone(for: pair.attraction.waitMinutes).opacity(0.15)))
        }
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No live waits")
                .font(.system(size: 13, weight: .semibold))
            Text("Open QueueBuddy to refresh park data.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(WidgetTheme.muted)
        }
    }
}

struct BestWaitsWidget: Widget {
    let kind = "BestWaitsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BestWaitsProvider()) { entry in
            BestWaitsWidgetView(entry: entry)
        }
        .configurationDisplayName("Best Waits")
        .description("The shortest open waits across your cached parks.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

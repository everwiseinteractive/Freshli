import WidgetKit
import SwiftUI

/// Freshli Watch Complication — shows a glanceable expiry count + items
/// saved on the watch face. Supports circular, rectangular, and inline
/// families so it works across all watch face styles.
struct FreshliWatchComplication: Widget {
    let kind = "FreshliWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FreshliComplicationProvider()) { entry in
            FreshliComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Freshli")
        .description("Track expiring items and your rescue impact.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Timeline Provider

struct FreshliComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> FreshliComplicationEntry {
        FreshliComplicationEntry(date: .now, expiringCount: 3, itemsSaved: 28, streakDays: 6)
    }

    func getSnapshot(in context: Context, completion: @escaping (FreshliComplicationEntry) -> Void) {
        completion(readCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FreshliComplicationEntry>) -> Void) {
        let entry = readCurrentEntry()
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readCurrentEntry() -> FreshliComplicationEntry {
        let defaults = UserDefaults(suiteName: "group.everwise.interactive.Freshli")
        return FreshliComplicationEntry(
            date: .now,
            expiringCount: defaults?.integer(forKey: "watchExpiringCount") ?? 0,
            itemsSaved: defaults?.integer(forKey: "watchItemsSaved") ?? 0,
            streakDays: defaults?.integer(forKey: "watchStreakDays") ?? 0
        )
    }
}

// MARK: - Entry

struct FreshliComplicationEntry: TimelineEntry {
    let date: Date
    let expiringCount: Int
    let itemsSaved: Int
    let streakDays: Int
}

// MARK: - Complication Views

struct FreshliComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: FreshliComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }

    // MARK: - Circular

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 1) {
                Image(systemName: entry.expiringCount > 0 ? "exclamationmark.triangle.fill" : "leaf.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(entry.expiringCount > 0 ? .orange : .green)

                Text("\(entry.expiringCount > 0 ? entry.expiringCount : entry.itemsSaved)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(entry.expiringCount > 0 ? "expiring" : "saved")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Rectangular

    private var rectangularView: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                    Text("Freshli")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }

                if entry.expiringCount > 0 {
                    Text("\(entry.expiringCount) expiring soon")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                } else {
                    Text("Pantry is fresh!")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }

                Text("\(entry.itemsSaved) saved this week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.streakDays > 0 {
                VStack(spacing: 1) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("\(entry.streakDays)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
            }
        }
    }

    // MARK: - Inline

    private var inlineView: some View {
        if entry.expiringCount > 0 {
            Label("\(entry.expiringCount) expiring · \(entry.itemsSaved) saved", systemImage: "leaf.fill")
        } else {
            Label("\(entry.itemsSaved) items saved this week", systemImage: "leaf.fill")
        }
    }

    // MARK: - Corner

    private var cornerView: some View {
        Text("\(entry.expiringCount > 0 ? entry.expiringCount : entry.itemsSaved)")
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .foregroundStyle(entry.expiringCount > 0 ? .orange : .green)
            .widgetLabel {
                Text(entry.expiringCount > 0 ? "expiring" : "saved")
            }
    }
}

// MARK: - Previews

#Preview("Circular - Expiring", as: .accessoryCircular) {
    FreshliWatchComplication()
} timeline: {
    FreshliComplicationEntry(date: .now, expiringCount: 3, itemsSaved: 28, streakDays: 6)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    FreshliWatchComplication()
} timeline: {
    FreshliComplicationEntry(date: .now, expiringCount: 2, itemsSaved: 15, streakDays: 4)
}

#Preview("Inline", as: .accessoryInline) {
    FreshliWatchComplication()
} timeline: {
    FreshliComplicationEntry(date: .now, expiringCount: 0, itemsSaved: 28, streakDays: 6)
}

import WidgetKit
import SwiftUI

// MARK: - Shared Constants

private let appGroupID = "group.everwise.interactive.PantryShare"
private let primaryGreen = Color(red: 0.133, green: 0.773, blue: 0.369) // #22C55E
private let accentTeal = Color(red: 0.078, green: 0.722, blue: 0.647)   // #14B8A6
private let warningAmber = Color(red: 0.961, green: 0.651, blue: 0.137) // #F59E0B
private let expiredRed = Color(red: 0.937, green: 0.267, blue: 0.267)   // #EF4444

// MARK: - Timeline Entry

struct FreshnessRingEntry: TimelineEntry {
    let date: Date
    let freshness: FreshnessWidgetData
}

struct FreshnessWidgetData: Codable {
    let score: Double
    let itemsSavedThisWeek: Int
    let streakDays: Int
    let lastUpdated: Date

    var percentageDisplay: String {
        String(format: "%.0f%%", score * 100)
    }

    var ringColor: Color {
        switch score {
        case 0.8...1.0: return primaryGreen
        case 0.5..<0.8: return warningAmber
        default: return expiredRed
        }
    }
}

// MARK: - Timeline Provider

struct FreshnessRingTimelineProvider: TimelineProvider {
    typealias Entry = FreshnessRingEntry

    func placeholder(in context: Context) -> FreshnessRingEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (FreshnessRingEntry) -> Void) {
        completion(context.isPreview ? .preview : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FreshnessRingEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> FreshnessRingEntry {
        let freshness = loadFreshnessData()
        return FreshnessRingEntry(date: Date(), freshness: freshness)
    }

    private func loadFreshnessData() -> FreshnessWidgetData {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: "freshness_data") else {
            return .preview
        }

        let decoded = try? JSONDecoder().decode(FreshnessWidgetData.self, from: data)
        return decoded ?? .preview
    }
}

extension FreshnessRingEntry {
    static var preview: FreshnessRingEntry {
        FreshnessRingEntry(
            date: Date(),
            freshness: FreshnessWidgetData(
                score: 0.85,
                itemsSavedThisWeek: 5,
                streakDays: 7,
                lastUpdated: Date()
            )
        )
    }
}

extension FreshnessWidgetData {
    static var preview: FreshnessWidgetData {
        FreshnessWidgetData(
            score: 0.85,
            itemsSavedThisWeek: 5,
            streakDays: 7,
            lastUpdated: Date()
        )
    }
}

// MARK: - Freshness Ring Widget

struct FreshnessRingWidget: Widget {
    let kind = "FreshnessRing"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: FreshnessRingTimelineProvider()
        ) { entry in
            FreshnessRingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Freshness Score")
        .description("Track your weekly food waste reduction with a freshness ring.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Widget View

struct FreshnessRingWidgetView: View {
    let entry: FreshnessRingEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        case .accessoryCircular:
            lockScreenCircular
        case .accessoryRectangular:
            lockScreenRectangular
        default:
            smallLayout
        }
    }

    // MARK: - Home Screen (systemSmall)

    private var smallLayout: some View {
        VStack(alignment: .center, spacing: 8) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(primaryGreen)
                Text("Freshness")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }

            Spacer()

            // Ring
            ZStack {
                Circle()
                    .stroke(entry.freshness.ringColor.opacity(0.15), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: entry.freshness.score)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [accentTeal, primaryGreen]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(entry.freshness.percentageDisplay)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if entry.freshness.streakDays > 0 {
                        Text("\(entry.freshness.streakDays)d 🔥")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(warningAmber)
                    }
                }
            }
            .frame(width: 70, height: 70)

            // Stats
            Text("\(entry.freshness.itemsSavedThisWeek) saved")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(12)
    }

    // MARK: - Lock Screen Circular

    private var lockScreenCircular: some View {
        ZStack {
            AccessoryWidgetBackground()

            Circle()
                .stroke(entry.freshness.ringColor.opacity(0.3), lineWidth: 2)

            Circle()
                .trim(from: 0, to: entry.freshness.score)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [accentTeal, primaryGreen]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: "leaf.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(entry.freshness.ringColor)
        }
    }

    // MARK: - Lock Screen Rectangular

    private var lockScreenRectangular: some View {
        HStack(spacing: 8) {
            // Ring (compact)
            ZStack {
                Circle()
                    .stroke(entry.freshness.ringColor.opacity(0.25), lineWidth: 2)

                Circle()
                    .trim(from: 0, to: entry.freshness.score)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [accentTeal, primaryGreen]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text(entry.freshness.percentageDisplay)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .frame(width: 32, height: 32)

            // Text info
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.freshness.itemsSavedThisWeek) items saved")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("\(entry.freshness.streakDays)d streak")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(warningAmber)
            }

            Spacer()
        }
        .padding(8)
    }
}

// MARK: - Previews

#Preview("Home Screen", as: .systemSmall) {
    FreshnessRingWidget()
} timeline: {
    FreshnessRingEntry.preview
}

#Preview("Lock Screen Circular", as: .accessoryCircular) {
    FreshnessRingWidget()
} timeline: {
    FreshnessRingEntry.preview
}

#Preview("Lock Screen Rectangular", as: .accessoryRectangular) {
    FreshnessRingWidget()
} timeline: {
    FreshnessRingEntry.preview
}

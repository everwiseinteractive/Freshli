import WidgetKit
import SwiftUI

// MARK: - Eat Me First Widget
// Apple Watch complication + lock-screen widget showing the single most
// urgent pantry item. Icon turns red when the item is within 24h of its
// "death date" — a quick glance at the wrist tells you what to rescue first.

private let eatMeAppGroupID = "group.everwise.interactive.Freshli"

// MARK: - Timeline Entry

struct EatMeFirstEntry: TimelineEntry {
    let date: Date
    let item: EatMeFirstData
}

struct EatMeFirstData: Codable {
    let itemName: String
    let categoryEmoji: String
    let hoursUntilExpiry: Int
    let itemCount: Int

    var urgency: EatMeUrgency {
        if hoursUntilExpiry <= 0            { return .expired }
        if hoursUntilExpiry <= 24           { return .critical }
        if hoursUntilExpiry <= 48           { return .warning }
        return .safe
    }

    var tintColor: Color {
        switch urgency {
        case .expired:  return Color(red: 0.937, green: 0.267, blue: 0.267)  // red
        case .critical: return Color(red: 0.937, green: 0.267, blue: 0.267)  // red
        case .warning:  return Color(red: 0.961, green: 0.651, blue: 0.137)  // amber
        case .safe:     return Color(red: 0.133, green: 0.773, blue: 0.369)  // green
        }
    }

    var timeLabel: String {
        if hoursUntilExpiry <= 0                { return "Now!" }
        if hoursUntilExpiry < 24                { return "\(hoursUntilExpiry)h" }
        return "\(hoursUntilExpiry / 24)d"
    }

    static var preview: EatMeFirstData {
        EatMeFirstData(itemName: "Spinach", categoryEmoji: "🥬", hoursUntilExpiry: 18, itemCount: 3)
    }

    static var empty: EatMeFirstData {
        EatMeFirstData(itemName: "All fresh!", categoryEmoji: "✨", hoursUntilExpiry: 9999, itemCount: 0)
    }
}

enum EatMeUrgency: String, Codable {
    case safe, warning, critical, expired
}

// MARK: - Timeline Provider

struct EatMeFirstTimelineProvider: TimelineProvider {
    typealias Entry = EatMeFirstEntry

    func placeholder(in context: Context) -> EatMeFirstEntry {
        EatMeFirstEntry(date: Date(), item: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (EatMeFirstEntry) -> Void) {
        completion(context.isPreview ? EatMeFirstEntry(date: Date(), item: .preview) : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EatMeFirstEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> EatMeFirstEntry {
        guard let defaults = UserDefaults(suiteName: eatMeAppGroupID),
              let data = defaults.data(forKey: "eat_me_first_data"),
              let decoded = try? JSONDecoder().decode(EatMeFirstData.self, from: data) else {
            return EatMeFirstEntry(date: Date(), item: .empty)
        }
        return EatMeFirstEntry(date: Date(), item: decoded)
    }
}

// MARK: - Widget Views

struct EatMeFirstWidgetView: View {
    let entry: EatMeFirstEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:   accessoryCircular
        case .accessoryCorner:     accessoryCircular
        case .accessoryInline:     accessoryInline
        case .accessoryRectangular: accessoryRectangular
        case .systemSmall:         systemSmall
        default:                   systemSmall
        }
    }

    // MARK: - Watch Complications

    private var accessoryCircular: some View {
        ZStack {
            Circle()
                .stroke(entry.item.tintColor.opacity(0.3), lineWidth: 3)
            VStack(spacing: 1) {
                Text(entry.item.categoryEmoji)
                    .font(.system(size: 14))
                Text(entry.item.timeLabel)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(entry.item.tintColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .widgetAccentable()
    }

    private var accessoryInline: some View {
        HStack(spacing: 2) {
            Image(systemName: entry.item.urgency == .critical || entry.item.urgency == .expired
                  ? "exclamationmark.triangle.fill" : "leaf.fill")
            Text("\(entry.item.itemName) • \(entry.item.timeLabel)")
        }
        .widgetAccentable()
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(entry.item.tintColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text(entry.item.categoryEmoji).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("EAT ME FIRST")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(entry.item.itemName)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text(entry.item.urgency == .expired ? "Past expiry" : "in \(entry.item.timeLabel)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(entry.item.tintColor)
            }
            Spacer(minLength: 0)
        }
        .widgetAccentable()
    }

    // MARK: - iOS Small

    private var systemSmall: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EAT ME FIRST")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                Spacer()
                if entry.item.urgency == .critical || entry.item.urgency == .expired {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(entry.item.tintColor)
                        .font(.system(size: 12))
                }
            }
            Spacer(minLength: 0)
            Text(entry.item.categoryEmoji)
                .font(.system(size: 40))
            Text(entry.item.itemName)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                Circle()
                    .fill(entry.item.tintColor)
                    .frame(width: 6, height: 6)
                Text(entry.item.urgency == .expired ? "Past expiry" : entry.item.timeLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(entry.item.tintColor)
                if entry.item.itemCount > 1 {
                    Text("• +\(entry.item.itemCount - 1)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

// MARK: - Widget

struct EatMeFirstWidget: Widget {
    let kind: String = "EatMeFirstWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EatMeFirstTimelineProvider()) { entry in
            EatMeFirstWidgetView(entry: entry)
        }
        .configurationDisplayName("Eat Me First")
        .description("Shows your most urgent pantry item at a glance. Turns red when an item is within 24 hours of expiry.")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

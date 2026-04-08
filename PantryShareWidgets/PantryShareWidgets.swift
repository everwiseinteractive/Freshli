import WidgetKit
import SwiftUI

// MARK: - Shared Constants

private let appGroupID = "group.everwise.interactive.PantryShare"
private let emeraldGreen = Color(red: 0.133, green: 0.773, blue: 0.369) // #22C55E
private let warningAmber = Color(red: 0.961, green: 0.651, blue: 0.137) // #F59E22
private let expiredRed = Color(red: 0.937, green: 0.267, blue: 0.267)  // #EF4444

// MARK: - Timeline Entry

struct PantryWidgetEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItem]
    let totalItems: Int
    let itemsSaved: Int
    let itemsShared: Int
    let co2Avoided: Double
}

struct WidgetItem: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let daysUntilExpiry: Int

    var emoji: String {
        switch category {
        case "fruits": return "🍎"
        case "vegetables": return "🥬"
        case "dairy": return "🥛"
        case "meat": return "🥩"
        case "bakery": return "🍞"
        case "grains": return "🌾"
        case "frozen": return "🧊"
        case "canned": return "🥫"
        case "beverages": return "🥤"
        case "snacks": return "🍿"
        default: return "🍽️"
        }
    }

    var expiryLabel: String {
        switch daysUntilExpiry {
        case ...0: return "Expired"
        case 1: return "Tomorrow"
        default: return "\(daysUntilExpiry)d left"
        }
    }

    var urgencyColor: Color {
        switch daysUntilExpiry {
        case ...0: return expiredRed
        case 1...2: return warningAmber
        default: return emeraldGreen
        }
    }
}

// MARK: - Timeline Provider

struct PantryTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = PantryWidgetEntry
    typealias Intent = PantryWidgetConfigIntent

    func placeholder(in context: Context) -> PantryWidgetEntry {
        .preview
    }

    func snapshot(for configuration: PantryWidgetConfigIntent, in context: Context) async -> PantryWidgetEntry {
        context.isPreview ? .preview : loadEntry()
    }

    func timeline(for configuration: PantryWidgetConfigIntent, in context: Context) async -> Timeline<PantryWidgetEntry> {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func loadEntry() -> PantryWidgetEntry {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return .preview }

        // Read expiring items
        var items: [WidgetItem] = []
        if let data = defaults.array(forKey: "widget_expiring_items") as? [[String: Any]] {
            items = data.compactMap { dict in
                guard let name = dict["name"] as? String,
                      let category = dict["category"] as? String,
                      let days = dict["daysUntilExpiry"] as? Int else { return nil }
                return WidgetItem(name: name, category: category, daysUntilExpiry: days)
            }
        }

        return PantryWidgetEntry(
            date: Date(),
            items: items,
            totalItems: defaults.integer(forKey: "widget_total_items"),
            itemsSaved: defaults.integer(forKey: "widget_items_saved"),
            itemsShared: defaults.integer(forKey: "widget_items_shared"),
            co2Avoided: defaults.double(forKey: "widget_co2_avoided")
        )
    }
}

extension PantryWidgetEntry {
    static var preview: PantryWidgetEntry {
        PantryWidgetEntry(
            date: Date(),
            items: [
                WidgetItem(name: "Milk", category: "dairy", daysUntilExpiry: 1),
                WidgetItem(name: "Spinach", category: "vegetables", daysUntilExpiry: 2),
                WidgetItem(name: "Chicken", category: "meat", daysUntilExpiry: 0),
                WidgetItem(name: "Bread", category: "bakery", daysUntilExpiry: 3),
            ],
            totalItems: 12,
            itemsSaved: 47,
            itemsShared: 8,
            co2Avoided: 137.5
        )
    }
}

// MARK: - Expiring Items Widget

struct PantryShareWidgets: Widget {
    let kind = "PantryShareWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PantryWidgetConfigIntent.self, provider: PantryTimelineProvider()) { entry in
            ExpiringItemsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Expiring Soon")
        .description("Track items expiring soon in your pantry.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Small Widget View

struct ExpiringItemsWidgetView: View {
    let entry: PantryWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        default: smallLayout
        }
    }

    // MARK: - Small

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(emeraldGreen)
                Text("Expiring")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("\(entry.totalItems)")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(emeraldGreen)
            }

            let urgentItems = entry.items.filter { $0.daysUntilExpiry <= 3 }

            if urgentItems.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(emeraldGreen)
                    Text("All Fresh!")
                        .font(.system(size: 15, weight: .bold))
                    Text("Nothing expiring soon")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(urgentItems.prefix(3)) { item in
                    HStack(spacing: 6) {
                        Text(item.emoji)
                            .font(.system(size: 13))
                        Text(item.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        Text(item.expiryLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(item.urgencyColor)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(2)
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        HStack(spacing: 16) {
            // Left: Summary
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(emeraldGreen)
                    Text("Freshli")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                Text("\(entry.totalItems)")
                    .font(.system(size: 38, weight: .black))
                Text("items tracked")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label("\(entry.itemsSaved)", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(emeraldGreen)
                    Label("\(entry.itemsShared)", systemImage: "arrow.up.heart.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(warningAmber)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Divider
            Rectangle()
                .fill(.quaternary)
                .frame(width: 1)
                .padding(.vertical, 4)

            // Right: Expiring list
            VStack(alignment: .leading, spacing: 5) {
                Text("Expiring Soon")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)

                let urgentItems = entry.items.filter { $0.daysUntilExpiry <= 5 }

                if urgentItems.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 2) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(emeraldGreen)
                            Text("All good!")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ForEach(urgentItems.prefix(4)) { item in
                        HStack(spacing: 5) {
                            Text(item.emoji)
                                .font(.system(size: 12))
                            Text(item.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(item.expiryLabel)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(item.urgencyColor)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(2)
    }
}

// MARK: - Impact Widget

struct ImpactSummaryWidget: Widget {
    let kind = "ImpactSummary"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PantryWidgetConfigIntent.self, provider: PantryTimelineProvider()) { entry in
            ImpactWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("My Impact")
        .description("See your food waste reduction impact.")
        .supportedFamilies([.systemSmall])
    }
}

struct ImpactWidgetView: View {
    let entry: PantryWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(emeraldGreen)
                Text("Impact")
                    .font(.system(size: 13, weight: .bold))
            }

            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.itemsSaved)")
                        .font(.system(size: 32, weight: .black))
                    Text("saved")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.heart.fill")
                        .font(.system(size: 11))
                    Text("\(entry.itemsShared) shared")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(emeraldGreen)

                HStack(spacing: 4) {
                    Image(systemName: "carbon.dioxide.cloud.fill")
                        .font(.system(size: 11))
                    Text(String(format: "%.0f kg CO₂", entry.co2Avoided))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(emeraldGreen)
            }

            Spacer()
        }
        .padding(2)
    }
}

// MARK: - Previews

#Preview("Small - Expiring", as: .systemSmall) {
    PantryShareWidgets()
} timeline: {
    PantryWidgetEntry.preview
}

#Preview("Medium - Expiring", as: .systemMedium) {
    PantryShareWidgets()
} timeline: {
    PantryWidgetEntry.preview
}

#Preview("Small - Impact", as: .systemSmall) {
    ImpactSummaryWidget()
} timeline: {
    PantryWidgetEntry.preview
}

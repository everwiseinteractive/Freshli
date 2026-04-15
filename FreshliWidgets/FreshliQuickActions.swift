import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Freshli Quick-Actions (Swift 6.3)
// Senior iOS Engineer implementation.
// Interactive Home Screen widget (Top 3 Expiring with consume action),
// Control Center Quick Scan toggle, Lock Screen complications, and
// hourly TimelineProvider refresh.

private let appGroupID = "group.everwise.interactive.Freshli"
private let freshliGreen = Color(red: 0.204, green: 0.780, blue: 0.349)  // #34C759
private let amberWarning = Color(red: 0.961, green: 0.651, blue: 0.137)  // #F5A623
private let expiredRed   = Color(red: 0.831, green: 0.094, blue: 0.239)  // #D4183D

// MARK: - 1. Home Screen Widget — Top 3 Expiring (Interactive)

/// Medium-sized interactive widget showing the 3 items closest to expiry.
/// Tapping an item's checkmark icon marks it as "Consumed" directly from the Home Screen.
struct FreshliExpiringWidget: Widget {
    let kind = "FreshliExpiringQuickActions"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PantryWidgetConfigIntent.self,
            provider: FreshliExpiringTimelineProvider()
        ) { entry in
            FreshliExpiringWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Expiring — Quick Actions")
        .description("See your top 3 expiring items. Tap ✓ to mark consumed.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: Timeline Provider — Hourly Refresh

struct FreshliExpiringTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = FreshliExpiringEntry
    typealias Intent = PantryWidgetConfigIntent

    func placeholder(in context: Context) -> FreshliExpiringEntry { .preview }

    func snapshot(for configuration: Intent, in context: Context) async -> FreshliExpiringEntry {
        context.isPreview ? .preview : loadEntry()
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<FreshliExpiringEntry> {
        let entry = loadEntry()
        // Refresh every hour as items get closer to their expiry timestamp
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func loadEntry() -> FreshliExpiringEntry {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.array(forKey: "widget_expiring_items") as? [[String: Any]] else {
            return .preview
        }

        let items: [QuickActionItem] = data.prefix(3).compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let category = dict["category"] as? String,
                  let days = dict["daysUntilExpiry"] as? Int else { return nil }
            return QuickActionItem(
                itemId: id,
                name: name,
                category: category,
                daysUntilExpiry: days
            )
        }

        return FreshliExpiringEntry(date: Date(), items: items)
    }
}

// MARK: Entry

struct FreshliExpiringEntry: TimelineEntry {
    let date: Date
    let items: [QuickActionItem]

    static var preview: FreshliExpiringEntry {
        FreshliExpiringEntry(date: Date(), items: [
            QuickActionItem(itemId: "1", name: "Milk", category: "dairy", daysUntilExpiry: 0),
            QuickActionItem(itemId: "2", name: "Spinach", category: "vegetables", daysUntilExpiry: 1),
            QuickActionItem(itemId: "3", name: "Chicken", category: "meat", daysUntilExpiry: 2),
        ])
    }
}

struct QuickActionItem: Identifiable {
    var id: String { itemId }
    let itemId: String
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
        case "frozen": return "🧊"
        case "beverages": return "🥤"
        default: return "🍽️"
        }
    }

    var urgencyColor: Color {
        switch daysUntilExpiry {
        case ...0: return expiredRed
        case 1...2: return amberWarning
        default: return freshliGreen
        }
    }

    var expiryLabel: String {
        switch daysUntilExpiry {
        case ...0: return "Expired"
        case 1: return "Tomorrow"
        default: return "\(daysUntilExpiry)d left"
        }
    }
}

// MARK: Interactive Widget View

struct FreshliExpiringWidgetView: View {
    let entry: FreshliExpiringEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(freshliGreen)
                Text("Expiring Soon")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("Tap ✓ to consume")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if entry.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(freshliGreen)
                        Text("All Fresh!")
                            .font(.system(size: 15, weight: .bold))
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.items) { item in
                    HStack(spacing: 8) {
                        Text(item.emoji)
                            .font(.system(size: 18))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Text(item.expiryLabel)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(item.urgencyColor)
                        }

                        Spacer()

                        // Interactive: tap to mark consumed
                        Button(intent: ConsumeFromWidgetIntent(itemId: item.itemId, itemName: item.name)) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(freshliGreen)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(4)
    }
}

// MARK: Consume From Widget Intent

/// App Intent that marks a pantry item as consumed directly from the widget.
struct ConsumeFromWidgetIntent: AppIntent {
    static var title: LocalizedStringResource { "Mark as Consumed" }
    static var description: IntentDescription { "Mark a pantry item as consumed from the widget." }

    @Parameter(title: "Item ID")
    var itemId: String

    @Parameter(title: "Item Name")
    var itemName: String

    init() {
        self.itemId = ""
        self.itemName = ""
    }

    init(itemId: String, itemName: String) {
        self.itemId = itemId
        self.itemName = itemName
    }

    func perform() async throws -> some IntentResult {
        // Update via shared UserDefaults so the widget refreshes immediately
        if let defaults = UserDefaults(suiteName: appGroupID),
           var items = defaults.array(forKey: "widget_expiring_items") as? [[String: Any]] {
            items.removeAll { ($0["id"] as? String) == itemId }
            defaults.set(items, forKey: "widget_expiring_items")
        }

        // Also persist the consume action to sync with Supabase on next app launch
        if let defaults = UserDefaults(suiteName: appGroupID) {
            var pending = defaults.array(forKey: "widget_pending_consume") as? [String] ?? []
            pending.append(itemId)
            defaults.set(pending, forKey: "widget_pending_consume")
        }

        // Request timeline reload
        WidgetCenter.shared.reloadTimelines(ofKind: "FreshliExpiringQuickActions")
        WidgetCenter.shared.reloadTimelines(ofKind: "FreshliWidgets")

        return .result()
    }
}

// MARK: - 2. Control Center — Quick Scan Toggle

/// Control Center widget that launches Freshli directly into the Smart Add camera mode.
struct FreshliQuickScanControl: ControlWidget {
    static let kind = "com.freshli.control.quickscan"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenSmartScanIntent()) {
                Label {
                    Text("Quick Scan")
                    Text("Add to Pantry")
                } icon: {
                    Image(systemName: "barcode.viewfinder")
                }
            }
        }
        .displayName("Quick Scan")
        .description("Launch Freshli's Smart Add camera to scan items into your pantry.")
    }
}

/// Intent that opens the app in Smart Add camera mode.
struct OpenSmartScanIntent: AppIntent {
    static var title: LocalizedStringResource { "Open Quick Scan" }
    static var description: IntentDescription { "Opens Freshli in Smart Add camera mode." }
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        // Write a flag so the app navigates to SmartAdd on launch
        UserDefaults(suiteName: appGroupID)?.set(true, forKey: "deeplink_smart_scan")
        return .result()
    }
}

// MARK: - 3. Lock Screen Complications

/// Circular Lock Screen complication showing the current Impact Streak
/// (e.g. "14" with a flame icon for "14 Days Waste-Free").
struct FreshliStreakCircularWidget: Widget {
    let kind = "FreshliStreakCircular"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PantryWidgetConfigIntent.self,
            provider: FreshliStreakTimelineProvider()
        ) { entry in
            FreshliStreakCircularView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Impact Streak")
        .description("Show your current waste-free streak on the Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// Rectangular Lock Screen complication with streak + label.
struct FreshliStreakRectangularWidget: Widget {
    let kind = "FreshliStreakRectangular"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PantryWidgetConfigIntent.self,
            provider: FreshliStreakTimelineProvider()
        ) { entry in
            FreshliStreakRectangularView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Impact Streak")
        .description("Show your waste-free streak and days count.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: Streak Entry & Provider

struct FreshliStreakEntry: TimelineEntry {
    let date: Date
    let streakDays: Int

    static var preview: FreshliStreakEntry {
        FreshliStreakEntry(date: Date(), streakDays: 14)
    }
}

struct FreshliStreakTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = FreshliStreakEntry
    typealias Intent = PantryWidgetConfigIntent

    func placeholder(in context: Context) -> FreshliStreakEntry { .preview }

    func snapshot(for configuration: Intent, in context: Context) async -> FreshliStreakEntry {
        context.isPreview ? .preview : loadEntry()
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<FreshliStreakEntry> {
        let entry = loadEntry()
        // Refresh every hour
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func loadEntry() -> FreshliStreakEntry {
        let defaults = UserDefaults(suiteName: appGroupID)
        let streak = defaults?.integer(forKey: "widget_impact_streak") ?? 0
        return FreshliStreakEntry(date: Date(), streakDays: streak)
    }
}

// MARK: Circular View

struct FreshliStreakCircularView: View {
    let entry: FreshliStreakEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange)
                Text("\(entry.streakDays)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
            }
        }
    }
}

// MARK: Rectangular View

struct FreshliStreakRectangularView: View {
    let entry: FreshliStreakEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(entry.streakDays) Days")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                Text("Waste-Free Streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 4. Real-time — Hourly Refresh

// All TimelineProviders above use `.after(nextRefresh)` with a 1-hour cadence,
// ensuring widgets stay current as items approach their expiry timestamp.
// The main app calls `WidgetCenter.shared.reloadAllTimelines()` whenever
// a consume / add / delete action occurs, providing instant updates for user actions.

// MARK: - Previews

#Preview("Expiring Quick Actions", as: .systemMedium) {
    FreshliExpiringWidget()
} timeline: {
    FreshliExpiringEntry.preview
}

#Preview("Streak Circular", as: .accessoryCircular) {
    FreshliStreakCircularWidget()
} timeline: {
    FreshliStreakEntry.preview
}

#Preview("Streak Rectangular", as: .accessoryRectangular) {
    FreshliStreakRectangularWidget()
} timeline: {
    FreshliStreakEntry.preview
}

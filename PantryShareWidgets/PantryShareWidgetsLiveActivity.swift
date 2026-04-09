import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Expiry Rescue Live Activity
// Shows when a food item is about to expire and needs to be used, shared, or donated.

struct FreshliWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Hours remaining until expiry.
        var hoursRemaining: Int
        /// Current status: "expiring", "rescued", "shared"
        var status: String
    }

    /// Item name
    var itemName: String
    /// Food category for emoji
    var category: String
    /// Quantity description
    var quantity: String
}

struct PantryShareWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FreshliWidgetsAttributes.self) { context in
            // Lock screen / notification banner
            lockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.15))
                .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text(categoryEmoji(context.attributes.category))
                            .font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.itemName)
                                .font(.system(size: 15, weight: .bold))
                            Text(context.attributes.quantity)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(urgencyText(context.state.hoursRemaining))
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(urgencyColor(context.state.hoursRemaining))
                        Text(context.state.status == "rescued" ? "Rescued!" : "to expiry")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.status == "rescued" {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(red: 0.133, green: 0.773, blue: 0.369))
                            Text("Food rescued! Nice work reducing waste.")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.top, 4)
                    } else {
                        HStack(spacing: 12) {
                            actionPill(icon: "fork.knife", label: "Cook", color: Color(red: 0.133, green: 0.773, blue: 0.369))
                            actionPill(icon: "arrow.up.heart", label: "Share", color: Color(red: 0.376, green: 0.537, blue: 0.992))
                            actionPill(icon: "heart.fill", label: "Donate", color: Color(red: 0.961, green: 0.651, blue: 0.137))
                        }
                        .padding(.top, 4)
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Text(categoryEmoji(context.attributes.category))
                        .font(.system(size: 14))
                    Text(context.attributes.itemName)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
            } compactTrailing: {
                Text(urgencyText(context.state.hoursRemaining))
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(urgencyColor(context.state.hoursRemaining))
            } minimal: {
                Text(categoryEmoji(context.attributes.category))
                    .font(.system(size: 14))
            }
            .widgetURL(URL(string: "pantryshare://expiring"))
            .keylineTint(Color(red: 0.133, green: 0.773, blue: 0.369))
        }
    }

    // MARK: - Lock Screen View

    private func lockScreenView(context: ActivityViewContext<FreshliWidgetsAttributes>) -> some View {
        HStack(spacing: 16) {
            // Item info
            HStack(spacing: 10) {
                Text(categoryEmoji(context.attributes.category))
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.itemName)
                        .font(.system(size: 17, weight: .bold))
                    Text(context.attributes.quantity)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Urgency
            VStack(alignment: .trailing, spacing: 2) {
                if context.state.status == "rescued" {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(red: 0.133, green: 0.773, blue: 0.369))
                    Text("Rescued!")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.133, green: 0.773, blue: 0.369))
                } else {
                    Text(urgencyText(context.state.hoursRemaining))
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(urgencyColor(context.state.hoursRemaining))
                    Text("until expiry")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Helpers

    private func actionPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private func urgencyText(_ hours: Int) -> String {
        if hours <= 0 { return "Now!" }
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }

    private func urgencyColor(_ hours: Int) -> Color {
        switch hours {
        case ...0: return Color(red: 0.937, green: 0.267, blue: 0.267)
        case 1...12: return Color(red: 0.961, green: 0.651, blue: 0.137)
        default: return Color(red: 0.133, green: 0.773, blue: 0.369)
        }
    }

    private func categoryEmoji(_ category: String) -> String {
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
}

// MARK: - Previews

extension FreshliWidgetsAttributes {
    fileprivate static var preview: FreshliWidgetsAttributes {
        FreshliWidgetsAttributes(itemName: "Organic Milk", category: "dairy", quantity: "1 carton")
    }
}

extension FreshliWidgetsAttributes.ContentState {
    fileprivate static var expiring: FreshliWidgetsAttributes.ContentState {
        FreshliWidgetsAttributes.ContentState(hoursRemaining: 6, status: "expiring")
    }

    fileprivate static var rescued: FreshliWidgetsAttributes.ContentState {
        FreshliWidgetsAttributes.ContentState(hoursRemaining: 0, status: "rescued")
    }
}

#Preview("Notification", as: .content, using: FreshliWidgetsAttributes.preview) {
    PantryShareWidgetsLiveActivity()
} contentStates: {
    FreshliWidgetsAttributes.ContentState.expiring
    FreshliWidgetsAttributes.ContentState.rescued
}

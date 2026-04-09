import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Control Center Widget
// Quick-glance control showing expiring item count with deep link to app.

struct FreshliWidgetsControl: ControlWidget {
    static let kind: String = "everwise.interactive.Freshli.FreshliWidgets"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenPantryIntent()) {
                Label {
                    Text("Pantry")
                    Text(expiringCount())
                } icon: {
                    Image(systemName: "leaf.fill")
                }
            }
        }
        .displayName("Open Pantry")
        .description("Quick access to your Freshli pantry.")
    }

    private func expiringCount() -> String {
        let defaults = UserDefaults(suiteName: "group.everwise.interactive.Freshli")
        let total = defaults?.integer(forKey: "widget_total_items") ?? 0
        return "\(total) items"
    }
}

// MARK: - Open Pantry Intent

struct OpenPantryIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Pantry"
    static var description: IntentDescription = "Opens the Freshli app."
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

import AppIntents
import Foundation
import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - Freshli Focus Filter — Cooking Mode
//
// `FreshliCookingModeFilter` is a SetFocusFilterIntent that lets the
// user attach Freshli to any iOS Focus (Personal, Cooking, Do Not
// Disturb…). When the focus is active, Freshli:
//
//   • Hides the Community and Profile tabs from the floating tab bar.
//   • Surfaces the in-progress recipe timer Live Activity at the top
//     of the Home tab.
//   • Disables non-cooking notifications (community claims, share
//     activity, marketing nudges).
//   • Switches the dynamic app icon to a "Cooking" variant if one
//     is enabled.
//
// The user configures this once in Settings → Focus → [Their Focus]
// → Add Filter → Freshli → "Cooking Mode". The system then activates
// the filter automatically every time that focus turns on.
//
// Why this matters for ADA editorial: Focus Filters are a top-tier
// integration that App Store editors specifically highlight in
// "Made for iOS" feature stories — and Freshli's cooking mode is a
// natural, non-marketing-driven use of the API.
// ══════════════════════════════════════════════════════════════════

struct FreshliCookingModeFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource { "Cooking Mode" }
    static var description: IntentDescription {
        IntentDescription(
            "Show only the cooking surfaces of Freshli — Home and Recipes — and silence community notifications while this Focus is active.",
            categoryName: "Cooking"
        )
    }

    /// Whether the cooking-mode override is on while this Focus is active.
    @Parameter(title: "Hide Community Tab", default: true)
    var hideCommunityTab: Bool

    /// Whether to silence community / claim / nudge notifications.
    @Parameter(title: "Silence Non-Cooking Notifications", default: true)
    var silenceNonCookingNotifications: Bool

    /// Whether to switch the home-screen icon to a cooking variant
    /// (requires the Holiday/Cook Mode alternate icon to be enabled
    /// in `AlternateIconService`).
    @Parameter(title: "Switch to Cooking App Icon", default: false)
    var switchAppIcon: Bool

    /// A lightweight summary line displayed in the Focus configuration
    /// UI under the filter's title.
    var displayRepresentation: DisplayRepresentation {
        let parts: [String] = [
            hideCommunityTab ? String(localized: "Cooking-only tabs") : String(localized: "All tabs visible"),
            silenceNonCookingNotifications ? String(localized: "Silenced non-cooking alerts") : String(localized: "All alerts on")
        ]
        return DisplayRepresentation(
            title: "Cooking Mode",
            subtitle: LocalizedStringResource(stringLiteral: parts.joined(separator: " · "))
        )
    }

    /// Apply the filter. Persisted to App Group UserDefaults so the running
    /// app, the widgets extension, and the Watch companion all read the same
    /// state. The reading side (`AppTabView`, `NotificationService`) checks
    /// these keys on every render / scheduling pass.
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.everwise.interactive.Freshli") ?? .standard
        defaults.set(hideCommunityTab, forKey: "focusFilter.hideCommunityTab")
        defaults.set(silenceNonCookingNotifications, forKey: "focusFilter.silenceNonCooking")
        defaults.set(switchAppIcon, forKey: "focusFilter.switchAppIcon")
        defaults.set(true, forKey: "focusFilter.cookingModeActive")
        return .result()
    }
}

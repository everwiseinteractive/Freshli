import TipKit
import SwiftUI

// MARK: - Freshli Tips (TipKit, iOS 26)
//
// Contextual in-app tips that surface the right feature at the right
// moment — the layer that bridges the onboarding story into actual
// muscle-memory use of the app. Each tip is scoped with TipKit
// rules so it only appears when the user is in the specific state
// that makes it relevant, and auto-dismisses itself after one
// acknowledgement.
//
// TipKit is already imported elsewhere in the codebase but was
// minimally used. These three tips cover the core-loop discoveries
// a first-run user needs to make:
//
//   1. AddItemTip       — "Tap here to add your first item"
//   2. RescueChefTip    — "Apple Intelligence can rescue these for you"
//   3. WeeklyWrapTip    — "See your impact story at the end of the week"

/// Nudges a new user toward the add FAB on the pantry screen the first
/// time they see an empty or near-empty pantry. Expires itself as soon
/// as the user has added any items — no nag on returning users.
struct AddItemTip: Tip {
    var title: Text {
        Text("Add your first item")
    }

    var message: Text? {
        Text("Tap the green + button to track anything in your fridge, freezer, or cupboard. It takes about 5 seconds.")
    }

    var image: Image? {
        Image(systemName: "plus.circle.fill")
    }

    /// Event fired from `FreshliView` the first time the pantry view
    /// appears. Combined with the `pantryItemCount` parameter we only
    /// show this tip to users with 0 items.
    static let pantryViewed = Tips.Event(id: "pantryViewed")

    /// Count of items in the pantry. Set from the view's onAppear so
    /// the tip's rules can read it.
    @Parameter
    static var pantryItemCount: Int = 0

    var rules: [Rule] {
        #Rule(Self.$pantryItemCount) { $0 == 0 }
        #Rule(Self.pantryViewed) { $0.donations.count >= 1 }
    }
}

/// Introduces the on-device Apple Intelligence Rescue Chef when the user
/// has at least one item expiring within 48 hours. Teaches the magic
/// moment without them needing to stumble onto the Rescue Chef tab.
struct RescueChefTip: Tip {
    var title: Text {
        Text("Rescue Chef is ready")
    }

    var message: Text? {
        Text("You've got items expiring soon. Ask Apple Intelligence to write recipes for your exact pantry — on-device, private, no internet needed.")
    }

    var image: Image? {
        Image(systemName: "sparkles")
    }

    static let hasAtRiskItems = Tips.Event(id: "hasAtRiskItems")

    @Parameter
    static var atRiskCount: Int = 0

    var rules: [Rule] {
        #Rule(Self.$atRiskCount) { $0 >= 1 }
    }
}

/// Tells the user the Weekly Wrap exists the first time they open the
/// Home tab after rescuing at least one item. Surfaces the emotional
/// payoff so the share loop kicks in.
struct WeeklyWrapTip: Tip {
    var title: Text {
        Text("Your first Weekly Wrap")
    }

    var message: Text? {
        Text("Tap the chart icon in the header to see your impact story — items saved, CO₂ avoided, and what you've rescued this week.")
    }

    var image: Image? {
        Image(systemName: "chart.line.uptrend.xyaxis")
    }

    static let firstItemRescued = Tips.Event(id: "firstItemRescued")

    var rules: [Rule] {
        #Rule(Self.firstItemRescued) { $0.donations.count >= 1 }
    }
}

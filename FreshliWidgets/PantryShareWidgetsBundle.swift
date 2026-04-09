import WidgetKit
import SwiftUI

@main
struct FreshliWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FreshliWidgets()
        ImpactSummaryWidget()
        FreshnessRingWidget()
        FreshliWidgetsControl()
        FreshliWidgetsLiveActivity()
        FreshliExpiryLiveActivity()
        FreshliClaimLiveActivity()
        FreshliRecipeTimerLiveActivity()
    }
}

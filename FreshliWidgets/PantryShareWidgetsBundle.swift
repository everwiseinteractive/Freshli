import WidgetKit
import SwiftUI

@main
struct FreshliWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FreshliWidgets()
        ImpactSummaryWidget()
        FreshnessRingWidget()
        EatMeFirstWidget()
        FreshliWidgetsControl()
        FreshliWidgetsLiveActivity()
        FreshliExpiryLiveActivity()
        FreshliClaimLiveActivity()
        FreshliRecipeTimerLiveActivity()
    }
}

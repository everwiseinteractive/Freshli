import WidgetKit
import SwiftUI

@main
struct PantryShareWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PantryShareWidgets()
        ImpactSummaryWidget()
        FreshnessRingWidget()
        PantryShareWidgetsControl()
        PantryShareWidgetsLiveActivity()
        FreshliExpiryLiveActivity()
        FreshliClaimLiveActivity()
        FreshliRecipeTimerLiveActivity()
    }
}

import SwiftUI

/// View model for the Freshli Weekly Wrap story experience
@Observable
final class WeeklyWrapViewModel {
    let wrapData: ImpactWrapDataService.WeeklyWrapData

    init(wrapData: ImpactWrapDataService.WeeklyWrapData) {
        self.wrapData = wrapData
    }
}

// MARK: - Preview Helper

extension WeeklyWrapViewModel {
    static var preview: WeeklyWrapViewModel {
        WeeklyWrapViewModel(
            wrapData: ImpactWrapDataService.WeeklyWrapData(
                itemsSaved: 28,
                itemsDonated: 6,
                itemsShared: 9,
                totalItemsImpacted: 43,
                moneySaved: 152.0,
                moneySavedDisplay: "$152",
                co2Avoided: 107.5,
                co2AvoidedDisplay: "107.5",
                treesEquivalent: 3,
                topCategorySaved: .vegetables,
                topCategoryCount: 14,
                categoryBreakdown: [
                    (FoodCategory.vegetables, 14),
                    (FoodCategory.fruits, 10),
                    (FoodCategory.dairy, 7),
                    (FoodCategory.bakery, 5)
                ],
                bestDayOfWeek: "Tuesday",
                currentStreak: 6,
                streakLabel: "\u{1F525} Keep it up!",
                weekOverWeekChange: 0.18,
                weekOverWeekLabel: "18% more than last week!",
                weekStartDate: Date().addingTimeInterval(-7 * 24 * 3600),
                weekEndDate: Date(),
                weekDisplayRange: "Mar 31 - Apr 6"
            )
        )
    }
}

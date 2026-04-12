import SwiftUI

/// View model for the Freshli Weekly Wrap story experience.
///
/// Exposes display-ready computed properties so the slide views stay
/// purely declarative — no formatting logic in the body closures.
/// Also provides the per-slide MeshGradient color palettes that drive
/// the animated background in the container view.
@Observable @MainActor
final class WeeklyWrapViewModel {
    let wrapData: ImpactWrapDataService.WeeklyWrapData

    init(wrapData: ImpactWrapDataService.WeeklyWrapData) {
        self.wrapData = wrapData
    }

    // MARK: - Streak

    var hasStreak: Bool { wrapData.currentStreak > 0 }

    var streakDisplay: String { "\(wrapData.currentStreak)" }

    // MARK: - Week-over-Week Comparison

    var weekOverWeekArrow: String {
        wrapData.weekOverWeekChange > 0
            ? "arrow.up.right"
            : wrapData.weekOverWeekChange < 0
                ? "arrow.down.right"
                : "equal"
    }

    var weekOverWeekIsPositive: Bool { wrapData.weekOverWeekChange >= 0 }

    // MARK: - Category

    var categoryBreakdownTop3: [(category: FoodCategory, count: Int)] {
        Array(wrapData.categoryBreakdown.prefix(3))
    }

    // MARK: - MeshGradient Palettes (3×3 = 9 colors per slide)
    //
    // Each palette is designed for a dark, cinematic background:
    //   Slide 0 (Big Number)   — deep forest green, heroic
    //   Slide 1 (Community)    — warm amber-green, human
    //   Slide 2 (Environment)  — cool teal-green, nature

    func meshColors(for slide: Int) -> [Color] {
        switch slide {
        case 0:
            return [
                Color(hex: 0x0A2E1A),  PSColors.primaryGreenDark.opacity(0.6),  Color(hex: 0x0A0A0A),
                PSColors.primaryGreen.opacity(0.2),  Color(hex: 0x0F3D22),  PSColors.accentTeal.opacity(0.15),
                Color(hex: 0x0A0A0A),  PSColors.primaryGreen.opacity(0.1),  Color(hex: 0x050F0A)
            ]
        case 1:
            return [
                Color(hex: 0x1A0E02),  PSColors.secondaryAmber.opacity(0.3),  Color(hex: 0x0A0A0A),
                PSColors.primaryGreen.opacity(0.15),  Color(hex: 0x2A1A08),  PSColors.secondaryAmber.opacity(0.15),
                Color(hex: 0x0A0A0A),  PSColors.primaryGreen.opacity(0.1),  Color(hex: 0x0F0802)
            ]
        default:
            return [
                Color(hex: 0x021A1A),  PSColors.accentTeal.opacity(0.4),  Color(hex: 0x0A0A0A),
                PSColors.primaryGreen.opacity(0.3),  Color(hex: 0x0A2420),  PSColors.accentTeal.opacity(0.2),
                Color(hex: 0x0A0A0A),  PSColors.primaryGreenDark.opacity(0.15),  Color(hex: 0x020F0F)
            ]
        }
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

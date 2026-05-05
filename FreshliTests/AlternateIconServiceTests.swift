import Testing
import Foundation
@testable import Freshli

@Suite("AlternateIconService")
struct AlternateIconServiceTests {

    @Test("Every Icon case has a stable raw value (used by Info.plist)")
    @MainActor
    func iconRawValuesStable() {
        // These raw values are referenced from `Info.plist` →
        // `CFBundleIcons` → `CFBundleAlternateIcons`. Renaming any of
        // them breaks the alternate-icon flow at runtime.
        #expect(AlternateIconService.Icon.default.rawValue == "")
        #expect(AlternateIconService.Icon.plasticFreeJuly.rawValue == "plastic-free-july")
        #expect(AlternateIconService.Icon.holidayPantryHero.rawValue == "holiday-pantry-hero")
        #expect(AlternateIconService.Icon.worldFoodDay.rawValue == "world-food-day")
        #expect(AlternateIconService.Icon.freshliPride.rawValue == "freshli-pride")
    }

    @Test("Plastic Free July suggested in late June, all of July, and early August")
    @MainActor
    func plasticFreeJulySeason() {
        let svc = AlternateIconService.shared
        let cal = Calendar(identifier: .gregorian)

        let inSeason = cal.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        #expect(svc.suggestSeasonalIcon(for: inSeason) == .plasticFreeJuly)

        let lateJune = cal.date(from: DateComponents(year: 2026, month: 6, day: 26))!
        #expect(svc.suggestSeasonalIcon(for: lateJune) == .plasticFreeJuly)

        let earlyAugust = cal.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        #expect(svc.suggestSeasonalIcon(for: earlyAugust) == .plasticFreeJuly)
    }

    @Test("World Food Day suggested only on October 16")
    @MainActor
    func worldFoodDayOnSpecificDate() {
        let svc = AlternateIconService.shared
        let cal = Calendar(identifier: .gregorian)
        let onTheDay = cal.date(from: DateComponents(year: 2026, month: 10, day: 16))!
        #expect(svc.suggestSeasonalIcon(for: onTheDay) == .worldFoodDay)

        let dayBefore = cal.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        #expect(svc.suggestSeasonalIcon(for: dayBefore) == nil)
    }

    @Test("Holiday Pantry Hero suggested in late December")
    @MainActor
    func holidayPantryHeroSeason() {
        let svc = AlternateIconService.shared
        let cal = Calendar(identifier: .gregorian)
        let christmas = cal.date(from: DateComponents(year: 2026, month: 12, day: 25))!
        #expect(svc.suggestSeasonalIcon(for: christmas) == .holidayPantryHero)
    }

    @Test("No seasonal suggestion in March")
    @MainActor
    func noSeasonalInMarch() {
        let svc = AlternateIconService.shared
        let cal = Calendar(identifier: .gregorian)
        let march = cal.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        #expect(svc.suggestSeasonalIcon(for: march) == nil)
    }
}

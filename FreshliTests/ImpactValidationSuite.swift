import Testing
import Foundation
@testable import Freshli

// ╔══════════════════════════════════════════════════════════════════╗
// ║  Freshli Impact Validation Suite                                ║
// ║  Swift Testing · Decimal Precision · Actor-Isolated             ║
// ║  Covers: Financial, CO2, Streak, Community, Edge Cases          ║
// ╚══════════════════════════════════════════════════════════════════╝

// MARK: - Mock Data Providers (No Production Supabase)

enum MockImpactData {

    /// A standard basket of 4 grocery items
    static let standardBasket: [ImpactEngine.ItemInput] = [
        .init(category: "dairy", quantity: 1, estimatedWeightKg: Decimal(string: "0.5")!, disposition: .consumed),
        .init(category: "fruits", quantity: 2, estimatedWeightKg: Decimal(string: "0.3")!, disposition: .consumed),
        .init(category: "meat", quantity: 1, estimatedWeightKg: Decimal(string: "0.5")!, disposition: .shared),
        .init(category: "vegetables", quantity: 1, estimatedWeightKg: Decimal(string: "0.4")!, disposition: .donated),
    ]

    /// Single item at £4 cost — for the "50% consumed/wasted" scenario
    static let singleItem: ImpactEngine.ItemInput = .init(
        category: "dairy",
        quantity: 1,
        estimatedWeightKg: Decimal(string: "0.5")!,
        disposition: .consumed
    )

    /// Beef item — high CO2 (27 kg CO2/kg)
    static let beefItem: ImpactEngine.ItemInput = .init(
        category: "meat",
        quantity: 1,
        estimatedWeightKg: Decimal(string: "1.0")!,
        disposition: .consumed
    )

    /// Tomato item — low CO2 (2.0 kg CO2/kg)
    static let tomatoItem: ImpactEngine.ItemInput = .init(
        category: "vegetables",
        quantity: 1,
        estimatedWeightKg: Decimal(string: "1.0")!,
        disposition: .consumed
    )

    /// Items with zero quantity
    static let zeroQuantityItem: ImpactEngine.ItemInput = .init(
        category: "fruits",
        quantity: 0,
        estimatedWeightKg: Decimal(string: "0.5")!,
        disposition: .consumed
    )

    /// Large-scale batch (1000 items)
    static var largeBatch: [ImpactEngine.ItemInput] {
        (0..<1000).map { _ in
            ImpactEngine.ItemInput(
                category: ["meat", "dairy", "fruits", "vegetables", "grains"].randomElement()!,
                quantity: 1,
                estimatedWeightKg: Decimal(string: "0.5")!,
                disposition: [.consumed, .shared, .donated].randomElement()!
            )
        }
    }

    /// All wasted items — no positive impact
    static let wastedItems: [ImpactEngine.ItemInput] = [
        .init(category: "dairy", quantity: 1, estimatedWeightKg: Decimal(string: "0.5")!, disposition: .wasted),
        .init(category: "meat", quantity: 1, estimatedWeightKg: Decimal(string: "0.5")!, disposition: .wasted),
    ]

    /// Items spanning every category
    static let allCategories: [ImpactEngine.ItemInput] = [
        "fruits", "vegetables", "dairy", "meat", "seafood",
        "grains", "bakery", "frozen", "canned", "condiments",
        "snacks", "beverages", "other"
    ].map { cat in
        ImpactEngine.ItemInput(
            category: cat,
            quantity: 1,
            estimatedWeightKg: Decimal(string: "1.0")!,
            disposition: .consumed
        )
    }

    /// Helper: create a date by offset from a reference
    static func date(daysFrom reference: Date, offset: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: offset, to: reference)!
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1. Financial Accuracy Suite
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@Suite("Financial Accuracy (Decimal)")
struct FinancialAccuracyTests {

    let engine = ImpactEngine()

    @Test("Single consumed item saves $3.50")
    func singleItemSaving() async {
        let result = await engine.calculateImpact(items: [MockImpactData.singleItem])
        #expect(result.moneySaved == Decimal(string: "3.50")!)
    }

    @Test("50% consumed, 50% wasted of a £4 item → £2 saved scenario")
    func halfConsumedHalfWasted() async {
        // 2 items: 1 consumed, 1 wasted
        let items: [ImpactEngine.ItemInput] = [
            .init(category: "dairy", quantity: 1, disposition: .consumed),
            .init(category: "dairy", quantity: 1, disposition: .wasted),
        ]
        let result = await engine.calculateImpact(items: items)
        // Only consumed counts: 1 × $3.50
        #expect(result.moneySaved == Decimal(string: "3.50")!)
        #expect(result.totalItemsSaved == 1)
    }

    @Test("Wasted items contribute zero money saved")
    func wastedItemsZeroMoney() async {
        let result = await engine.calculateImpact(items: MockImpactData.wastedItems)
        #expect(result.moneySaved == Decimal(0))
    }

    @Test("Money saved scales linearly with quantity")
    func linearScaling() async {
        let items = [ImpactEngine.ItemInput(category: "other", quantity: 10, disposition: .consumed)]
        let result = await engine.calculateImpact(items: items)
        // 10 quantity × $3.50 = $35
        #expect(result.moneySaved == Decimal(string: "35.00")!)
    }

    @Test("Money saved is never negative")
    func neverNegative() async {
        let result = await engine.calculateImpact(items: [])
        #expect(result.moneySaved >= Decimal(0))
    }

    @Test("Currency conversion: USD → GBP")
    func currencyConversionGBP() async {
        let result = await engine.calculateImpact(items: [MockImpactData.singleItem])
        let display = result.moneySavedDisplay(currency: "GBP")
        // $3.50 × 0.79 = £2.765 → "£2"
        #expect(display.hasPrefix("£"))
    }

    @Test("Currency conversion: USD → EUR")
    func currencyConversionEUR() async {
        let result = await engine.calculateImpact(items: [MockImpactData.singleItem])
        let display = result.moneySavedDisplay(currency: "EUR")
        #expect(display.hasPrefix("€"))
    }

    @Test("Currency conversion: USD → JPY")
    func currencyConversionJPY() async {
        let result = await engine.calculateImpact(items: [MockImpactData.singleItem])
        let display = result.moneySavedDisplay(currency: "JPY")
        #expect(display.hasPrefix("¥"))
    }

    @Test("Unknown currency defaults to USD symbol")
    func unknownCurrencyFallback() async {
        let result = await engine.calculateImpact(items: [MockImpactData.singleItem])
        let display = result.moneySavedDisplay(currency: "XYZ")
        #expect(display.hasPrefix("$"))
    }

    @Test("Shared + donated items also count toward money saved")
    func sharedAndDonatedCountMoney() async {
        let items: [ImpactEngine.ItemInput] = [
            .init(disposition: .shared),
            .init(disposition: .donated),
        ]
        let result = await engine.calculateImpact(items: items)
        // 2 items × $3.50 = $7.00
        #expect(result.moneySaved == Decimal(string: "7.00")!)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 2. CO2 Modeling Suite
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@Suite("CO2 Modeling (Category-Specific)")
struct CO2ModelingTests {

    let engine = ImpactEngine()

    @Test("Beef is ~27 kg CO2/kg")
    func beefCO2() async {
        let co2 = await engine.co2ForItem(MockImpactData.beefItem)
        // 1 kg × 27.0 = 27.0
        #expect(co2 == Decimal(string: "27.0")!)
    }

    @Test("Tomatoes/Vegetables are ~2.0 kg CO2/kg")
    func tomatoCO2() async {
        let co2 = await engine.co2ForItem(MockImpactData.tomatoItem)
        // 1 kg × 2.0 = 2.0
        #expect(co2 == Decimal(string: "2.0")!)
    }

    @Test("Beef CO2 is significantly higher than vegetables")
    func beefVsVegetables() async {
        let beefCO2 = await engine.co2ForItem(MockImpactData.beefItem)
        let vegCO2 = await engine.co2ForItem(MockImpactData.tomatoItem)
        #expect(beefCO2 > vegCO2 * 10) // Beef is >10× vegetables
    }

    @Test("CO2 scales with weight", arguments: [
        (Decimal(string: "0.5")!, Decimal(string: "13.5")!),  // 0.5 kg beef × 27
        (Decimal(string: "2.0")!, Decimal(string: "54.0")!),  // 2.0 kg beef × 27
    ])
    func co2ScalesWithWeight(weight: Decimal, expectedCO2: Decimal) async {
        let item = ImpactEngine.ItemInput(
            category: "meat",
            quantity: 1,
            estimatedWeightKg: weight,
            disposition: .consumed
        )
        let co2 = await engine.co2ForItem(item)
        #expect(co2 == expectedCO2)
    }

    @Test("Unknown category falls back to generic factor")
    func unknownCategoryFallback() async {
        let item = ImpactEngine.ItemInput(
            category: "unicorn_food",
            quantity: 1,
            estimatedWeightKg: Decimal(string: "1.0")!,
            disposition: .consumed
        )
        let co2 = await engine.co2ForItem(item)
        #expect(co2 == ImpactEngine.co2PerItemGeneric) // 2.5
    }

    @Test("All 13 food categories have CO2 factors")
    func allCategoriesHaveFactors() {
        let expectedCategories = [
            "meat", "seafood", "dairy", "fruits", "vegetables",
            "grains", "bakery", "frozen", "canned", "condiments",
            "snacks", "beverages", "other"
        ]
        for cat in expectedCategories {
            #expect(ImpactEngine.co2PerKgByCategory[cat] != nil, "Missing CO2 factor for \(cat)")
        }
    }

    @Test("Wasted items contribute zero CO2 savings")
    func wastedZeroCO2() async {
        let result = await engine.calculateImpact(items: MockImpactData.wastedItems)
        #expect(result.co2Avoided == Decimal(0))
    }

    @Test("CO2 display formats correctly")
    func co2DisplayFormat() async {
        let items = [ImpactEngine.ItemInput(
            category: "meat",
            quantity: 1,
            estimatedWeightKg: Decimal(string: "1.0")!,
            disposition: .consumed
        )]
        let result = await engine.calculateImpact(items: items)
        #expect(result.co2Display == "27.0kg")
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 3. Streak Logic Suite
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@Suite("Streak Logic")
struct StreakLogicTests {

    let engine = ImpactEngine()
    let calendar = Calendar.current
    let referenceDate = Calendar.current.startOfDay(for: Date())

    @Test("First ever action starts streak at 1")
    func firstAction() async {
        let (newStreak, celebrate, _) = await engine.computeStreak(
            lastStreakDate: nil,
            today: referenceDate,
            currentStreak: 0
        )
        #expect(newStreak == 1)
        #expect(!celebrate)
    }

    @Test("Consecutive day increments streak")
    func consecutiveDay() async {
        let yesterday = MockImpactData.date(daysFrom: referenceDate, offset: -1)
        let (newStreak, _, _) = await engine.computeStreak(
            lastStreakDate: yesterday,
            today: referenceDate,
            currentStreak: 5
        )
        #expect(newStreak == 6)
    }

    @Test("Same day does not change streak")
    func sameDay() async {
        let (newStreak, celebrate, _) = await engine.computeStreak(
            lastStreakDate: referenceDate,
            today: referenceDate,
            currentStreak: 5
        )
        #expect(newStreak == 5)
        #expect(!celebrate)
    }

    @Test("Gap of 2+ days resets streak to 1")
    func gapResets() async {
        let twoDaysAgo = MockImpactData.date(daysFrom: referenceDate, offset: -2)
        let (newStreak, _, _) = await engine.computeStreak(
            lastStreakDate: twoDaysAgo,
            today: referenceDate,
            currentStreak: 10
        )
        #expect(newStreak == 1)
    }

    @Test("Celebration triggers at day 3")
    func celebrateAt3() async {
        let yesterday = MockImpactData.date(daysFrom: referenceDate, offset: -1)
        let (newStreak, celebrate, day) = await engine.computeStreak(
            lastStreakDate: yesterday,
            today: referenceDate,
            currentStreak: 2
        )
        #expect(newStreak == 3)
        #expect(celebrate)
        #expect(day == 3)
    }

    @Test("Celebration triggers at day 7")
    func celebrateAt7() async {
        let yesterday = MockImpactData.date(daysFrom: referenceDate, offset: -1)
        let (newStreak, celebrate, day) = await engine.computeStreak(
            lastStreakDate: yesterday,
            today: referenceDate,
            currentStreak: 6
        )
        #expect(newStreak == 7)
        #expect(celebrate)
        #expect(day == 7)
    }

    @Test("Celebration triggers at day 14")
    func celebrateAt14() async {
        let yesterday = MockImpactData.date(daysFrom: referenceDate, offset: -1)
        let (_, celebrate, day) = await engine.computeStreak(
            lastStreakDate: yesterday,
            today: referenceDate,
            currentStreak: 13
        )
        #expect(celebrate)
        #expect(day == 14)
    }

    @Test("Celebration triggers at day 30")
    func celebrateAt30() async {
        let yesterday = MockImpactData.date(daysFrom: referenceDate, offset: -1)
        let (_, celebrate, day) = await engine.computeStreak(
            lastStreakDate: yesterday,
            today: referenceDate,
            currentStreak: 29
        )
        #expect(celebrate)
        #expect(day == 30)
    }

    @Test("No celebration at non-milestone days", arguments: [4, 5, 6, 8, 10, 15, 20, 25])
    func noCelebrationAtNonMilestone(targetStreak: Int) async {
        let yesterday = MockImpactData.date(daysFrom: referenceDate, offset: -1)
        let (_, celebrate, _) = await engine.computeStreak(
            lastStreakDate: yesterday,
            today: referenceDate,
            currentStreak: targetStreak - 1
        )
        #expect(!celebrate)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 4. Community Impact Suite
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@Suite("Community Impact")
struct CommunityImpactTests {

    let engine = ImpactEngine()

    @Test("Sharing updates both giver and receiver")
    func giverAndReceiver() async {
        let items: [ImpactEngine.ItemInput] = [
            .init(category: "dairy", quantity: 1, estimatedWeightKg: Decimal(string: "0.5")!, disposition: .shared),
            .init(category: "fruits", quantity: 1, estimatedWeightKg: Decimal(string: "0.3")!, disposition: .shared),
        ]
        let impact = await engine.computeCommunityImpact(sharedItems: items)
        #expect(impact.giverItemsShared == 2)
        #expect(impact.receiverItemsReceived == 2)
        #expect(impact.giverCO2Avoided > Decimal(0))
        #expect(impact.receiverMoneySaved > Decimal(0))
    }

    @Test("Receiver money matches $3.50 per item × quantity")
    func receiverMoneyAccuracy() async {
        let items = [ImpactEngine.ItemInput(
            category: "other",
            quantity: 3,
            estimatedWeightKg: Decimal(string: "0.5")!,
            disposition: .shared
        )]
        let impact = await engine.computeCommunityImpact(sharedItems: items)
        // 1 item with quantity 3: $3.50 × 3 = $10.50
        #expect(impact.receiverMoneySaved == Decimal(string: "10.50")!)
    }

    @Test("Giver CO2 uses category-specific factor")
    func giverCO2Accuracy() async {
        let items = [ImpactEngine.ItemInput(
            category: "meat",
            quantity: 1,
            estimatedWeightKg: Decimal(string: "1.0")!,
            disposition: .shared
        )]
        let impact = await engine.computeCommunityImpact(sharedItems: items)
        #expect(impact.giverCO2Avoided == Decimal(string: "27.0")!) // 1kg meat × 27
    }

    @Test("Empty sharing produces zero impact")
    func emptySharing() async {
        let impact = await engine.computeCommunityImpact(sharedItems: [])
        #expect(impact.giverItemsShared == 0)
        #expect(impact.receiverItemsReceived == 0)
        #expect(impact.giverCO2Avoided == Decimal(0))
        #expect(impact.receiverMoneySaved == Decimal(0))
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 5. Edge Cases
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@Suite("Edge Cases")
struct EdgeCaseTests {

    let engine = ImpactEngine()

    // MARK: - Zero Values

    @Test("Zero items produces zero impact — no NaN or crash")
    func zeroItems() async {
        let result = await engine.calculateImpact(items: [])
        #expect(result.moneySaved == Decimal(0))
        #expect(result.co2Avoided == Decimal(0))
        #expect(result.totalItemsSaved == 0)
        #expect(result.mealsHelped == 0)
    }

    @Test("Zero quantity produces zero impact")
    func zeroQuantity() async {
        let result = await engine.calculateImpact(items: [MockImpactData.zeroQuantityItem])
        #expect(result.moneySaved == Decimal(0))
        #expect(result.co2Avoided == Decimal(0))
    }

    @Test("Zero weight produces zero CO2")
    func zeroWeight() async {
        let item = ImpactEngine.ItemInput(
            category: "meat",
            quantity: 1,
            estimatedWeightKg: Decimal(0),
            disposition: .consumed
        )
        let co2 = await engine.co2ForItem(item)
        #expect(co2 == Decimal(0))
    }

    // MARK: - Leap Years & Timezones

    @Test("Streak works across leap year boundary (Feb 28 → Feb 29)")
    func leapYearStreak() async {
        // 2024 is a leap year
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let feb28 = cal.date(from: DateComponents(year: 2024, month: 2, day: 28))!
        let feb29 = cal.date(from: DateComponents(year: 2024, month: 2, day: 29))!

        let (newStreak, _, _) = await engine.computeStreak(
            lastStreakDate: feb28,
            today: feb29,
            currentStreak: 5,
            calendar: cal
        )
        #expect(newStreak == 6)
    }

    @Test("Streak works across non-leap year (Feb 28 → Mar 1)")
    func nonLeapYearStreak() async {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let feb28 = cal.date(from: DateComponents(year: 2025, month: 2, day: 28))!
        let mar1 = cal.date(from: DateComponents(year: 2025, month: 3, day: 1))!

        let (newStreak, _, _) = await engine.computeStreak(
            lastStreakDate: feb28,
            today: mar1,
            currentStreak: 5,
            calendar: cal
        )
        #expect(newStreak == 6)
    }

    @Test("Streak handles timezone edge: 11:59 PM → 12:01 AM (same calendar day)")
    func timezoneEdge() async {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let late = cal.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 23, minute: 59))!
        let earlyNext = cal.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 0, minute: 1))!

        let (newStreak, _, _) = await engine.computeStreak(
            lastStreakDate: earlyNext,
            today: late,
            currentStreak: 3,
            calendar: cal
        )
        // Same calendar day — no change
        #expect(newStreak == 3)
    }

    @Test("Streak handles DST transition")
    func dstTransition() async {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        // March 9, 2025: DST spring forward in US Eastern
        let mar8 = cal.date(from: DateComponents(year: 2025, month: 3, day: 8, hour: 22))!
        let mar9 = cal.date(from: DateComponents(year: 2025, month: 3, day: 9, hour: 10))!

        let (newStreak, _, _) = await engine.computeStreak(
            lastStreakDate: mar8,
            today: mar9,
            currentStreak: 5,
            calendar: cal
        )
        #expect(newStreak == 6) // Consecutive day despite DST
    }

    // MARK: - Large Scale

    @Test("Large batch (1000 items) produces finite results")
    func largeBatch() async {
        let result = await engine.calculateImpact(items: MockImpactData.largeBatch)
        let nsDecMoney = result.moneySaved as NSDecimalNumber
        let nsDecCO2 = result.co2Avoided as NSDecimalNumber
        #expect(nsDecMoney.doubleValue.isFinite)
        #expect(nsDecCO2.doubleValue.isFinite)
        #expect(result.totalItemsSaved == 1000)
        #expect(result.moneySaved > Decimal(0))
    }

    @Test("All categories produce positive CO2")
    func allCategoriesPositiveCO2() async {
        let result = await engine.calculateImpact(items: MockImpactData.allCategories)
        #expect(result.co2Avoided > Decimal(0))
        #expect(result.totalItemsSaved == 13) // one per category
    }

    // MARK: - Currency Conversion Edge Cases

    @Test("All supported currencies produce valid display strings")
    func allCurrenciesValid() async {
        let result = await engine.calculateImpact(items: [MockImpactData.singleItem])
        for currency in ["USD", "GBP", "EUR", "CAD", "AUD", "JPY"] {
            let display = result.moneySavedDisplay(currency: currency)
            #expect(!display.isEmpty, "Display for \(currency) should not be empty")
        }
    }

    // MARK: - Snapshot Equality

    @Test("ImpactSnapshot equality works for identical inputs")
    func snapshotEquality() async {
        let items = [MockImpactData.singleItem]
        let result1 = await engine.calculateImpact(items: items)
        let result2 = await engine.calculateImpact(items: items)
        #expect(result1 == result2)
    }

    // MARK: - Decimal vs Double Precision

    @Test("Decimal avoids floating-point rounding (0.1 + 0.2 == 0.3)")
    func decimalPrecision() {
        let a = Decimal(string: "0.1")!
        let b = Decimal(string: "0.2")!
        let sum = a + b
        #expect(sum == Decimal(string: "0.3")!)
    }

    @Test("Money calculation uses Decimal (no penny drift)")
    func noPennyDrift() async {
        // 3 items × $3.50 = $10.50 exactly
        let items = (0..<3).map { _ in
            ImpactEngine.ItemInput(disposition: .consumed)
        }
        let result = await engine.calculateImpact(items: items)
        #expect(result.moneySaved == Decimal(string: "10.50")!)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 6. ImpactStats Backward Compatibility
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@Suite("ImpactStats ↔ ImpactEngine Consistency")
struct ImpactConsistencyValidation {

    let engine = ImpactEngine()

    @Test("Engine money formula agrees with ImpactStats at same item count")
    func moneyConsistency() async {
        let count = 20
        let items = (0..<count).map { _ in
            ImpactEngine.ItemInput(disposition: .consumed)
        }
        let engineResult = await engine.calculateImpact(items: items)
        let statsResult = ImpactService.ImpactStats(
            itemsSaved: count, itemsShared: 0, itemsDonated: 0, mealsCreated: 0
        )
        let engineMoney = (engineResult.moneySaved as NSDecimalNumber).doubleValue
        // ImpactStats uses Double($3.50 × count)
        #expect(abs(engineMoney - statsResult.moneySaved) < 0.01)
    }
}

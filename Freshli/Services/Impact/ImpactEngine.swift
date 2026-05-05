import Foundation

// MARK: - Impact Engine (Actor-Isolated, Decimal-Precision)
// Uses Decimal arithmetic for all financial and CO2 calculations
// to eliminate floating-point rounding errors in user-facing metrics.

actor ImpactEngine {

    // MARK: - Constants (Decimal for precision)

    /// Average cost per food item saved from waste (USD)
    static let costPerItemSaved: Decimal = Decimal(string: "3.50")!

    /// CO2 footprint per item (kg) — averaged across categories
    static let co2PerItemGeneric: Decimal = Decimal(string: "2.5")!

    /// Category-specific CO2 factors (kg CO2 per kg of food)
    static let co2PerKgByCategory: [String: Decimal] = [
        "meat":       Decimal(string: "27.0")!,   // Beef/lamb average
        "seafood":    Decimal(string: "11.7")!,
        "dairy":      Decimal(string: "3.2")!,
        "fruits":     Decimal(string: "1.1")!,
        "vegetables": Decimal(string: "2.0")!,
        "grains":     Decimal(string: "1.4")!,
        "bakery":     Decimal(string: "1.3")!,
        "frozen":     Decimal(string: "2.5")!,
        "canned":     Decimal(string: "1.6")!,
        "condiments": Decimal(string: "1.8")!,
        "snacks":     Decimal(string: "2.0")!,
        "beverages":  Decimal(string: "0.8")!,
        "other":      Decimal(string: "2.5")!,
    ]

    /// Currency conversion rates (from USD)
    static let currencyRates: [String: Decimal] = [
        "USD": Decimal(1),
        "GBP": Decimal(string: "0.79")!,
        "EUR": Decimal(string: "0.92")!,
        "CAD": Decimal(string: "1.36")!,
        "AUD": Decimal(string: "1.53")!,
        "JPY": Decimal(string: "149.50")!,
    ]

    // MARK: - Impact Snapshot (All Decimal)

    struct ImpactSnapshot: Sendable, Equatable {
        let moneySaved: Decimal
        let co2Avoided: Decimal
        let totalItemsSaved: Int
        let itemsShared: Int
        let itemsDonated: Int
        let mealsHelped: Int
        let currentStreak: Int

        /// Formatted money string (no decimals for display)
        func moneySavedDisplay(currency: String = "USD") -> String {
            let rate = ImpactEngine.currencyRates[currency] ?? Decimal(1)
            let converted = moneySaved * rate
            let symbol = Self.currencySymbol(for: currency)
            let nsDecimal = converted as NSDecimalNumber
            return "\(symbol)\(nsDecimal.intValue)"
        }

        /// Formatted CO2 string (1 decimal)
        var co2Display: String {
            let nsDecimal = co2Avoided as NSDecimalNumber
            return String(format: "%.1fkg", nsDecimal.doubleValue)
        }

        private static func currencySymbol(for code: String) -> String {
            switch code {
            case "USD", "CAD", "AUD": return "$"
            case "GBP": return "£"
            case "EUR": return "€"
            case "JPY": return "¥"
            default: return "$"
            }
        }
    }

    // MARK: - Item Input (for batch calculations)

    struct ItemInput: Sendable {
        let category: String
        let quantity: Decimal
        let estimatedWeightKg: Decimal
        let disposition: Disposition

        enum Disposition: String, Sendable {
            case consumed, shared, donated, wasted
        }

        init(
            category: String = "other",
            quantity: Decimal = 1,
            estimatedWeightKg: Decimal = Decimal(string: "0.5")!,
            disposition: Disposition = .consumed
        ) {
            self.category = category
            self.quantity = quantity
            self.estimatedWeightKg = estimatedWeightKg
            self.disposition = disposition
        }
    }

    // MARK: - Calculation

    /// Calculate impact from a batch of items using Decimal arithmetic.
    func calculateImpact(items: [ItemInput], currentStreak: Int = 0) -> ImpactSnapshot {
        var moneySaved: Decimal = 0
        var co2Avoided: Decimal = 0
        var totalSaved = 0
        var shared = 0
        var donated = 0

        for item in items {
            switch item.disposition {
            case .consumed:
                totalSaved += 1
                moneySaved += Self.costPerItemSaved * item.quantity
                co2Avoided += co2ForItem(item)
            case .shared:
                totalSaved += 1
                shared += 1
                moneySaved += Self.costPerItemSaved * item.quantity
                co2Avoided += co2ForItem(item)
            case .donated:
                totalSaved += 1
                donated += 1
                moneySaved += Self.costPerItemSaved * item.quantity
                co2Avoided += co2ForItem(item)
            case .wasted:
                break // No positive impact
            }
        }

        // Clamp to non-negative
        moneySaved = max(0, moneySaved)
        co2Avoided = max(0, co2Avoided)

        return ImpactSnapshot(
            moneySaved: moneySaved,
            co2Avoided: co2Avoided,
            totalItemsSaved: totalSaved,
            itemsShared: shared,
            itemsDonated: donated,
            mealsHelped: shared + donated,
            currentStreak: currentStreak
        )
    }

    /// Category-specific CO2 calculation using weight and per-kg factor
    func co2ForItem(_ item: ItemInput) -> Decimal {
        let factor = Self.co2PerKgByCategory[item.category.lowercased()] ?? Self.co2PerItemGeneric
        return factor * item.estimatedWeightKg * item.quantity
    }

    // MARK: - Streak Logic

    /// Compute new streak given previous streak date and today.
    /// Returns (newStreak, shouldCelebrate, celebrationDay).
    func computeStreak(
        lastStreakDate: Date?,
        today: Date,
        currentStreak: Int,
        calendar: Calendar = .current
    ) -> (newStreak: Int, shouldCelebrate: Bool, celebrationDay: Int?) {
        let todayStart = calendar.startOfDay(for: today)

        guard let lastDate = lastStreakDate else {
            // First ever action
            return (1, false, nil)
        }

        let lastStart = calendar.startOfDay(for: lastDate)
        let daysDiff = calendar.dateComponents([.day], from: lastStart, to: todayStart).day ?? 0

        let newStreak: Int
        if daysDiff == 0 {
            // Same day — no change
            return (currentStreak, false, nil)
        } else if daysDiff == 1 {
            newStreak = currentStreak + 1
        } else {
            // Gap > 1 day — reset
            newStreak = 1
        }

        let celebrationDays = [3, 7, 14, 30]
        let shouldCelebrate = celebrationDays.contains(newStreak)
        return (newStreak, shouldCelebrate, shouldCelebrate ? newStreak : nil)
    }

    // MARK: - Community Impact

    struct CommunityImpact: Sendable, Equatable {
        let giverItemsShared: Int
        let giverCO2Avoided: Decimal
        let receiverItemsReceived: Int
        let receiverMoneySaved: Decimal
    }

    /// Compute community impact for a sharing event.
    func computeCommunityImpact(
        sharedItems: [ItemInput]
    ) -> CommunityImpact {
        var giverCO2: Decimal = 0
        var receiverMoney: Decimal = 0

        for item in sharedItems {
            giverCO2 += co2ForItem(item)
            receiverMoney += Self.costPerItemSaved * item.quantity
        }

        return CommunityImpact(
            giverItemsShared: sharedItems.count,
            giverCO2Avoided: giverCO2,
            receiverItemsReceived: sharedItems.count,
            receiverMoneySaved: receiverMoney
        )
    }
}

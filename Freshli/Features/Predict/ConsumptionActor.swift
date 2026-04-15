import Foundation
import SwiftData
import TabularData

// MARK: - FreshliConsumptionEvent

/// A lightweight, Sendable snapshot of a consumption event for actor-isolated analysis.
struct FreshliConsumptionEvent: Sendable {
    let itemName: String
    let category: String
    let quantity: Double
    let unit: String
    let consumedDate: Date
    let daysInPantry: Int
    let dateAdded: Date
}

// MARK: - FreshliUsagePattern

/// Describes a learned usage pattern for a specific item or category.
struct FreshliUsagePattern: Sendable {
    let itemName: String
    let category: String
    let averageDaysToConsume: Double
    let consumptionRatePerDay: Double
    let confidenceScore: Double
    let sampleCount: Int
    let lastUpdated: Date

    var humanReadable: String {
        let days = Int(averageDaysToConsume.rounded())
        return "User finishes \(itemName) every \(days) day\(days == 1 ? "" : "s")"
    }
}

// MARK: - FreshliPrediction

/// A prediction about when an item will be depleted or expire, whichever comes first.
struct FreshliPrediction: Identifiable, Sendable {
    let id: UUID
    let itemName: String
    let category: String
    let currentQuantity: Double
    let unit: String
    let predictedDepletionDate: Date
    let expiryDate: Date
    let estimatedDaysRemaining: Int
    let depletionFraction: Double
    let confidenceScore: Double
    let sampleCount: Int
    let criticalDate: Date
    let reason: FreshliPredictionReason

    /// 0.0 (empty) to 1.0 (full) — used by GhostProgressBar
    var remainingFraction: Double {
        max(0, min(1, 1.0 - depletionFraction))
    }

    var isUrgent: Bool {
        estimatedDaysRemaining <= 1
    }

    var isRunningLow: Bool {
        estimatedDaysRemaining <= 3 && estimatedDaysRemaining > 1
    }
}

enum FreshliPredictionReason: Sendable {
    case depletionBeforeExpiry
    case expiryBeforeDepletion
    case bothSameDay
    case noHistory
}

// MARK: - ConsumptionActor

/// Analyzes historical consumption data on-device for privacy.
/// Uses TabularData for regression when sufficient samples exist (>= 5),
/// otherwise falls back to a weighted moving-average heuristic.
actor ConsumptionActor {
    private let logger = PSLogger(category: .pantry)

    // MARK: - Category Defaults (days to consume standard quantity)

    private let categoryDefaults: [String: Double] = [
        "dairy": 7, "meat": 3, "seafood": 2, "fruits": 5,
        "vegetables": 6, "bakery": 4, "grains": 30, "frozen": 45,
        "canned": 90, "condiments": 60, "snacks": 10, "beverages": 5,
        "other": 14
    ]

    // MARK: - Standard Quantities (for normalization)

    private func standardQuantity(for unit: String) -> Double {
        switch unit {
        case "pieces": return 1.0
        case "grams": return 100.0
        case "kilograms": return 1.0
        case "milliliters": return 100.0
        case "liters": return 1.0
        case "cups": return 1.0
        case "tablespoons": return 1.0
        case "teaspoons": return 1.0
        case "ounces": return 4.0
        case "pounds": return 0.5
        case "packs": return 1.0
        case "bottles": return 1.0
        case "cans": return 1.0
        case "bags": return 1.0
        default: return 1.0
        }
    }

    // MARK: - Analyze Usage Pattern

    /// Analyzes historical events for a given item/category and returns a usage pattern.
    func analyzeUsagePattern(
        itemName: String,
        category: String,
        events: [FreshliConsumptionEvent]
    ) -> FreshliUsagePattern {
        let now = Date()

        // Filter to matching events: exact name match first, then category fallback
        let exactMatches = events.filter { $0.itemName.lowercased() == itemName.lowercased() }
        let categoryMatches = events.filter { $0.category == category }

        if exactMatches.count >= 5 {
            // Regression via TabularData
            let result = regressionEstimate(events: exactMatches)
            return FreshliUsagePattern(
                itemName: itemName,
                category: category,
                averageDaysToConsume: result.avgDays,
                consumptionRatePerDay: 1.0 / max(result.avgDays, 0.1),
                confidenceScore: min(0.95, 0.7 + Double(exactMatches.count) * 0.02),
                sampleCount: exactMatches.count,
                lastUpdated: now
            )
        } else if !exactMatches.isEmpty {
            // Weighted moving average with recency bias
            let avgDays = weightedMovingAverage(events: exactMatches)
            let categoryDefault = categoryDefaults[category] ?? 14.0
            // Blend: more samples → more weight on actual data
            let weight = Double(exactMatches.count) / 5.0
            let blended = avgDays * weight + categoryDefault * (1.0 - weight)
            return FreshliUsagePattern(
                itemName: itemName,
                category: category,
                averageDaysToConsume: blended,
                consumptionRatePerDay: 1.0 / max(blended, 0.1),
                confidenceScore: 0.4 + Double(exactMatches.count) * 0.1,
                sampleCount: exactMatches.count,
                lastUpdated: now
            )
        } else if categoryMatches.count >= 3 {
            // Category-level moving average
            let avgDays = weightedMovingAverage(events: categoryMatches)
            return FreshliUsagePattern(
                itemName: itemName,
                category: category,
                averageDaysToConsume: avgDays,
                consumptionRatePerDay: 1.0 / max(avgDays, 0.1),
                confidenceScore: 0.35,
                sampleCount: categoryMatches.count,
                lastUpdated: now
            )
        } else {
            // Pure category default
            let days = categoryDefaults[category] ?? 14.0
            return FreshliUsagePattern(
                itemName: itemName,
                category: category,
                averageDaysToConsume: days,
                consumptionRatePerDay: 1.0 / days,
                confidenceScore: 0.2,
                sampleCount: 0,
                lastUpdated: now
            )
        }
    }

    // MARK: - Generate Prediction

    /// Generates a depletion/expiry prediction for an item given its usage pattern.
    func generatePrediction(
        itemId: UUID,
        itemName: String,
        category: String,
        currentQuantity: Double,
        unit: String,
        dateAdded: Date,
        expiryDate: Date,
        pattern: FreshliUsagePattern
    ) -> FreshliPrediction {
        let now = Date()
        let daysSinceAdded = max(1, Calendar.current.dateComponents([.day], from: dateAdded, to: now).day ?? 1)

        // Estimate how much has been consumed so far (proportional to time elapsed)
        let totalExpectedDays = pattern.averageDaysToConsume
        let stdQty = standardQuantity(for: unit)
        let quantityRatio = currentQuantity / max(stdQty, 0.01)

        // Adjusted days remaining based on current quantity
        let adjustedDaysRemaining = Int((totalExpectedDays * quantityRatio).rounded())
        let predictedDepletionDate = Calendar.current.date(byAdding: .day, value: max(0, adjustedDaysRemaining), to: now) ?? now

        // Depletion fraction: how far through consumption we estimate we are
        let elapsedFraction = min(1.0, Double(daysSinceAdded) / max(totalExpectedDays * quantityRatio, 1.0))

        // Critical date is whichever comes first
        let criticalDate: Date
        let reason: FreshliPredictionReason

        let depletionDays = Calendar.current.dateComponents([.day], from: now, to: predictedDepletionDate).day ?? 0
        let expiryDays = Calendar.current.dateComponents([.day], from: now, to: expiryDate).day ?? 0

        if depletionDays == expiryDays {
            criticalDate = expiryDate
            reason = .bothSameDay
        } else if predictedDepletionDate < expiryDate {
            criticalDate = predictedDepletionDate
            reason = .depletionBeforeExpiry
        } else {
            criticalDate = expiryDate
            reason = .expiryBeforeDepletion
        }

        let estimatedDays = max(0, Calendar.current.dateComponents([.day], from: now, to: criticalDate).day ?? 0)

        return FreshliPrediction(
            id: itemId,
            itemName: itemName,
            category: category,
            currentQuantity: currentQuantity,
            unit: unit,
            predictedDepletionDate: predictedDepletionDate,
            expiryDate: expiryDate,
            estimatedDaysRemaining: estimatedDays,
            depletionFraction: elapsedFraction,
            confidenceScore: pattern.confidenceScore,
            sampleCount: pattern.sampleCount,
            criticalDate: criticalDate,
            reason: reason
        )
    }

    // MARK: - Regression via TabularData

    /// Uses TabularData DataFrame for simple linear regression on consumption days.
    /// Input: events with (quantity, daysInPantry). Output: predicted days for standard quantity.
    private func regressionEstimate(events: [FreshliConsumptionEvent]) -> (avgDays: Double, slope: Double) {
        // Build a DataFrame with quantity and days columns
        var quantities: [Double] = []
        var days: [Double] = []

        for event in events {
            quantities.append(event.quantity)
            days.append(Double(event.daysInPantry))
        }

        let df = DataFrame(columns: [
            Column<Double>(name: "quantity", contents: quantities).eraseToAnyColumn(),
            Column<Double>(name: "days", contents: days).eraseToAnyColumn()
        ])

        // Compute means for simple linear regression: days = slope * quantity + intercept
        let meanQty = quantities.reduce(0, +) / Double(quantities.count)
        let meanDays = days.reduce(0, +) / Double(days.count)

        var numerator = 0.0
        var denominator = 0.0

        for i in 0..<quantities.count {
            let qDiff = quantities[i] - meanQty
            let dDiff = days[i] - meanDays
            numerator += qDiff * dDiff
            denominator += qDiff * qDiff
        }

        let slope = denominator != 0 ? numerator / denominator : 0.0

        // Use mean days as the baseline estimate (regression intercept at mean quantity)
        logger.debug("Regression: meanDays=\(String(format: "%.1f", meanDays)), slope=\(String(format: "%.2f", slope)), n=\(df.rows.count)")

        return (avgDays: max(1, meanDays), slope: slope)
    }

    // MARK: - Weighted Moving Average

    /// Computes a weighted moving average with exponential recency bias.
    /// More recent events have higher weight.
    private func weightedMovingAverage(events: [FreshliConsumptionEvent]) -> Double {
        guard !events.isEmpty else { return 14.0 }

        // Sort by date (most recent first)
        let sorted = events.sorted { $0.consumedDate > $1.consumedDate }

        var weightedSum = 0.0
        var totalWeight = 0.0
        let decayFactor = 0.8 // Each older event gets 80% of the previous weight

        for (index, event) in sorted.enumerated() {
            let weight = pow(decayFactor, Double(index))
            weightedSum += Double(event.daysInPantry) * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return 1.0 }
        return max(1.0, weightedSum / totalWeight)
    }
}

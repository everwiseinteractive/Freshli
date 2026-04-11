import Foundation
import SwiftUI

// MARK: - Council Data Service
// Generates anonymised postcode-level waste reports for local councils.
// Helps with waste management planning — councils pay for the data.

// MARK: - Models

struct CouncilReport: Identifiable {
    let id = UUID()
    let postcode: String
    let reportPeriod: String
    let totalWastedItems: Int
    let totalWastedKg: Double
    let totalFinancialImpact: Double
    let estimatedCO2Impact: Double
    let topWastedCategories: [(category: String, count: Int)]
    let topReasons: [(reason: String, count: Int)]
    let householdCount: Int
    let potentialSavingsPerHousehold: Double
    let comparison: ComparisonData?
}

struct ComparisonData {
    let nationalAverage: Int    // items per household per month
    let regionalAverage: Int
    let rank: Int               // 1-100 percentile
}

// MARK: - Service

@MainActor
final class CouncilDataService {
    static let shared = CouncilDataService()
    private init() {}

    /// Generate an anonymised council-level waste report from user data.
    /// In production this would aggregate data from many users. Here we use
    /// a single user's data as a representative sample for the postcode.
    func generateReport(items: [FreshliItem], binEntries: [BinEntry], postcode: String = "SW1A 1AA") -> CouncilReport {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now

        // Waste from bin log + unconsumed expired items
        let recentBinned = binEntries.filter { $0.date >= thirtyDaysAgo }
        let expiredUnconsumed = items.filter {
            !$0.isConsumed && !$0.isShared && !$0.isDonated && $0.expiryDate < now && $0.dateAdded >= thirtyDaysAgo
        }

        let totalItems = recentBinned.count + expiredUnconsumed.count
        let estimatedKg = Double(totalItems) * 0.35  // avg item weight
        let financialImpact = recentBinned.reduce(0.0) { $0 + $1.costEstimate }
            + Double(expiredUnconsumed.count) * 3.50
        let co2Impact = Double(totalItems) * 2.5

        // Top categories
        var categoryCounts: [String: Int] = [:]
        for entry in recentBinned { categoryCounts[entry.categoryRaw, default: 0] += 1 }
        for item in expiredUnconsumed { categoryCounts[item.category.rawValue, default: 0] += 1 }
        let topCategories = categoryCounts.map { ($0.key.capitalized, $0.value) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { (category: $0.0, count: $0.1) }

        // Top reasons
        var reasonCounts: [String: Int] = [:]
        for entry in recentBinned { reasonCounts[entry.reason.rawValue, default: 0] += 1 }
        let topReasons = reasonCounts.map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
            .prefix(4)
            .map { (reason: $0.0, count: $0.1) }

        // Simulated household + comparison data
        let householdCount = 1  // single-user mode — in production this would be real count
        let savingsPerHousehold = financialImpact  // fully attributable to this household

        let comparison = ComparisonData(
            nationalAverage: 24,
            regionalAverage: 21,
            rank: totalItems < 10 ? 85 : (totalItems < 20 ? 60 : 35)
        )

        return CouncilReport(
            postcode: postcode,
            reportPeriod: "Last 30 days",
            totalWastedItems: totalItems,
            totalWastedKg: estimatedKg,
            totalFinancialImpact: financialImpact,
            estimatedCO2Impact: co2Impact,
            topWastedCategories: Array(topCategories),
            topReasons: Array(topReasons),
            householdCount: householdCount,
            potentialSavingsPerHousehold: savingsPerHousehold,
            comparison: comparison
        )
    }
}

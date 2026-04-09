import Foundation
import Observation

// MARK: - DonationRecord Model

struct DonationRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    var items: [String]  // Item names/descriptions
    var estimatedValue: Double  // in dollars
    let category: DonationCategory
    var taxDeductible: Bool

    enum DonationCategory: String, Codable {
        case foodBank = "food_bank"
        case neighbor = "neighbor"
        case community = "community"
        case school = "school"
        case shelter = "shelter"
        case other = "other"

        var displayName: String {
            switch self {
            case .foodBank: return "Food Bank"
            case .neighbor: return "Neighbor"
            case .community: return "Community"
            case .school: return "School"
            case .shelter: return "Shelter"
            case .other: return "Other"
            }
        }
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        items: [String],
        estimatedValue: Double,
        category: DonationCategory = .foodBank,
        taxDeductible: Bool = true
    ) {
        self.id = id
        self.date = date
        self.items = items
        self.estimatedValue = estimatedValue
        self.category = category
        self.taxDeductible = taxDeductible
    }
}

// MARK: - TaxReport Model

struct TaxReport {
    let year: Int
    let totalValue: Double
    let itemCount: Int
    let organizationBreakdown: [String: Double]  // Organization name -> total value
    let categoryBreakdown: [DonationRecord.DonationCategory: Double]

    var formattedSummary: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current

        let totalFormatted = formatter.string(from: NSNumber(value: totalValue)) ?? "$0.00"
        return """
        Tax Report for \(year)
        Total Donations: \(totalFormatted)
        Items Donated: \(itemCount)
        """
    }
}

// MARK: - DonationAnalyticsService

@Observable
final class DonationAnalyticsService {
    private let donationRecordsKey = "freshli_donation_records"

    var records: [DonationRecord] = [] {
        didSet {
            saveDonationRecords()
        }
    }

    init() {
        loadDonationRecords()
    }

    // MARK: - Computed Properties

    var totalDonations: Int {
        records.count
    }

    var totalEstimatedValue: Double {
        records.reduce(0) { $0 + $1.estimatedValue }
    }

    var totalTaxDeductibleValue: Double {
        records.filter { $0.taxDeductible }
            .reduce(0) { $0 + $1.estimatedValue }
    }

    var monthlyBreakdown: [String: Double] {
        let calendar = Calendar.current
        var breakdown: [String: Double] = [:]

        for record in records {
            let components = calendar.dateComponents([.year, .month], from: record.date)
            guard let year = components.year, let month = components.month else { continue }

            let key = String(format: "%04d-%02d", year, month)
            breakdown[key, default: 0] += record.estimatedValue
        }

        return breakdown
    }

    var yearlyBreakdown: [Int: Double] {
        let calendar = Calendar.current
        var breakdown: [Int: Double] = [:]

        for record in records {
            let year = calendar.component(.year, from: record.date)
            breakdown[year, default: 0] += record.estimatedValue
        }

        return breakdown
    }

    var categoryBreakdown: [DonationRecord.DonationCategory: Double] {
        var breakdown: [DonationRecord.DonationCategory: Double] = [:]

        for record in records {
            breakdown[record.category, default: 0] += record.estimatedValue
        }

        return breakdown
    }

    var recentDonations: [DonationRecord] {
        records.sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }

    // MARK: - Recording Donations

    func recordDonation(
        items: [String],
        estimatedValue: Double,
        category: DonationRecord.DonationCategory = .foodBank,
        taxDeductible: Bool = true,
        date: Date = Date()
    ) {
        let record = DonationRecord(
            date: date,
            items: items,
            estimatedValue: estimatedValue,
            category: category,
            taxDeductible: taxDeductible
        )

        records.append(record)
    }

    func deleteDonation(_ record: DonationRecord) {
        records.removeAll { $0.id == record.id }
    }

    // MARK: - Tax Report Generation

    func generateTaxReport(year: Int) -> TaxReport {
        let calendar = Calendar.current
        var yearRecords: [DonationRecord] = []

        for record in records {
            let recordYear = calendar.component(.year, from: record.date)
            if recordYear == year && record.taxDeductible {
                yearRecords.append(record)
            }
        }

        let totalValue = yearRecords.reduce(0) { $0 + $1.estimatedValue }
        let itemCount = yearRecords.reduce(0) { $0 + $1.items.count }

        var organizationBreakdown: [String: Double] = [:]
        var categoryBreakdown: [DonationRecord.DonationCategory: Double] = [:]

        for record in yearRecords {
            // Organization tracking could be enhanced with actual organization names
            let orgKey = record.category.displayName
            organizationBreakdown[orgKey, default: 0] += record.estimatedValue
            categoryBreakdown[record.category, default: 0] += record.estimatedValue
        }

        return TaxReport(
            year: year,
            totalValue: totalValue,
            itemCount: itemCount,
            organizationBreakdown: organizationBreakdown,
            categoryBreakdown: categoryBreakdown
        )
    }

    // MARK: - Export

    func exportToCSV() -> String {
        var csv = "Date,Items,Value,Category,Tax Deductible\n"

        let formatter = ISO8601DateFormatter()

        for record in records.sorted(by: { $0.date > $1.date }) {
            let dateString = formatter.string(from: record.date)
            let itemsString = record.items.joined(separator: ";")
            let valueString = String(format: "%.2f", record.estimatedValue)
            let categoryString = record.category.displayName
            let taxDeductibleString = record.taxDeductible ? "Yes" : "No"

            csv += "\(dateString),\"\(itemsString)\",\(valueString),\(categoryString),\(taxDeductibleString)\n"
        }

        return csv
    }

    func exportTaxReport(year: Int) -> String {
        let report = generateTaxReport(year: year)

        var text = "\(report.formattedSummary)\n\n"

        text += "Category Breakdown:\n"
        for (category, value) in report.categoryBreakdown.sorted(by: { $0.value > $1.value }) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            let valueFormatted = formatter.string(from: NSNumber(value: value)) ?? "$0.00"
            text += "  \(category.displayName): \(valueFormatted)\n"
        }

        return text
    }

    // MARK: - Persistence

    private func saveDonationRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: donationRecordsKey)
        }
    }

    private func loadDonationRecords() {
        if let data = UserDefaults.standard.data(forKey: donationRecordsKey),
           let decoded = try? JSONDecoder().decode([DonationRecord].self, from: data) {
            records = decoded
        }
    }
}

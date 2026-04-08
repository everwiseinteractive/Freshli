import Foundation
import SwiftData

// MARK: - ConsumptionRecord Model

/// Tracks historical consumption data to inform depletion predictions.
@Model
final class ConsumptionRecord {
    var id: UUID
    var itemName: String
    var category: String  // Raw value of FoodCategory
    var quantity: Double
    var unit: String  // Raw value of MeasurementUnit
    var consumedDate: Date
    var daysInPantry: Int  // How long item was in pantry before consumed
    var householdSize: Int  // Default 2

    init(
        itemName: String,
        category: String,
        quantity: Double,
        unit: String,
        consumedDate: Date = Date(),
        daysInPantry: Int,
        householdSize: Int = 2
    ) {
        self.id = UUID()
        self.itemName = itemName
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.consumedDate = consumedDate
        self.daysInPantry = daysInPantry
        self.householdSize = householdSize
    }
}

// MARK: - DepletionSuggestion Enum

enum DepletionSuggestion {
    case likelyEmpty      // Past predicted depletion date
    case runningLow       // Within 2 days of predicted depletion
    case plentiful        // Not close to depletion
    case unknown          // No data to predict
}

// MARK: - DepletionPrediction Struct

struct DepletionPrediction: Identifiable {
    let id: UUID
    let itemName: String
    let predictedDepletionDate: Date
    let confidenceScore: Double  // 0-1
    let estimatedDaysRemaining: Int
    let suggestion: DepletionSuggestion
    let basedOnRecords: Int  // How many historical records informed prediction

    var itemId: UUID { id }
}

// MARK: - DepletionService

@Observable
final class DepletionService {
    private let logger = PSLogger(category: .pantry)

    // MARK: - Category Defaults

    /// Average days to consumption by category (based on typical shelf life)
    private let categoryDefaults: [String: Int] = [
        "dairy": 7,
        "meat": 3,
        "seafood": 2,
        "fruits": 5,
        "vegetables": 6,
        "bakery": 4,
        "grains": 30,
        "frozen": 45,
        "canned": 90,
        "condiments": 60,
        "snacks": 10,
        "beverages": 5,
        "other": 14
    ]

    // MARK: - Public Methods

    /// Record that an item has been consumed
    func recordConsumption(item: PantryItem, modelContext: ModelContext) {
        let daysInPantry = Calendar.current.dateComponents([.day], from: item.dateAdded, to: Date()).day ?? 0

        let record = ConsumptionRecord(
            itemName: item.name,
            category: item.categoryRaw,
            quantity: item.quantity,
            unit: item.unitRaw,
            consumedDate: Date(),
            daysInPantry: max(1, daysInPantry),
            householdSize: 2
        )

        modelContext.insert(record)

        do {
            try modelContext.save()
            logger.info("Recorded consumption for \(item.name) (daysInPantry: \(daysInPantry))")
        } catch {
            logger.error("Failed to record consumption: \(error.localizedDescription)")
        }
    }

    /// Predict when an item will be depleted
    func predictDepletion(for item: PantryItem, modelContext: ModelContext) -> DepletionPrediction {
        let today = Date()
        let records = fetchConsumptionRecords(itemName: item.name, category: item.categoryRaw, modelContext: modelContext)

        // Calculate average days to consumption
        let (avgDays, confidenceScore, basedOnRecords) = calculateAverageDaysToConsumption(
            records: records,
            category: item.categoryRaw,
            quantity: item.quantity,
            unit: item.unitRaw
        )

        // Adjust based on current quantity
        let adjustedDays = adjustForQuantity(
            baseDays: avgDays,
            currentQuantity: item.quantity,
            standardQuantity: standardQuantityForUnit(item.unit)
        )

        let estimatedDaysRemaining = max(0, adjustedDays)
        let predictedDepletionDate = Calendar.current.date(byAdding: .day, value: estimatedDaysRemaining, to: today) ?? today

        // Determine suggestion
        let daysUntilDepletion = Calendar.current.dateComponents([.day], from: today, to: predictedDepletionDate).day ?? 0
        let suggestion = determineSuggestion(daysRemaining: daysUntilDepletion)

        logger.debug("Predicted depletion for \(item.name): \(estimatedDaysRemaining) days remaining (confidence: \(String(format: "%.2f", confidenceScore)))")

        return DepletionPrediction(
            id: item.id,
            itemName: item.name,
            predictedDepletionDate: predictedDepletionDate,
            confidenceScore: confidenceScore,
            estimatedDaysRemaining: estimatedDaysRemaining,
            suggestion: suggestion,
            basedOnRecords: basedOnRecords
        )
    }

    /// Predict depletion for multiple items
    func predictionsForAllItems(items: [PantryItem], modelContext: ModelContext) -> [DepletionPrediction] {
        return items.map { predictDepletion(for: $0, modelContext: modelContext) }
    }

    /// Get items likely empty now or very soon
    func getDepletionSuggestions(modelContext: ModelContext) -> [DepletionPrediction] {
        let descriptor = FetchDescriptor<PantryItem>(
            predicate: #Predicate<PantryItem> { item in
                !item.isConsumed && !item.isShared && !item.isDonated
            }
        )

        do {
            let activeItems = try modelContext.fetch(descriptor)
            let predictions = predictionsForAllItems(items: activeItems, modelContext: modelContext)

            // Filter to only critical items
            return predictions.filter { prediction in
                switch prediction.suggestion {
                case .likelyEmpty, .runningLow:
                    return true
                default:
                    return false
                }
            }
        } catch {
            logger.error("Failed to fetch depletion suggestions: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Private Methods

    /// Fetch consumption records for a specific item or category
    private func fetchConsumptionRecords(itemName: String, category: String, modelContext: ModelContext) -> [ConsumptionRecord] {
        let searchName = itemName
        let searchCategory = category
        let descriptor = FetchDescriptor<ConsumptionRecord>(
            predicate: #Predicate<ConsumptionRecord> { record in
                record.itemName == searchName ||
                record.category == searchCategory
            }
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch consumption records: \(error.localizedDescription)")
            return []
        }
    }

    /// Calculate average days to consumption with confidence scoring
    private func calculateAverageDaysToConsumption(
        records: [ConsumptionRecord],
        category: String,
        quantity: Double,
        unit: String
    ) -> (avgDays: Int, confidenceScore: Double, basedOnRecords: Int) {
        let itemSpecificRecords = records.filter { $0.itemName.lowercased() == records.first?.itemName.lowercased() ?? "" }

        if itemSpecificRecords.count >= 3 {
            // High confidence: use item-specific average
            let avgDays = Int(itemSpecificRecords.map { Double($0.daysInPantry) }.reduce(0, +) / Double(itemSpecificRecords.count))
            return (avgDays, 0.85, itemSpecificRecords.count)
        } else if !itemSpecificRecords.isEmpty && itemSpecificRecords.count > 0 {
            // Medium confidence: blend item average with category default
            let itemAvg = Int(itemSpecificRecords.map { Double($0.daysInPantry) }.reduce(0, +) / Double(itemSpecificRecords.count))
            let categoryDefault = categoryDefaults[category] ?? 14
            let blended = Int(Double(itemAvg) * 0.6 + Double(categoryDefault) * 0.4)
            return (blended, 0.60, itemSpecificRecords.count)
        } else {
            // Low confidence: use category default
            let categoryDefault = categoryDefaults[category] ?? 14
            return (categoryDefault, 0.40, 0)
        }
    }

    /// Adjust prediction based on current quantity relative to standard
    private func adjustForQuantity(baseDays: Int, currentQuantity: Double, standardQuantity: Double) -> Int {
        let multiplier = currentQuantity / max(standardQuantity, 0.1)
        return Int(Double(baseDays) * multiplier)
    }

    /// Standard quantity for a unit (for normalization)
    private func standardQuantityForUnit(_ unit: MeasurementUnit) -> Double {
        switch unit {
        case .pieces: return 1.0
        case .grams: return 100.0
        case .kilograms: return 1.0
        case .milliliters: return 100.0
        case .liters: return 1.0
        case .cups: return 1.0
        case .tablespoons: return 1.0
        case .teaspoons: return 1.0
        case .ounces: return 4.0
        case .pounds: return 0.5
        case .packs: return 1.0
        case .bottles: return 1.0
        case .cans: return 1.0
        case .bags: return 1.0
        }
    }

    /// Determine suggestion based on days remaining
    private func determineSuggestion(daysRemaining: Int) -> DepletionSuggestion {
        if daysRemaining < 0 {
            return .likelyEmpty
        } else if daysRemaining <= 2 {
            return .runningLow
        } else {
            return .plentiful
        }
    }
}

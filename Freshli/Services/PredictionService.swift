import Foundation
import SwiftData

// MARK: - FreshliPredictionService

/// Manages the prediction lifecycle: fetches history, runs ConsumptionActor analysis,
/// caches predictions, and coordinates with NotificationService for smart alerts.
@Observable @MainActor
final class FreshliPredictionService {
    private(set) var predictions: [FreshliPrediction] = []
    private(set) var patterns: [String: FreshliUsagePattern] = [:]
    private(set) var isAnalyzing = false
    private(set) var lastAnalysisDate: Date?

    private let actor = ConsumptionActor()
    private let logger = PSLogger(category: .pantry)

    // MARK: - Full Analysis

    /// Runs a full prediction pass for all active pantry items.
    /// Call on app launch, after sync, or when items change.
    func analyzeAllItems(modelContext: ModelContext) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        defer {
            isAnalyzing = false
            lastAnalysisDate = Date()
        }

        let activeItems = fetchActiveItems(modelContext: modelContext)
        guard !activeItems.isEmpty else {
            predictions = []
            return
        }

        let events = fetchConsumptionEvents(modelContext: modelContext)
        var newPredictions: [FreshliPrediction] = []
        var newPatterns: [String: FreshliUsagePattern] = [:]

        for item in activeItems {
            let pattern = await actor.analyzeUsagePattern(
                itemName: item.name,
                category: item.categoryRaw,
                events: events
            )

            let prediction = await actor.generatePrediction(
                itemId: item.id,
                itemName: item.name,
                category: item.categoryRaw,
                currentQuantity: item.quantity,
                unit: item.unitRaw,
                dateAdded: item.dateAdded,
                expiryDate: item.expiryDate,
                pattern: pattern
            )

            newPredictions.append(prediction)
            newPatterns[item.id.uuidString] = pattern
        }

        predictions = newPredictions.sorted { $0.estimatedDaysRemaining < $1.estimatedDaysRemaining }
        patterns = newPatterns

        logger.info("Analyzed \(activeItems.count) items, generated \(newPredictions.count) predictions")
    }

    // MARK: - Single Item Prediction

    /// Generates a prediction for a single item (e.g., after quantity change).
    func predictForItem(_ item: FreshliItem, modelContext: ModelContext) async -> FreshliPrediction? {
        let events = fetchConsumptionEvents(modelContext: modelContext)

        let pattern = await actor.analyzeUsagePattern(
            itemName: item.name,
            category: item.categoryRaw,
            events: events
        )

        let prediction = await actor.generatePrediction(
            itemId: item.id,
            itemName: item.name,
            category: item.categoryRaw,
            currentQuantity: item.quantity,
            unit: item.unitRaw,
            dateAdded: item.dateAdded,
            expiryDate: item.expiryDate,
            pattern: pattern
        )

        // Update cache
        if let index = predictions.firstIndex(where: { $0.id == item.id }) {
            predictions[index] = prediction
        } else {
            predictions.append(prediction)
            predictions.sort { $0.estimatedDaysRemaining < $1.estimatedDaysRemaining }
        }
        patterns[item.id.uuidString] = pattern

        return prediction
    }

    // MARK: - Query Helpers

    /// Returns the cached prediction for a specific item, if available.
    func prediction(for itemId: UUID) -> FreshliPrediction? {
        predictions.first { $0.id == itemId }
    }

    /// Returns the cached usage pattern for a specific item, if available.
    func pattern(for itemId: UUID) -> FreshliUsagePattern? {
        patterns[itemId.uuidString]
    }

    /// Items predicted to deplete or expire within the given number of days.
    func urgentPredictions(within days: Int = 1) -> [FreshliPrediction] {
        predictions.filter { $0.estimatedDaysRemaining <= days }
    }

    /// Items running low (2-3 days remaining).
    func runningLowPredictions() -> [FreshliPrediction] {
        predictions.filter { $0.isRunningLow }
    }

    // MARK: - Record Consumption

    /// Records a consumption event and refreshes predictions.
    func recordConsumption(item: FreshliItem, modelContext: ModelContext) async {
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
            logger.info("Recorded consumption for \(item.name)")
        } catch {
            logger.error("Failed to record consumption: \(error.localizedDescription)")
        }

        // Remove prediction for consumed item
        predictions.removeAll { $0.id == item.id }
        patterns.removeValue(forKey: item.id.uuidString)
    }

    // MARK: - Confirm Prediction Actions

    /// Confirms an item has been consumed — marks it consumed and records history.
    func confirmConsumed(item: FreshliItem, modelContext: ModelContext) async {
        await recordConsumption(item: item, modelContext: modelContext)
        item.isConsumed = true

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to mark item consumed: \(error.localizedDescription)")
        }
    }

    /// Confirms an item has been refilled — resets quantity and refreshes prediction.
    func confirmRefill(item: FreshliItem, newQuantity: Double, modelContext: ModelContext) async {
        // Record partial consumption before refill
        let daysInPantry = Calendar.current.dateComponents([.day], from: item.dateAdded, to: Date()).day ?? 0

        let record = ConsumptionRecord(
            itemName: item.name,
            category: item.categoryRaw,
            quantity: item.quantity, // Log the amount that was consumed before refill
            unit: item.unitRaw,
            consumedDate: Date(),
            daysInPantry: max(1, daysInPantry),
            householdSize: 2
        )

        modelContext.insert(record)
        item.quantity = newQuantity
        item.dateAdded = Date() // Reset the clock for prediction

        do {
            try modelContext.save()
            logger.info("Refilled \(item.name) to \(newQuantity)")
        } catch {
            logger.error("Failed to refill item: \(error.localizedDescription)")
        }

        _ = await predictForItem(item, modelContext: modelContext)
    }

    // MARK: - Private Helpers

    private func fetchActiveItems(modelContext: ModelContext) -> [FreshliItem] {
        let descriptor = FetchDescriptor<FreshliItem>(
            predicate: #Predicate<FreshliItem> { item in
                !item.isConsumed && !item.isShared && !item.isDonated
            },
            sortBy: [SortDescriptor(\FreshliItem.expiryDate)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch active items: \(error.localizedDescription)")
            return []
        }
    }

    private func fetchConsumptionEvents(modelContext: ModelContext) -> [FreshliConsumptionEvent] {
        let descriptor = FetchDescriptor<ConsumptionRecord>(
            sortBy: [SortDescriptor(\ConsumptionRecord.consumedDate, order: .reverse)]
        )

        do {
            let records = try modelContext.fetch(descriptor)
            return records.map { record in
                FreshliConsumptionEvent(
                    itemName: record.itemName,
                    category: record.category,
                    quantity: record.quantity,
                    unit: record.unit,
                    consumedDate: record.consumedDate,
                    daysInPantry: record.daysInPantry,
                    dateAdded: Calendar.current.date(
                        byAdding: .day,
                        value: -record.daysInPantry,
                        to: record.consumedDate
                    ) ?? record.consumedDate
                )
            }
        } catch {
            logger.error("Failed to fetch consumption records: \(error.localizedDescription)")
            return []
        }
    }
}

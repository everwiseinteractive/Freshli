import Foundation
import SwiftUI

// MARK: - Shelf-Life AI Service
// Dynamic expiry adjustment based on storage method and ambient conditions.
// Beats static "best before" dates by predicting real shelf life.

// MARK: - Models

struct ShelfLifeSuggestion {
    let bestStorageLocation: StorageLocation
    let alternativeLocation: StorageLocation?
    let defaultDays: Int
    let optimisedDays: Int
    var extraDays: Int { max(0, optimisedDays - defaultDays) }
    let reasoning: String
    let warning: String?
}

struct StorageAdjustment {
    let originalExpiry: Date
    let adjustedExpiry: Date
    let daysDelta: Int        // positive = extended, negative = shortened
    let reason: String
}

// MARK: - Service

@MainActor
final class ShelfLifeAIService {
    static let shared = ShelfLifeAIService()
    private init() {}

    // MARK: - Storage Suggestion

    /// Recommend the best storage location for a given item, with projected shelf life.
    func suggest(name: String, category: FoodCategory) -> ShelfLifeSuggestion {
        let l = name.lowercased()

        // Specific items override category defaults
        if l.contains("tomato") {
            return ShelfLifeSuggestion(
                bestStorageLocation: .counter,
                alternativeLocation: .fridge,
                defaultDays: 5,
                optimisedDays: 8,
                reasoning: "Tomatoes ripen best at room temperature — cold ruins flavour and texture.",
                warning: "Only move to fridge once fully ripe to slow spoilage."
            )
        }
        if l.contains("bread") || l.contains("loaf") {
            return ShelfLifeSuggestion(
                bestStorageLocation: .freezer,
                alternativeLocation: .pantry,
                defaultDays: 5,
                optimisedDays: 60,
                reasoning: "Sliced bread lasts 12× longer in the freezer than a bread bin. Toast directly from frozen.",
                warning: "Avoid the fridge — it actually speeds up staling."
            )
        }
        if l.contains("banana") || l.contains("avocado") {
            return ShelfLifeSuggestion(
                bestStorageLocation: .counter,
                alternativeLocation: .fridge,
                defaultDays: 5,
                optimisedDays: 9,
                reasoning: "Ripen on the counter, then move to the fridge once perfect to halt over-ripening.",
                warning: "Keep away from ethylene-sensitive produce (leafy greens).")
        }
        if l.contains("potato") || l.contains("onion") || l.contains("garlic") {
            return ShelfLifeSuggestion(
                bestStorageLocation: .pantry,
                alternativeLocation: nil,
                defaultDays: 21,
                optimisedDays: 45,
                reasoning: "Cool, dark, and dry — never refrigerate. Keeps fresh for 6+ weeks.",
                warning: "Never store onions with potatoes — they accelerate each other's spoilage."
            )
        }
        if l.contains("egg") {
            return ShelfLifeSuggestion(
                bestStorageLocation: .fridge,
                alternativeLocation: nil,
                defaultDays: 21,
                optimisedDays: 35,
                reasoning: "Store pointed-end down in the coldest part of the fridge (not the door).",
                warning: nil
            )
        }
        if l.contains("herb") || l.contains("basil") || l.contains("parsley") || l.contains("coriander") {
            return ShelfLifeSuggestion(
                bestStorageLocation: .fridge,
                alternativeLocation: .counter,
                defaultDays: 5,
                optimisedDays: 14,
                reasoning: "Treat herbs like cut flowers: trim stems, stand in water, cover loosely with a bag.",
                warning: "Basil prefers the counter — cold damages the leaves."
            )
        }
        if l.contains("berry") || l.contains("strawberr") || l.contains("blueberr") {
            return ShelfLifeSuggestion(
                bestStorageLocation: .fridge,
                alternativeLocation: .freezer,
                defaultDays: 4,
                optimisedDays: 10,
                reasoning: "Store unwashed, line container with paper towel. Rinse just before eating.",
                warning: "Moisture is the enemy — wet berries spoil within 24 hours."
            )
        }

        // Category defaults
        switch category {
        case .dairy:
            return ShelfLifeSuggestion(
                bestStorageLocation: .fridge, alternativeLocation: .freezer,
                defaultDays: 7, optimisedDays: 14,
                reasoning: "Store on a middle shelf (not the door) at 4°C for best longevity.",
                warning: nil
            )
        case .meat:
            return ShelfLifeSuggestion(
                bestStorageLocation: .freezer, alternativeLocation: .fridge,
                defaultDays: 3, optimisedDays: 90,
                reasoning: "Freezing on purchase day locks in freshness. Thaw in fridge 24h before use.",
                warning: "Never refreeze thawed raw meat."
            )
        case .seafood:
            return ShelfLifeSuggestion(
                bestStorageLocation: .freezer, alternativeLocation: .fridge,
                defaultDays: 2, optimisedDays: 90,
                reasoning: "Fresh fish degrades quickly. Freeze immediately unless eating within 48 hours.",
                warning: "Use airtight wrapping to prevent freezer burn."
            )
        case .fruits:
            return ShelfLifeSuggestion(
                bestStorageLocation: .counter, alternativeLocation: .fridge,
                defaultDays: 6, optimisedDays: 12,
                reasoning: "Most fruit ripens best on the counter. Refrigerate once ripe to pause spoilage.",
                warning: nil
            )
        case .vegetables:
            return ShelfLifeSuggestion(
                bestStorageLocation: .fridge, alternativeLocation: .freezer,
                defaultDays: 7, optimisedDays: 14,
                reasoning: "High-humidity crisper drawer is ideal for most vegetables.",
                warning: nil
            )
        case .bakery:
            return ShelfLifeSuggestion(
                bestStorageLocation: .freezer, alternativeLocation: .pantry,
                defaultDays: 4, optimisedDays: 60,
                reasoning: "Bakery goods freeze brilliantly and reheat to near-fresh.",
                warning: "Never refrigerate bread — it stales 3× faster."
            )
        default:
            return ShelfLifeSuggestion(
                bestStorageLocation: .pantry, alternativeLocation: .fridge,
                defaultDays: 30, optimisedDays: 60,
                reasoning: "Cool, dark, dry storage extends shelf life substantially.",
                warning: nil
            )
        }
    }

    // MARK: - Dynamic Adjustment Based on Weather

    /// Adjust an item's expiry date based on current temperature. In a heatwave,
    /// counter-stored items spoil faster; in cold weather they last longer.
    func adjustedExpiry(for item: FreshliItem, currentTempCelsius: Double) -> StorageAdjustment {
        let original = item.expiryDate
        var daysDelta = 0
        var reason = "No adjustment — conditions are optimal."

        // Only counter-stored items are affected by ambient temperature
        if item.storageLocation == .counter {
            if currentTempCelsius >= 28 {
                daysDelta = -3
                reason = "Heatwave (\(Int(currentTempCelsius))°C) — counter items spoil 3 days faster."
            } else if currentTempCelsius >= 24 {
                daysDelta = -1
                reason = "Warm weather (\(Int(currentTempCelsius))°C) — shelf life reduced by 1 day."
            } else if currentTempCelsius < 5 {
                daysDelta = 2
                reason = "Cold weather — counter items last 2 extra days."
            }
        }

        let adjusted = Calendar.current.date(byAdding: .day, value: daysDelta, to: original) ?? original
        return StorageAdjustment(originalExpiry: original, adjustedExpiry: adjusted, daysDelta: daysDelta, reason: reason)
    }
}

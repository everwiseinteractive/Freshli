import Foundation
@preconcurrency import Vision
import UIKit
import os

// MARK: - Food Identification Result

struct FoodIdentificationResult: Identifiable {
    let id = UUID()
    let identifier: String
    let displayName: String
    let confidence: Double
    let category: FoodCategory
    let storageLocation: StorageLocation
    let estimatedShelfLifeDays: Int
    let defaultUnit: MeasurementUnit
}

// MARK: - Food Identification State

enum FoodIdentificationState {
    case idle
    case capturing
    case analyzing
    case identified([FoodIdentificationResult])
    case error(String)
}

// MARK: - Food Identification Service

@Observable @MainActor
final class FoodIdentificationService {
    private(set) var identificationState: FoodIdentificationState = .idle
    private(set) var results: [FoodIdentificationResult] = []
    private(set) var errorMessage: String?

    private let logger = PSLogger(category: .pantry)

    // MARK: - Public Methods

    /// Identify food from an image using Vision framework's built-in MobileNetV2 classifier.
    /// - Parameter image: UIImage from camera or photo library
    func identifyFood(_ image: UIImage) async {
        await MainActor.run {
            self.identificationState = .analyzing
            self.errorMessage = nil
            self.results = []
        }

        do {
            guard let cgImage = image.cgImage else {
                await setError("Unable to process image")
                return
            }

            // Classify image using Vision's built-in classifier
            let classifications = try await classifyImage(cgImage)
            logger.info("Image classification completed with \(classifications.count) results")

            // Map classifications to food identification results
            let foodResults = mapClassificationsToFood(classifications)
            logger.info("Mapped \(foodResults.count) items to food database")

            await MainActor.run {
                self.results = foodResults
                self.identificationState = .identified(foodResults)
            }
        } catch {
            await setError("Food identification failed: \(error.localizedDescription)")
        }
    }

    /// Convert identified results to FreshliItem objects.
    /// - Parameters:
    ///   - result: The FoodIdentificationResult to convert
    ///   - quantity: Optional quantity override
    /// - Returns: FreshliItem ready to add to inventory
    func convertToFreshliItem(_ result: FoodIdentificationResult, quantity: Double = 1) -> FreshliItem {
        let expiryDate = Calendar.current.date(
            byAdding: .day,
            value: result.estimatedShelfLifeDays,
            to: Date()
        ) ?? Date.distantFuture

        return FreshliItem(
            name: result.displayName,
            category: result.category,
            storageLocation: result.storageLocation,
            quantity: quantity,
            unit: result.defaultUnit,
            expiryDate: expiryDate
        )
    }

    /// Reset the identification state.
    func reset() {
        identificationState = .idle
        results = []
        errorMessage = nil
    }

    // MARK: - Private Methods

    private func setError(_ message: String) async {
        await MainActor.run {
            self.errorMessage = message
            self.identificationState = .error(message)
            self.logger.error(message)
        }
    }

    /// Classify an image using Vision framework's built-in classifier.
    private func classifyImage(_ cgImage: CGImage) async throws -> [(identifier: String, confidence: Double)] {
        let request = VNClassifyImageRequest()

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try requestHandler.perform([request])

                    guard let results = request.results else {
                        continuation.resume(returning: [])
                        return
                    }

                    // Get top 5 results
                    let topResults = results.prefix(5).map { observation in
                        (identifier: observation.identifier, confidence: Double(observation.confidence))
                    }

                    continuation.resume(returning: Array(topResults))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Map Vision classification results to food items using the produce shelf life database.
    private func mapClassificationsToFood(_ classifications: [(identifier: String, confidence: Double)]) -> [FoodIdentificationResult] {
        var results: [FoodIdentificationResult] = []

        for (identifier, confidence) in classifications {
            // Map Vision identifier to friendly food name
            if let friendlyName = mapIdentifierToFoodName(identifier) {
                // Look up in database
                if let produceInfo = ShelfLifeDatabase.lookup(by: friendlyName) {
                    let result = FoodIdentificationResult(
                        identifier: identifier,
                        displayName: friendlyName,
                        confidence: confidence,
                        category: produceInfo.category,
                        storageLocation: produceInfo.defaultStorage,
                        estimatedShelfLifeDays: produceInfo.shelfLifeDays[produceInfo.defaultStorage] ?? 7,
                        defaultUnit: produceInfo.defaultUnit
                    )
                    results.append(result)
                }
            }
        }

        // Sort by confidence descending
        return results.sorted { $0.confidence > $1.confidence }
    }

    /// Map Vision framework classification identifiers to friendly food names.
    /// Handles MobileNetV2 output labels and common variations.
    private func mapIdentifierToFoodName(_ identifier: String) -> String? {
        // MobileNetV2 label mapping dictionary (~100+ entries)
        let labelMapping: [String: String] = [
            // Fruits
            "banana": "banana",
            "apple": "apple",
            "Granny_Smith": "Granny Smith Apple",
            "orange": "orange",
            "lemon": "lemon",
            "lime": "lime",
            "strawberry": "strawberry",
            "blueberry": "blueberry",
            "raspberry": "raspberry",
            "grape": "grape",
            "peach": "peach",
            "pear": "pear",
            "cherry": "cherry",
            "kiwi": "kiwi",
            "mango": "mango",
            "papaya": "papaya",
            "pineapple": "pineapple",
            "watermelon": "watermelon",
            "cantaloupe": "cantaloupe",
            "avocado": "avocado",

            // Vegetables
            "broccoli": "broccoli",
            "cabbage": "cabbage",
            "carrot": "carrot",
            "celery": "celery",
            "corn": "corn",
            "cucumber": "cucumber",
            "eggplant": "eggplant",
            "garlic": "garlic",
            "ginger": "ginger",
            "green_bean": "green bean",
            "green_peas": "green peas",
            "kale": "kale",
            "lettuce": "lettuce",
            "mushroom": "mushroom",
            "onion": "onion",
            "pea": "pea",
            "pepper": "bell pepper",
            "potato": "potato",
            "pumpkin": "pumpkin",
            "radish": "radish",
            "spinach": "spinach",
            "squash": "squash",
            "sweet_potato": "sweet potato",
            "tomato": "tomato",
            "yam": "yam",
            "zucchini": "zucchini",

            // Dairy
            "cheese": "cheese",
            "milk": "milk",
            "yogurt": "yogurt",
            "butter": "butter",

            // Meat
            "beef": "beef",
            "chicken": "chicken",
            "pork": "pork",
            "lamb": "lamb",
            "duck": "duck",
            "turkey": "turkey",
            "sausage": "sausage",
            "bacon": "bacon",
            "ham": "ham",

            // Seafood
            "salmon": "salmon",
            "tuna": "tuna",
            "cod": "cod",
            "shrimp": "shrimp",
            "crab": "crab",
            "lobster": "lobster",
            "clam": "clam",
            "oyster": "oyster",
            "fish": "fish",

            // Grains & Bread
            "bagel": "bagel",
            "bread": "bread",
            "baguette": "baguette",
            "croissant": "croissant",
            "donut": "donut",
            "pancake": "pancake",
            "waffle": "waffle",
            "pretzel": "pretzel",
            "tortilla": "tortilla",

            // Baked Goods
            "cake": "cake",
            "cookie": "cookie",
            "cupcake": "cupcake",
            "muffin": "muffin",
            "pastry": "pastry",

            // Beverages
            "beer": "beer",
            "coffee": "coffee",
            "juice": "juice",
            "soda": "soda",
            "tea": "tea",
            "wine": "wine",

            // Condiments & Sauces
            "ketchup": "ketchup",
            "mustard": "mustard",
            "mayonnaise": "mayonnaise",
            "hot_sauce": "hot sauce",
            "bbq_sauce": "BBQ sauce",
            "soy_sauce": "soy sauce",
            "vinegar": "vinegar",
            "honey": "honey",
            "jam": "jam",
            "peanut_butter": "peanut butter",

            // Snacks & Desserts
            "chip": "chips",
            "chocolate": "chocolate",
            "cracker": "cracker",
            "ice_cream": "ice cream",
            "popcorn": "popcorn",
            "candy": "candy",
            "nut": "nut",
            "granola": "granola",

            // Eggs & Proteins
            "egg": "egg",
            "tofu": "tofu",

            // Frozen Foods
            "french_fries": "french fries",
            "pizza": "pizza",

            // Pasta & Grains
            "pasta": "pasta",
            "rice": "rice",
            "oatmeal": "oatmeal",
            "cereal": "cereal",

            // Canned Foods (generic)
            "canned_beans": "canned beans",
            "canned_soup": "canned soup",
            "canned_vegetable": "canned vegetables",
            "canned_fruit": "canned fruit",
        ]

        // Clean identifier (lowercase, replace underscores with spaces)
        let cleanIdentifier = identifier
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")

        // Check exact match first
        if let mapped = labelMapping[identifier.lowercased()] {
            return mapped
        }

        // Check cleaned identifier
        if let mapped = labelMapping[cleanIdentifier] {
            return mapped
        }

        // Try partial matching for common variations
        for (key, value) in labelMapping {
            if cleanIdentifier.contains(key) || key.contains(cleanIdentifier) {
                return value
            }
        }

        // Default: return identifier as-is if not found
        return identifier.replacingOccurrences(of: "_", with: " ")
    }
}

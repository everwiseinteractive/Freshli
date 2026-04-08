import Foundation
import Vision
import UIKit
import os

// MARK: - Scanned Item Model

struct ParsedReceiptItem: Identifiable {
    let id = UUID()
    var name: String
    var quantity: Double
    var unit: MeasurementUnit
    var category: FoodCategory
    var estimatedExpiry: Date
    var storageLocation: StorageLocation
    var confidenceScore: Double
}

// MARK: - Receipt Scanner State

enum ReceiptScanningState {
    case idle
    case scanning
    case parsing
    case complete
    case error(String)
}

// MARK: - Receipt Scanner Service

@Observable
final class ReceiptScannerService {
    private(set) var scanningState: ReceiptScanningState = .idle
    private(set) var scannedItems: [ParsedReceiptItem] = []
    private(set) var errorMessage: String?

    private let logger = PSLogger(category: .pantry)

    // MARK: - Public Methods

    /// Scan a receipt image and extract grocery items.
    /// - Parameter image: UIImage from camera or photo library
    func scanReceipt(_ image: UIImage) async {
        await MainActor.run {
            self.scanningState = .scanning
            self.errorMessage = nil
            self.scannedItems = []
        }

        do {
            guard let cgImage = image.cgImage else {
                await setError("Unable to process image")
                return
            }

            // Perform OCR using Vision framework
            let recognizedText = try await performOCR(cgImage)
            logger.info("OCR completed, recognized \(recognizedText.count) text lines")

            await MainActor.run {
                self.scanningState = .parsing
            }

            // Parse text and extract items
            let items = parseReceiptText(recognizedText)
            logger.info("Parsed \(items.count) items from receipt")

            await MainActor.run {
                self.scannedItems = items
                self.scanningState = .complete
            }
        } catch {
            await setError("Scanning failed: \(error.localizedDescription)")
        }
    }

    /// Convert scanned items to PantryItem objects.
    /// - Returns: Array of PantryItem ready to add to inventory
    func convertToPantryItems() -> [PantryItem] {
        scannedItems.map { scannedItem in
            PantryItem(
                name: scannedItem.name,
                category: scannedItem.category,
                storageLocation: scannedItem.storageLocation,
                quantity: scannedItem.quantity,
                unit: scannedItem.unit,
                expiryDate: scannedItem.estimatedExpiry
            )
        }
    }

    /// Reset the scanner state.
    func reset() {
        scanningState = .idle
        scannedItems = []
        errorMessage = nil
    }

    // MARK: - Private Methods

    private func setError(_ message: String) async {
        await MainActor.run {
            self.errorMessage = message
            self.scanningState = .error(message)
            self.logger.error(message)
        }
    }

    /// Perform OCR on the image using Vision framework.
    private func performOCR(_ cgImage: CGImage) async throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try requestHandler.perform([request])

                    guard let results = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: [])
                        return
                    }

                    let recognizedStrings = results.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }

                    continuation.resume(returning: recognizedStrings)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Parse receipt text and extract grocery items.
    private func parseReceiptText(_ lines: [String]) -> [ParsedReceiptItem] {
        var items: [ParsedReceiptItem] = []
        let cleanedLines = filterNonFoodLines(lines)

        for line in cleanedLines {
            if let item = extractItemFromLine(line) {
                items.append(item)
            }
        }

        return items
    }

    /// Filter out non-food lines (store info, totals, tax, payment, dates, barcodes, etc.)
    private func filterNonFoodLines(_ lines: [String]) -> [String] {
        let storePatterns = [
            "store", "supermarket", "market", "grocery", "shop", "walmart", "target", "costco", "whole foods", "trader joe",
            "kroger", "safeway", "publix", "wegmans", "albertsons", "waitrose", "tesco", "sainsbury", "asda", "morrisons"
        ]

        let nonFoodPatterns = [
            "^[0-9]{8,}$",              // Barcodes
            "^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4}",  // Dates
            "^[0-9]{1,2}:[0-9]{2}",    // Times
            "total", "subtotal", "tax", "change", "payment", "cash", "card", "credit",
            "phone", "contact", "address", "street", "avenue", "road", "drive",
            "thank you", "thanks", "welcome", "have a nice day", "return",
            "quantity", "qty", "item", "price", "upc", "sku", "id",
            "customer", "receipt", "invoice", "order", "transaction"
        ]

        return lines.filter { line in
            let lowercaseLine = line.lowercased().trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if lowercaseLine.isEmpty { return false }

            // Skip store names
            if storePatterns.contains(where: { lowercaseLine.contains($0) }) { return false }

            // Skip non-food patterns
            for pattern in nonFoodPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let range = NSRange(lowercaseLine.startIndex..<lowercaseLine.endIndex, in: lowercaseLine)
                    if regex.firstMatch(in: lowercaseLine, range: range) != nil {
                        return false
                    }
                }
            }

            // Skip lines that are only numbers/prices
            let numberOnlyPattern = "^[\\d.,\\s$£€¥]*$"
            if let regex = try? NSRegularExpression(pattern: numberOnlyPattern) {
                let range = NSRange(lowercaseLine.startIndex..<lowercaseLine.endIndex, in: lowercaseLine)
                if regex.firstMatch(in: lowercaseLine, range: range) != nil {
                    return false
                }
            }

            return true
        }
    }

    /// Extract an item from a receipt line.
    private func extractItemFromLine(_ line: String) -> ParsedReceiptItem? {
        var cleanedName = line.trimmingCharacters(in: .whitespaces)

        // Remove quantity prefixes (e.g., "2x Milk" -> "Milk")
        let quantityPattern = "^([0-9]+\\.?[0-9]*)\\s*[xX×]\\s*"
        if let regex = try? NSRegularExpression(pattern: quantityPattern) {
            let range = NSRange(cleanedName.startIndex..<cleanedName.endIndex, in: cleanedName)
            cleanedName = regex.stringByReplacingMatches(in: cleanedName, range: range, withTemplate: "")
        }

        // Remove trailing prices/codes (common receipt format: "Item Name 4.99" or "Item Name #SKU")
        cleanedName = removePricingInfo(cleanedName)

        // Extract quantity if present
        let quantity = extractQuantity(line)
        let unit = estimateUnit(cleanedName)

        guard !cleanedName.isEmpty && cleanedName.count > 1 else { return nil }

        // Auto-categorize
        let category = categorizeItem(cleanedName)

        // Estimate expiry date based on category
        let expiryDate = estimateExpiryDate(for: category)

        // Assign storage location based on category
        let storageLocation = assignStorageLocation(for: category)

        // Estimate confidence score (0-1) based on line length and content
        let confidence = estimateConfidence(for: cleanedName, quantity: quantity)

        return ParsedReceiptItem(
            name: cleanedName,
            quantity: quantity,
            unit: unit,
            category: category,
            estimatedExpiry: expiryDate,
            storageLocation: storageLocation,
            confidenceScore: confidence
        )
    }

    /// Remove pricing and product codes from item name.
    private func removePricingInfo(_ line: String) -> String {
        var result = line

        // Remove trailing prices (e.g., "Milk 3.99" -> "Milk")
        let pricePattern = "\\s*[\\$£€¥]?\\s*[0-9]+\\.[0-9]{2}\\s*$"
        if let regex = try? NSRegularExpression(pattern: pricePattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Remove product codes (e.g., "#123456" or "SKU: 123")
        let codePattern = "\\s*[#]?[0-9]{5,}\\s*$|SKU:?\\s*[0-9]+\\s*$"
        if let regex = try? NSRegularExpression(pattern: codePattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Extract quantity from a receipt line.
    private func extractQuantity(_ line: String) -> Double {
        let patterns = [
            "^([0-9]+\\.?[0-9]*)\\s*[xX×]",  // "2x Item"
            "qty:?\\s*([0-9]+\\.?[0-9]*)",    // "qty: 2"
            "\\(([0-9]+\\.?[0-9]*)\\)",       // "(2)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                if let match = regex.firstMatch(in: line, range: range),
                   let quantityRange = Range(match.range(at: 1), in: line),
                   let quantity = Double(String(line[quantityRange])) {
                    return max(quantity, 1.0)
                }
            }
        }

        return 1.0
    }

    /// Estimate measurement unit based on item name and common keywords.
    private func estimateUnit(_ itemName: String) -> MeasurementUnit {
        let lowercased = itemName.lowercased()

        // Liquid keywords
        if lowercased.contains("milk") || lowercased.contains("juice") || lowercased.contains("water") ||
           lowercased.contains("beverage") || lowercased.contains("oil") || lowercased.contains("sauce") {
            return .milliliters
        }

        // Solid keywords suggesting weight
        if lowercased.contains("butter") || lowercased.contains("cheese") || lowercased.contains("flour") ||
           lowercased.contains("sugar") || lowercased.contains("salt") {
            return .grams
        }

        // Container keywords
        if lowercased.contains("bottle") || lowercased.contains("can") || lowercased.contains("jar") {
            return .cans
        }

        if lowercased.contains("pack") || lowercased.contains("box") || lowercased.contains("bag") {
            return .packs
        }

        // Default to pieces for items like fruits, vegetables
        return .pieces
    }

    /// Auto-categorize items using keyword matching.
    private func categorizeItem(_ itemName: String) -> FoodCategory {
        let lowercased = itemName.lowercased()

        let categoryKeywords: [(FoodCategory, [String])] = [
            (.fruits, ["apple", "banana", "orange", "grape", "berry", "mango", "pineapple", "strawberry", "blueberry", "peach", "pear", "watermelon", "melon", "lemon", "lime"]),
            (.vegetables, ["carrot", "broccoli", "spinach", "lettuce", "tomato", "cucumber", "pepper", "onion", "garlic", "potato", "celery", "kale", "zucchini", "squash", "bean", "pea"]),
            (.dairy, ["milk", "cheese", "yogurt", "butter", "cream", "ice cream", "whipped cream", "sour cream"]),
            (.meat, ["beef", "chicken", "pork", "lamb", "steak", "burger", "sausage", "bacon", "ham", "turkey", "duck"]),
            (.seafood, ["fish", "salmon", "tuna", "shrimp", "crab", "lobster", "cod", "tilapia", "halibut", "anchovy"]),
            (.grains, ["bread", "rice", "pasta", "cereal", "oat", "barley", "quinoa", "wheat", "flour", "cornmeal"]),
            (.bakery, ["bread", "bagel", "muffin", "donut", "croissant", "cake", "cookie", "biscuit", "pastry"]),
            (.frozen, ["frozen", "ice", "freezer"]),
            (.canned, ["canned", "can", "tin", "conserve"]),
            (.condiments, ["sauce", "ketchup", "mustard", "mayo", "mayonnaise", "vinegar", "oil", "spice", "salt", "pepper", "seasoning"]),
            (.snacks, ["chip", "cracker", "popcorn", "candy", "chocolate", "nut", "granola", "bar", "pretzel"]),
            (.beverages, ["juice", "soda", "coffee", "tea", "wine", "beer", "water", "drink", "smoothie", "lemonade"])
        ]

        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { lowercased.contains($0) }) {
                return category
            }
        }

        return .other
    }

    /// Estimate expiry date based on category.
    private func estimateExpiryDate(for category: FoodCategory) -> Date {
        let days: Int

        switch category {
        case .fruits:
            days = 5
        case .vegetables:
            days = 7
        case .dairy:
            days = 10
        case .meat:
            days = 3
        case .seafood:
            days = 2
        case .grains:
            days = 90
        case .bakery:
            days = 5
        case .frozen:
            days = 180
        case .canned:
            days = 365
        case .condiments:
            days = 180
        case .snacks:
            days = 60
        case .beverages:
            days = 30
        case .other:
            days = 14
        }

        return Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date.distantFuture
    }

    /// Assign storage location based on category.
    private func assignStorageLocation(for category: FoodCategory) -> StorageLocation {
        switch category {
        case .dairy, .meat, .seafood, .beverages:
            return .fridge
        case .frozen:
            return .freezer
        case .canned, .grains, .condiments, .snacks, .other:
            return .pantry
        case .fruits, .vegetables, .bakery:
            return .counter
        }
    }

    /// Estimate confidence score based on item characteristics.
    private func estimateConfidence(for itemName: String, quantity: Double) -> Double {
        var confidence: Double = 0.8

        // Reduce confidence for very short names
        if itemName.count < 3 {
            confidence -= 0.2
        }

        // Increase confidence for longer, more detailed names
        if itemName.count > 15 {
            confidence += 0.1
        }

        // Adjust for unusual quantities
        if quantity > 10 {
            confidence -= 0.05
        }

        return max(0.0, min(1.0, confidence))
    }
}

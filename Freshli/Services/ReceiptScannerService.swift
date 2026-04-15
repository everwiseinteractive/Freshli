import Foundation
@preconcurrency import Vision
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

@Observable @MainActor
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

    /// Convert scanned items to FreshliItem objects.
    /// - Returns: Array of FreshliItem ready to add to inventory
    func convertToFreshliItems() -> [FreshliItem] {
        scannedItems.map { scannedItem in
            FreshliItem(
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

                    guard let results = request.results else {
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
            "kroger", "safeway", "publix", "wegmans", "albertsons", "waitrose", "tesco", "sainsbury", "asda", "morrisons",
            "dillons", "harris teeter", "king kullen", "winco", "sprouts"
        ]

        let nonFoodPatterns = [
            "^[0-9]{8,}$",              // Barcodes
            "^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4}",  // Dates
            "^[0-9]{1,2}:[0-9]{2}",    // Times
            "total", "subtotal", "sub total", "tax", "sales tax", "change", "payment", "cash", "card", "credit",
            "phone", "contact", "address", "street", "avenue", "road", "drive", "city", "state", "zip",
            "thank you", "thanks", "welcome", "have a nice day", "return", "returns",
            "quantity", "qty", "item", "price", "upc", "sku", "id", "bar code",
            "customer", "receipt", "invoice", "order", "transaction", "register",
            "department", "visa", "mastercard", "amex", "debit", "tender"
        ]

        return lines.filter { line in
            let lowercaseLine = line.lowercased().trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if lowercaseLine.isEmpty { return false }

            // Skip lines that are too short to be real items
            if lowercaseLine.count < 2 { return false }

            // Skip store names
            if storePatterns.contains(where: { lowercaseLine.contains($0) }) { return false }

            // Skip non-food patterns
            for pattern in nonFoodPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
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
        let originalLine = cleanedName

        // Remove quantity prefixes (e.g., "2x Milk" -> "Milk")
        let quantityPattern = "^([0-9]+\\.?[0-9]*)\\s*[xX×]\\s*"
        if let regex = try? NSRegularExpression(pattern: quantityPattern) {
            let range = NSRange(cleanedName.startIndex..<cleanedName.endIndex, in: cleanedName)
            cleanedName = regex.stringByReplacingMatches(in: cleanedName, range: range, withTemplate: "")
        }

        // Remove trailing prices/codes (common receipt format: "Item Name 4.99" or "Item Name #SKU")
        cleanedName = removePricingInfo(cleanedName)

        // Additional cleanup: Remove excessive whitespace and normalize
        cleanedName = cleanedName.split(separator: " ").map(String.init).joined(separator: " ")

        // Extract quantity if present
        let quantity = extractQuantity(originalLine)
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
        // Matches: $3.99, 3.99, £3.99, €3.99, 3.99€, etc.
        let pricePattern = "\\s+[\\$£€¥]?\\s*[0-9]+[.,][0-9]{2}[\\$£€¥]?\\s*$"
        if let regex = try? NSRegularExpression(pattern: pricePattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Remove product codes (e.g., "#123456" or "SKU: 123" at the end)
        let codePattern = "\\s+[#]?[0-9]{5,}\\s*$"
        if let regex = try? NSRegularExpression(pattern: codePattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Remove SKU patterns
        let skuPattern = "\\s+(?:SKU|UPC|ITEM|ID):?\\s*[0-9A-Z]+\\s*$"
        if let regex = try? NSRegularExpression(pattern: skuPattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Remove multiple spaces between item name and trailing info
        result = result.split(separator: " ").map(String.init).joined(separator: " ")

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
           lowercased.contains("beverage") || lowercased.contains("oil") || lowercased.contains("sauce") ||
           lowercased.contains("soda") || lowercased.contains("tea") || lowercased.contains("coffee") ||
           lowercased.contains("wine") || lowercased.contains("beer") || lowercased.contains("soy") {
            return .milliliters
        }

        // Solid keywords suggesting weight
        if lowercased.contains("butter") || lowercased.contains("cheese") || lowercased.contains("flour") ||
           lowercased.contains("sugar") || lowercased.contains("salt") || lowercased.contains("spice") ||
           lowercased.contains("coffee") || lowercased.contains("cocoa") {
            return .grams
        }

        // Container/packaged keywords
        if lowercased.contains("bottle") {
            return .bottles
        }

        if lowercased.contains("can") || lowercased.contains("tin") {
            return .cans
        }

        if lowercased.contains("pack") || lowercased.contains("box") {
            return .packs
        }

        if lowercased.contains("bag") {
            return .bags
        }

        // Weight-based for meats/produce sold by pound
        if lowercased.contains("beef") || lowercased.contains("chicken") || lowercased.contains("pork") ||
           lowercased.contains("lamb") || lowercased.contains("steak") || lowercased.contains("salmon") ||
           lowercased.contains("ground") {
            return .pounds
        }

        // Default to pieces for items like fruits, vegetables
        return .pieces
    }

    /// Auto-categorize items using keyword matching.
    private func categorizeItem(_ itemName: String) -> FoodCategory {
        let lowercased = itemName.lowercased()

        let categoryKeywords: [(FoodCategory, [String])] = [
            (.fruits, ["apple", "apples", "banana", "bananas", "orange", "oranges", "grape", "grapes", "berry", "berries",
                       "mango", "pineapple", "strawberry", "strawberries", "blueberry", "blueberries", "peach", "pear",
                       "watermelon", "melon", "cantaloupe", "lemon", "limes", "lime", "tangerine", "clementine", "avocado"]),
            (.vegetables, ["carrot", "carrots", "broccoli", "spinach", "lettuce", "tomato", "tomatoes", "cucumber", "bell pepper",
                          "onion", "onions", "garlic", "potato", "potatoes", "celery", "kale", "zucchini", "squash", "bean",
                          "beans", "pea", "peas", "cauliflower", "cabbage", "asparagus", "green beans", "brussels sprouts"]),
            (.dairy, ["milk", "cheese", "yogurt", "yoghurt", "butter", "cream", "ice cream", "whipped cream", "sour cream",
                     "cottage cheese", "mozzarella", "cheddar", "feta", "parmesan", "ricotta"]),
            (.meat, ["beef", "chicken", "pork", "lamb", "steak", "burger", "sausage", "bacon", "ham", "turkey", "duck",
                    "ground beef", "ground turkey", "ground pork", "ribeye", "sirloin", "chuck", "brisket"]),
            (.seafood, ["fish", "salmon", "tuna", "shrimp", "crab", "lobster", "cod", "tilapia", "halibut", "anchovy",
                       "mussels", "clams", "scallops", "oysters", "calamari"]),
            (.grains, ["bread", "rice", "pasta", "cereal", "oat", "oats", "barley", "quinoa", "wheat", "flour", "cornmeal",
                      "whole wheat", "white rice", "brown rice", "jasmine rice"]),
            (.bakery, ["bagel", "bagels", "muffin", "muffins", "donut", "donuts", "doughnut", "croissant", "cake", "cookie",
                      "cookies", "biscuit", "biscuits", "pastry", "pastries", "crescent", "croissants"]),
            (.frozen, ["frozen", "ice", "freezer", "frozen vegetables", "frozen pizza", "ice cream", "popsicle"]),
            (.canned, ["canned", "can", "tin", "conserve", "canned vegetables", "canned beans", "canned soup"]),
            (.condiments, ["sauce", "ketchup", "mustard", "mayo", "mayonnaise", "vinegar", "oil", "spice", "salt", "pepper",
                          "seasoning", "dressing", "soy sauce", "worcestershire", "hot sauce", "pesto", "salsa"]),
            (.snacks, ["chip", "chips", "cracker", "crackers", "popcorn", "candy", "chocolate", "nut", "nuts", "granola",
                      "bar", "bars", "pretzel", "pretzels", "cookie", "cookies", "crackers", "trail mix"]),
            (.beverages, ["juice", "soda", "coffee", "tea", "wine", "beer", "water", "drink", "smoothie", "lemonade",
                         "orange juice", "apple juice", "cranberry juice", "cola", "sprite", "coconut water", "almond milk"])
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
        var confidence: Double = 0.75

        // Length-based adjustments
        if itemName.count < 3 {
            confidence -= 0.2
        } else if itemName.count > 20 {
            confidence += 0.15
        }

        // Word count heuristic (more words = more detail = higher confidence)
        let wordCount = itemName.split(separator: " ").count
        if wordCount >= 2 {
            confidence += Double(min(wordCount - 1, 2)) * 0.05
        }

        // Quantity adjustments
        if quantity <= 0 || quantity > 20 {
            confidence -= 0.1
        } else if quantity > 5 {
            confidence -= 0.05
        }

        // Check for common item keywords (higher confidence if recognized)
        let knownKeywords = [
            "milk", "cheese", "yogurt", "butter", "bread", "apple", "banana", "chicken",
            "beef", "pork", "rice", "pasta", "oil", "eggs", "tomato", "lettuce",
            "water", "juice", "coffee", "tea", "chips", "cookie", "yogurt", "yoghurt"
        ]

        let lowerName = itemName.lowercased()
        if knownKeywords.contains(where: { lowerName.contains($0) }) {
            confidence += 0.1
        }

        return max(0.0, min(1.0, confidence))
    }
}

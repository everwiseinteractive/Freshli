import Foundation
import Observation
import SwiftData

// MARK: - Models

struct ReceiptItem: Identifiable {
    let id: UUID = UUID()
    var name: String
    var quantity: Double
    var unit: String
    var price: Double?
    var category: String
}

struct GroceryReceipt: Identifiable, Codable {
    let id: UUID
    let storeName: String
    let date: Date
    var items: [CodableReceiptItem]
    let totalAmount: Double
    let receiptSource: String

    struct CodableReceiptItem: Codable {
        let name: String
        let quantity: Double
        let unit: String
        let price: Double?
        let category: String
    }

    init(id: UUID, storeName: String, date: Date, items: [ReceiptItem], totalAmount: Double, receiptSource: ReceiptSource) {
        self.id = id
        self.storeName = storeName
        self.date = date
        self.items = items.map { CodableReceiptItem(name: $0.name, quantity: $0.quantity, unit: $0.unit, price: $0.price, category: $0.category) }
        self.totalAmount = totalAmount
        self.receiptSource = receiptSource.rawValue
    }
}

enum ReceiptSource: String, Codable {
    case manual
    case photoScan
    case instacartDigital
    case ocadoDigital
    case krogerDigital
    case amazonFresh
}

// MARK: - Service

@Observable
final class ReceiptImportService {
    var recentReceipts: [GroceryReceipt] = []
    var importHistory: [GroceryReceipt] = []
    var connectedServices: [ConnectedService] = []

    private let userDefaults = UserDefaults.standard
    private let receiptsKey = "com.freshli.recentReceipts"
    private let historyKey = "com.freshli.importHistory"
    private let connectedServicesKey = "com.freshli.connectedServices"

    // MARK: - Item to Category Mapping

    private let itemToCategoryMap: [String: String] = [
        "apple": "fruits", "banana": "fruits", "orange": "fruits", "grape": "fruits", "strawberry": "fruits",
        "blueberry": "fruits", "watermelon": "fruits", "mango": "fruits",
        "carrot": "vegetables", "broccoli": "vegetables", "spinach": "vegetables", "lettuce": "vegetables",
        "tomato": "vegetables", "cucumber": "vegetables", "bell pepper": "vegetables", "onion": "vegetables",
        "milk": "dairy", "cheese": "dairy", "yogurt": "dairy", "butter": "dairy", "cream": "dairy",
        "chicken": "meat", "beef": "meat", "pork": "meat", "turkey": "meat", "lamb": "meat",
        "salmon": "seafood", "tuna": "seafood", "shrimp": "seafood", "cod": "seafood",
        "bread": "bakery", "bagel": "bakery", "croissant": "bakery", "muffin": "bakery", "donut": "bakery",
        "rice": "grains", "pasta": "grains", "cereal": "grains", "oats": "grains", "flour": "grains",
        "frozen pizza": "frozen", "frozen vegetables": "frozen", "ice cream": "frozen",
        "beans": "canned", "soup": "canned", "tuna can": "canned", "corn": "canned",
        "ketchup": "condiments", "mustard": "condiments", "mayo": "condiments", "oil": "condiments",
        "chips": "snacks", "cookies": "snacks", "crackers": "snacks", "popcorn": "snacks",
        "juice": "beverages", "soda": "beverages", "water": "beverages", "coffee": "beverages", "tea": "beverages"
    ]

    init() {
        loadFromUserDefaults()
    }

    // MARK: - Public Methods

    func parseReceiptFromText(_ text: String) -> GroceryReceipt {
        let lines = text.split(separator: "\n").map(String.init)
        var items: [ReceiptItem] = []
        var storeName = "Manual Receipt"
        var totalAmount: Double = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Basic parsing: look for patterns like "Item Name   1   $5.99"
            let components = trimmed.split(separator: "\t").map(String.init)
            if components.count >= 2 {
                let itemName = components[0]
                let quantity = Double(components[1].filter { $0.isNumber || $0 == "." }) ?? 1.0
                let price = components.count > 2 ? Double(components[2].filter { $0.isNumber || $0 == "." }) : nil

                let category = detectCategory(for: itemName)
                items.append(ReceiptItem(name: itemName, quantity: quantity, unit: "pieces", price: price, category: category))

                if let price { totalAmount += price }
            }
        }

        return GroceryReceipt(
            id: UUID(),
            storeName: storeName,
            date: Date(),
            items: items,
            totalAmount: totalAmount,
            receiptSource: .manual
        )
    }

    func importFromPhoto() {
        // Stub for Vision OCR integration
        // TODO: Integrate VNRecognizeTextRequest from Vision framework
        // let request = VNRecognizeTextRequest()
        // request.recognitionLevel = .accurate
        // let handler = VNImageRequestHandler(cgImage: image, options: [:])
        // try? handler.perform([request])
    }

    func convertToFreshliItems(_ receipt: GroceryReceipt) -> [FreshliItemData] {
        return receipt.items.map { receiptItem in
            let expiryDate = estimateExpiryDate(for: receiptItem.category)
            let category = FoodCategory(rawValue: receiptItem.category) ?? .other
            let unit = MeasurementUnit(rawValue: receiptItem.unit) ?? .pieces

            return FreshliItemData(
                name: receiptItem.name,
                category: category,
                unit: unit,
                quantity: receiptItem.quantity,
                expiryDate: expiryDate,
                source: "Receipt from \(receipt.storeName)"
            )
        }
    }

    func estimateExpiryDate(for category: String) -> Date {
        let calendar = Calendar.current
        let daysToAdd: Int

        switch category.lowercased() {
        case "fruits", "vegetables":
            daysToAdd = Int.random(in: 3...7)
        case "dairy":
            daysToAdd = Int.random(in: 7...14)
        case "meat", "seafood":
            daysToAdd = Int.random(in: 1...3)
        case "bakery":
            daysToAdd = Int.random(in: 2...5)
        case "frozen":
            daysToAdd = 365
        case "pantrystaple", "grains", "canned", "condiments":
            daysToAdd = Int.random(in: 90...365)
        case "beverages", "snacks":
            daysToAdd = Int.random(in: 30...90)
        default:
            daysToAdd = Int.random(in: 7...30)
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: Date()) ?? Date()
    }

    func addReceipt(_ receipt: GroceryReceipt) {
        recentReceipts.insert(receipt, at: 0)
        importHistory.insert(receipt, at: 0)

        if recentReceipts.count > 10 {
            recentReceipts.removeLast()
        }

        saveToUserDefaults()
    }

    func deleteReceipt(_ receipt: GroceryReceipt) {
        recentReceipts.removeAll { $0.id == receipt.id }
        importHistory.removeAll { $0.id == receipt.id }
        saveToUserDefaults()
    }

    func connectService(_ service: ReceiptSource) {
        let connectedService = ConnectedService(source: service.rawValue, isConnected: true, lastSyncDate: Date())
        if let index = connectedServices.firstIndex(where: { $0.source == service.rawValue }) {
            connectedServices[index] = connectedService
        } else {
            connectedServices.append(connectedService)
        }
        saveToUserDefaults()
    }

    func disconnectService(_ service: ReceiptSource) {
        connectedServices.removeAll { $0.source == service.rawValue }
        saveToUserDefaults()
    }

    // MARK: - Private Methods

    private func detectCategory(for itemName: String) -> String {
        let lowercased = itemName.lowercased()
        for (keyword, category) in itemToCategoryMap {
            if lowercased.contains(keyword) {
                return category
            }
        }
        return "other"
    }

    private func loadFromUserDefaults() {
        if let data = userDefaults.data(forKey: receiptsKey),
           let decoded = try? JSONDecoder().decode([GroceryReceipt].self, from: data) {
            recentReceipts = decoded
        }

        if let data = userDefaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([GroceryReceipt].self, from: data) {
            importHistory = decoded
        }

        if let data = userDefaults.data(forKey: connectedServicesKey),
           let decoded = try? JSONDecoder().decode([ConnectedService].self, from: data) {
            connectedServices = decoded
        }
    }

    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(recentReceipts) {
            userDefaults.set(encoded, forKey: receiptsKey)
        }
        if let encoded = try? JSONEncoder().encode(importHistory) {
            userDefaults.set(encoded, forKey: historyKey)
        }
        if let encoded = try? JSONEncoder().encode(connectedServices) {
            userDefaults.set(encoded, forKey: connectedServicesKey)
        }
    }
}

// MARK: - Connected Service Model

struct ConnectedService: Identifiable, Codable {
    let id: UUID = UUID()
    let source: String
    var isConnected: Bool
    var lastSyncDate: Date?

    enum CodingKeys: String, CodingKey {
        case source, isConnected, lastSyncDate
    }

    init(source: String, isConnected: Bool, lastSyncDate: Date?) {
        self.source = source
        self.isConnected = isConnected
        self.lastSyncDate = lastSyncDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(isConnected, forKey: .isConnected)
        try container.encode(lastSyncDate, forKey: .lastSyncDate)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(String.self, forKey: .source)
        isConnected = try container.decode(Bool.self, forKey: .isConnected)
        lastSyncDate = try container.decodeIfPresent(Date.self, forKey: .lastSyncDate)
    }
}

// MARK: - Freshli Item Data

struct FreshliItemData {
    let name: String
    let category: FoodCategory
    let unit: MeasurementUnit
    let quantity: Double
    let expiryDate: Date
    let source: String?
}

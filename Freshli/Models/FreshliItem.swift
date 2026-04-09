import Foundation
import SwiftData

@Model
final class FreshliItem {
    var id: UUID
    var name: String
    var categoryRaw: String
    var storageLocationRaw: String
    var quantity: Double
    var unitRaw: String
    var expiryDate: Date
    var dateAdded: Date
    var barcode: String?
    var notes: String?
    var isShared: Bool
    var isDonated: Bool
    var isConsumed: Bool

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var storageLocation: StorageLocation {
        get { StorageLocation(rawValue: storageLocationRaw) ?? .pantry }
        set { storageLocationRaw = newValue.rawValue }
    }

    var unit: MeasurementUnit {
        get { MeasurementUnit(rawValue: unitRaw) ?? .pieces }
        set { unitRaw = newValue.rawValue }
    }

    var expiryStatus: ExpiryStatus {
        ExpiryStatus.from(expiryDate: expiryDate)
    }

    var quantityDisplay: String {
        let formatted = quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", quantity)
            : String(format: "%.1f", quantity)
        return "\(formatted) \(unit.displayName)"
    }

    var isActive: Bool {
        !isConsumed && !isShared && !isDonated
    }

    init(
        name: String,
        category: FoodCategory,
        storageLocation: StorageLocation,
        quantity: Double,
        unit: MeasurementUnit,
        expiryDate: Date,
        barcode: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.storageLocationRaw = storageLocation.rawValue
        self.quantity = quantity
        self.unitRaw = unit.rawValue
        self.expiryDate = expiryDate
        self.dateAdded = Date()
        self.barcode = barcode
        self.notes = notes
        self.isShared = false
        self.isDonated = false
        self.isConsumed = false
    }
}

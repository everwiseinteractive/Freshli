import Foundation
import SwiftData

enum ListingType: String, Codable, CaseIterable, Identifiable {
    case share
    case donate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .share: return String(localized: "Share")
        case .donate: return String(localized: "Donate")
        }
    }
}

enum ListingStatus: String, Codable {
    case active
    case claimed
    case completed
    case expired
}

@Model
final class SharedListing {
    var id: UUID
    var itemName: String
    var itemDescription: String
    var quantity: String
    var listingTypeRaw: String
    var statusRaw: String
    var pickupAddress: String
    var pickupNotes: String?
    var datePosted: Date
    var expiryDate: Date

    var listingType: ListingType {
        get { ListingType(rawValue: listingTypeRaw) ?? .share }
        set { listingTypeRaw = newValue.rawValue }
    }

    var status: ListingStatus {
        get { ListingStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        itemName: String,
        itemDescription: String,
        quantity: String,
        listingType: ListingType,
        pickupAddress: String,
        pickupNotes: String? = nil,
        expiryDate: Date
    ) {
        self.id = UUID()
        self.itemName = itemName
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.listingTypeRaw = listingType.rawValue
        self.statusRaw = ListingStatus.active.rawValue
        self.pickupAddress = pickupAddress
        self.pickupNotes = pickupNotes
        self.datePosted = Date()
        self.expiryDate = expiryDate
    }
}

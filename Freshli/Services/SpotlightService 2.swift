import Foundation
import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers

// MARK: - SpotlightService
/// Indexes pantry items for Spotlight search

@MainActor
struct SpotlightService {
    
    /// Index a single item
    static func indexItem(_ item: FreshliItem) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = item.name
        attributeSet.contentDescription = "\(item.category.displayName) - \(item.expiryDate.expiryDisplayText)"
        attributeSet.keywords = [
            item.name.lowercased(),
            item.category.displayName.lowercased(),
            item.storageLocation.displayName.lowercased(),
            "freshli",
            "pantry"
        ]
        
        let searchableItem = CSSearchableItem(
            uniqueIdentifier: item.id.uuidString,
            domainIdentifier: "com.freshli.pantryitems",
            attributeSet: attributeSet
        )
        
        CSSearchableIndex.default().indexSearchableItems([searchableItem]) { error in
            if let error = error {
                PSLogger.app.error("Spotlight indexing failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Index multiple items
    static func indexItems(_ items: [FreshliItem]) {
        items.forEach { indexItem($0) }
    }
    
    /// Remove item from index
    static func removeItem(_ itemId: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [itemId.uuidString]) { error in
            if let error = error {
                PSLogger.app.error("Spotlight removal failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Clear all indexed items
    static func clearAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.freshli.pantryitems"]) { error in
            if let error = error {
                PSLogger.app.error("Spotlight clear failed: \(error.localizedDescription)")
            }
        }
    }
}

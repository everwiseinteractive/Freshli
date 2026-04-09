import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import os

enum SpotlightService {
    private static let logger = PSLogger(category: .pantry)
    private static let domainIdentifier = "com.everwise.Freshli.freshliItems"

    /// Index a single pantry item in Spotlight
    static func indexItem(_ item: FreshliItem) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = item.name
        attributeSet.contentDescription = buildDescription(for: item)
        attributeSet.keywords = buildKeywords(for: item)

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: item.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )

        // Items auto-expire from Spotlight after 30 days
        searchableItem.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        CSSearchableIndex.default().indexSearchableItems([searchableItem]) { error in
            if let error {
                logger.error("Failed to index item in Spotlight: \(error.localizedDescription)")
            } else {
                logger.debug("Indexed item in Spotlight: \(item.name)")
            }
        }
    }

    /// Index multiple pantry items
    static func indexItems(_ items: [FreshliItem]) {
        let searchableItems = items.map { item -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
            attributeSet.title = item.name
            attributeSet.contentDescription = buildDescription(for: item)
            attributeSet.keywords = buildKeywords(for: item)

            let searchableItem = CSSearchableItem(
                uniqueIdentifier: item.id.uuidString,
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
            searchableItem.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
            return searchableItem
        }

        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error {
                logger.error("Failed to index \(items.count) items in Spotlight: \(error.localizedDescription)")
            } else {
                logger.info("Indexed \(items.count) items in Spotlight")
            }
        }
    }

    /// Remove an item from Spotlight index
    static func removeItem(_ itemId: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [itemId.uuidString]) { error in
            if let error {
                logger.error("Failed to remove item from Spotlight: \(error.localizedDescription)")
            }
        }
    }

    /// Remove all Freshli items from Spotlight
    static func removeAllItems() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error {
                logger.error("Failed to remove all items from Spotlight: \(error.localizedDescription)")
            } else {
                logger.info("Cleared all Freshli items from Spotlight")
            }
        }
    }

    // MARK: - Helpers

    private static func buildDescription(for item: FreshliItem) -> String {
        var parts: [String] = []
        parts.append(item.category.displayName)
        parts.append(item.quantityDisplay)
        parts.append(item.expiryDate.expiryDisplayText)
        parts.append("Stored in \(item.storageLocation.displayName)")
        return parts.joined(separator: " · ")
    }

    private static func buildKeywords(for item: FreshliItem) -> [String] {
        var keywords = [item.name, item.category.displayName, item.storageLocation.displayName, "pantry", "food"]
        if let notes = item.notes, !notes.isEmpty {
            keywords.append(notes)
        }
        return keywords
    }
}

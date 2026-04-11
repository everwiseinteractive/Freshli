import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import os

enum SpotlightService {
    // Apple's `os.Logger` is Sendable; safe to use from @Sendable completion handlers.
    nonisolated static let logger = Logger(subsystem: "com.freshli.app", category: "Spotlight")
    private static let domainIdentifier = "com.everwise.Freshli.freshliItems"

    /// Index a single pantry item in Spotlight
    static func indexItem(_ item: FreshliItem) {
        // Snapshot Sendable values before crossing the @Sendable closure boundary.
        let itemName = item.name

        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = itemName
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
                logger.error("Failed to index item in Spotlight: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.debug("Indexed item in Spotlight: \(itemName, privacy: .public)")
            }
        }
    }

    /// Index multiple pantry items
    static func indexItems(_ items: [FreshliItem]) {
        // Build all CSSearchableItem instances and snapshot count on the current actor,
        // then hand off the Sendable array + int to the completion closure.
        let searchableItems: [CSSearchableItem] = items.map { item in
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
        let count = searchableItems.count

        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error {
                logger.error("Failed to index \(count) items in Spotlight: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("Indexed \(count) items in Spotlight")
            }
        }
    }

    /// Remove an item from Spotlight index
    static func removeItem(_ itemId: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [itemId.uuidString]) { error in
            if let error {
                logger.error("Failed to remove item from Spotlight: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Remove all Freshli items from Spotlight
    static func removeAllItems() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error {
                logger.error("Failed to remove all items from Spotlight: \(error.localizedDescription, privacy: .public)")
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

import Foundation
import Supabase
import os

// MARK: - Update Parameter Structs (typed Encodable for Supabase)

private struct ConsumedUpdate: Encodable {
    let is_consumed: Bool
    let updated_at: String
}

private struct SharedUpdate: Encodable {
    let is_shared: Bool
    let updated_at: String
}

private struct DonatedUpdate: Encodable {
    let is_donated: Bool
    let updated_at: String
}

private struct QuantityUpdate: Encodable {
    let quantity: Double
    let updated_at: String
}

private struct ExpiryDateUpdate: Encodable {
    let expiry_date: String
    let updated_at: String
}

// MARK: - Freshli Supabase Service
// Handles all item operations with Supabase including CRUD, status updates, and queries.

final class FreshliSupabaseService: Sendable {
    nonisolated private let client = AppSupabase.client
    nonisolated private let logger = Logger(subsystem: "com.freshli.app", category: "FreshliSupabaseService")

    nonisolated init() {}

    // MARK: - Fetch Operations

    /// Fetches all items for the current user
    /// - Parameter userId: User ID to fetch items for
    /// - Returns: Array of SupabaseFreshliItem
    /// - Throws: DatabaseError if the fetch fails
    func fetchItems(for userId: UUID) async throws -> [SupabaseFreshliItem] {
        debugLog("FreshliSupabaseService: Fetching items for user \(userId)")

        let items: [SupabaseFreshliItem] = try await client
            .from("pantry_items")
            .select()
            .eq("user_id", value: userId)
            .order("date_added", ascending: false)
            .execute()
            .value

        debugLog("FreshliSupabaseService: Fetched \(items.count) items for user \(userId)")
        return items
    }

    /// Fetches a single item by ID
    /// - Parameters:
    ///   - itemId: Item ID to fetch
    ///   - userId: User ID for verification
    /// - Returns: SupabaseFreshliItem if found
    /// - Throws: DatabaseError if not found or access denied
    func fetchItem(id itemId: UUID, userId: UUID) async throws -> SupabaseFreshliItem {
        debugLog("FreshliSupabaseService: Fetching item \(itemId)")

        let item: SupabaseFreshliItem = try await client
            .from("pantry_items")
            .select()
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value

        return item
    }

    /// Fetches items expiring within a specified number of days
    /// - Parameters:
    ///   - userId: User ID to fetch items for
    ///   - days: Number of days from now to check expiry
    /// - Returns: Array of expiring SupabaseFreshliItem, sorted by expiry date
    /// - Throws: DatabaseError if the fetch fails
    func fetchExpiringItems(for userId: UUID, within days: Int) async throws -> [SupabaseFreshliItem] {
        debugLog("FreshliSupabaseService: Fetching items expiring within \(days) days for user \(userId)")

        guard let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) else {
            debugLog("FreshliSupabaseService: Failed to compute future date")
            return []
        }
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: futureDate)

        let items: [SupabaseFreshliItem] = try await client
            .from("pantry_items")
            .select()
            .eq("user_id", value: userId)
            .eq("is_consumed", value: false)
            .lt("expiry_date", value: dateString)
            .order("expiry_date", ascending: true)
            .execute()
            .value

        debugLog("FreshliSupabaseService: Found \(items.count) expiring items")
        return items
    }

    /// Fetches items marked as shared but not yet claimed
    /// - Parameter userId: User ID to fetch items for
    /// - Returns: Array of shared SupabaseFreshliItem
    /// - Throws: DatabaseError if the fetch fails
    func fetchSharedItems(for userId: UUID) async throws -> [SupabaseFreshliItem] {
        debugLog("FreshliSupabaseService: Fetching shared items for user \(userId)")

        let items: [SupabaseFreshliItem] = try await client
            .from("pantry_items")
            .select()
            .eq("user_id", value: userId)
            .eq("is_shared", value: true)
            .eq("is_consumed", value: false)
            .order("date_added", ascending: false)
            .execute()
            .value

        return items
    }

    /// Fetches items by category
    /// - Parameters:
    ///   - userId: User ID to fetch items for
    ///   - category: Category to filter by
    /// - Returns: Array of SupabaseFreshliItem in the specified category
    /// - Throws: DatabaseError if the fetch fails
    func fetchItems(for userId: UUID, in category: String) async throws -> [SupabaseFreshliItem] {
        debugLog("FreshliSupabaseService: Fetching items in category '\(category)' for user \(userId)")

        let items: [SupabaseFreshliItem] = try await client
            .from("pantry_items")
            .select()
            .eq("user_id", value: userId)
            .eq("category", value: category)
            .order("date_added", ascending: false)
            .execute()
            .value

        return items
    }

    // MARK: - Consumed Items

    /// Fetches consumed items for a user within the specified number of days
    /// - Parameters:
    ///   - userId: User ID to fetch items for
    ///   - days: Number of days to look back
    /// - Returns: Array of consumed SupabaseFreshliItem
    /// - Throws: DatabaseError if the fetch fails
    func fetchConsumedItems(for userId: UUID, days: Int) async throws -> [SupabaseFreshliItem] {
        debugLog("FreshliSupabaseService: Fetching consumed items for user \(userId) within \(days) days")

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffString = ISO8601DateFormatter().string(from: cutoffDate)

        let items: [SupabaseFreshliItem] = try await client
            .from("pantry_items")
            .select()
            .eq("user_id", value: userId)
            .eq("is_consumed", value: true)
            .gte("updated_at", value: cutoffString)
            .order("updated_at", ascending: false)
            .execute()
            .value

        return items
    }

    // MARK: - Add Operations

    /// Adds a new item to Supabase
    /// - Parameter item: SupabaseFreshliItem to add
    /// - Returns: The created SupabaseFreshliItem with server-generated fields
    /// - Throws: DatabaseError if the insert fails
    func addItem(_ item: SupabaseFreshliItem) async throws -> SupabaseFreshliItem {
        debugLog("FreshliSupabaseService: Adding item '\(item.name)' for user \(item.userId)")

        let response: SupabaseFreshliItem = try await client
            .from("pantry_items")
            .insert(item)
            .select()
            .single()
            .execute()
            .value

        debugLog("FreshliSupabaseService: Successfully added item \(response.id)")
        return response
    }

    // MARK: - Update Operations

    /// Updates an existing item
    /// - Parameter item: SupabaseFreshliItem with updated values
    /// - Throws: DatabaseError if the update fails
    func updateItem(_ item: SupabaseFreshliItem) async throws {
        debugLog("FreshliSupabaseService: Updating item \(item.id)")

        try await client
            .from("pantry_items")
            .update(item)
            .eq("id", value: item.id)
            .execute()

        debugLog("FreshliSupabaseService: Successfully updated item \(item.id)")
    }

    /// Marks an item as consumed
    /// - Parameters:
    ///   - itemId: Item ID to mark as consumed
    ///   - userId: User ID for verification
    /// - Throws: DatabaseError if the update fails
    func markAsConsumed(id itemId: UUID, userId: UUID) async throws {
        debugLog("FreshliSupabaseService: Marking item \(itemId) as consumed")

        try await client
            .from("pantry_items")
            .update(ConsumedUpdate(is_consumed: true, updated_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("FreshliSupabaseService: Successfully marked item \(itemId) as consumed")
    }

    /// Marks an item as shared
    /// - Parameters:
    ///   - itemId: Item ID to mark as shared
    ///   - userId: User ID for verification
    /// - Throws: DatabaseError if the update fails
    func markAsShared(id itemId: UUID, userId: UUID) async throws {
        debugLog("FreshliSupabaseService: Marking item \(itemId) as shared")

        try await client
            .from("pantry_items")
            .update(SharedUpdate(is_shared: true, updated_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("FreshliSupabaseService: Successfully marked item \(itemId) as shared")
    }

    /// Marks an item as donated
    /// - Parameters:
    ///   - itemId: Item ID to mark as donated
    ///   - userId: User ID for verification
    /// - Throws: DatabaseError if the update fails
    func markAsDonated(id itemId: UUID, userId: UUID) async throws {
        debugLog("FreshliSupabaseService: Marking item \(itemId) as donated")

        try await client
            .from("pantry_items")
            .update(DonatedUpdate(is_donated: true, updated_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("FreshliSupabaseService: Successfully marked item \(itemId) as donated")
    }

    /// Updates the quantity of an item
    /// - Parameters:
    ///   - itemId: Item ID to update
    ///   - userId: User ID for verification
    ///   - quantity: New quantity value
    /// - Throws: DatabaseError if the update fails
    func updateQuantity(for itemId: UUID, userId: UUID, to quantity: Double) async throws {
        debugLog("FreshliSupabaseService: Updating quantity for item \(itemId)")

        try await client
            .from("pantry_items")
            .update(QuantityUpdate(quantity: quantity, updated_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("FreshliSupabaseService: Successfully updated quantity for item \(itemId)")
    }

    /// Updates the expiry date of an item
    /// - Parameters:
    ///   - itemId: Item ID to update
    ///   - userId: User ID for verification
    ///   - expiryDate: New expiry date
    /// - Throws: DatabaseError if the update fails
    func updateExpiryDate(for itemId: UUID, userId: UUID, to expiryDate: Date) async throws {
        debugLog("FreshliSupabaseService: Updating expiry date for item \(itemId)")

        let dateString = ISO8601DateFormatter().string(from: expiryDate)
        try await client
            .from("pantry_items")
            .update(ExpiryDateUpdate(expiry_date: dateString, updated_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("FreshliSupabaseService: Successfully updated expiry date for item \(itemId)")
    }

    // MARK: - Delete Operations

    /// Deletes a item
    /// - Parameters:
    ///   - itemId: Item ID to delete
    ///   - userId: User ID for verification
    /// - Throws: DatabaseError if the delete fails
    func deleteItem(id itemId: UUID, userId: UUID) async throws {
        debugLog("FreshliSupabaseService: Deleting item \(itemId)")

        try await client
            .from("pantry_items")
            .delete()
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("FreshliSupabaseService: Successfully deleted item \(itemId)")
    }

    // MARK: - Helper Enums

    enum DatabaseError: LocalizedError {
        case fetchFailed(String)
        case insertFailed(String)
        case updateFailed(String)
        case deleteFailed(String)
        case itemNotFound
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message):
                return "Failed to fetch items: \(message)"
            case .insertFailed(let message):
                return "Failed to add item: \(message)"
            case .updateFailed(let message):
                return "Failed to update item: \(message)"
            case .deleteFailed(let message):
                return "Failed to delete item: \(message)"
            case .itemNotFound:
                return "Item not found"
            case .accessDenied:
                return "Access denied to this item"
            }
        }
    }
}

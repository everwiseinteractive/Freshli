import Foundation
import Supabase
import os

// MARK: - Pantry Supabase Service
// Handles all pantry item operations with Supabase including CRUD, status updates, and queries.

@Observable
final class PantrySupabaseService: Sendable {
    private let client = AppSupabase.client
    private let logger = Logger(subsystem: "com.freshli.app", category: "PantrySupabaseService")

    // MARK: - Fetch Operations

    /// Fetches all pantry items for the current user
    /// - Parameter userId: User ID to fetch items for
    /// - Returns: Array of SupabasePantryItem
    /// - Throws: DatabaseError if the fetch fails
    func fetchItems(for userId: UUID) async throws -> [SupabasePantryItem] {
        debugLog("PantrySupabaseService: Fetching items for user \(userId)")

        let items: [SupabasePantryItem] = try await client
            .from("pantry_items")
            .select()
            .eq("user_id", value: userId)
            .order("date_added", ascending: false)
            .execute()
            .value

        debugLog("PantrySupabaseService: Fetched \(items.count) items for user \(userId)")
        return items
    }

    /// Fetches a single pantry item by ID
    /// - Parameters:
    ///   - itemId: Item ID to fetch
    ///   - userId: User ID for verification
    /// - Returns: SupabasePantryItem if found
    /// - Throws: DatabaseError if not found or access denied
    func fetchItem(id itemId: UUID, userId: UUID) async throws -> SupabasePantryItem {
        debugLog("PantrySupabaseService: Fetching item \(itemId)")

        let item: SupabasePantryItem = try await client
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
    /// - Returns: Array of expiring SupabasePantryItem, sorted by expiry date
    /// - Throws: DatabaseError if the fetch fails
    func fetchExpiringItems(for userId: UUID, within days: Int) async throws -> [SupabasePantryItem] {
        debugLog("PantrySupabaseService: Fetching items expiring within \(days) days for user \(userId)")

        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date())!
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: futureDate)

        let items: [SupabasePantryItem] = try await client
            .from("pantry_items")
            .select()
            .eq("user_id", value: userId)
            .eq("is_consumed", value: false)
            .lt("expiry_date", value: dateString)
            .order("expiry_date", ascending: true)
            .execute()
            .value

        debugLog("PantrySupabaseService: Found \(items.count) expiring items")
        return items
    }

    /// Fetches items marked as shared but not yet claimed
    /// - Parameter userId: User ID to fetch items for
    /// - Returns: Array of shared SupabasePantryItem
    /// - Throws: DatabaseError if the fetch fails
    func fetchSharedItems(for userId: UUID) async throws -> [SupabasePantryItem] {
        debugLog("PantrySupabaseService: Fetching shared items for user \(userId)")

        let items: [SupabasePantryItem] = try await client
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
    /// - Returns: Array of SupabasePantryItem in the specified category
    /// - Throws: DatabaseError if the fetch fails
    func fetchItems(for userId: UUID, in category: String) async throws -> [SupabasePantryItem] {
        debugLog("PantrySupabaseService: Fetching items in category '\(category)' for user \(userId)")

        let items: [SupabasePantryItem] = try await client
            .from("pantry_items")
            .select()
            .eq("user_id", value: userId)
            .eq("category", value: category)
            .order("date_added", ascending: false)
            .execute()
            .value

        return items
    }

    // MARK: - Add Operations

    /// Adds a new pantry item to Supabase
    /// - Parameter item: SupabasePantryItem to add
    /// - Returns: The created SupabasePantryItem with server-generated fields
    /// - Throws: DatabaseError if the insert fails
    func addItem(_ item: SupabasePantryItem) async throws -> SupabasePantryItem {
        debugLog("PantrySupabaseService: Adding item '\(item.name)' for user \(item.userId)")

        let response: SupabasePantryItem = try await client
            .from("pantry_items")
            .insert(item)
            .select()
            .single()
            .execute()
            .value

        debugLog("PantrySupabaseService: Successfully added item \(response.id)")
        return response
    }

    // MARK: - Update Operations

    /// Updates an existing pantry item
    /// - Parameter item: SupabasePantryItem with updated values
    /// - Throws: DatabaseError if the update fails
    func updateItem(_ item: SupabasePantryItem) async throws {
        debugLog("PantrySupabaseService: Updating item \(item.id)")

        try await client
            .from("pantry_items")
            .update(item)
            .eq("id", value: item.id)
            .execute()

        debugLog("PantrySupabaseService: Successfully updated item \(item.id)")
    }

    /// Marks an item as consumed
    /// - Parameters:
    ///   - itemId: Item ID to mark as consumed
    ///   - userId: User ID for verification
    /// - Throws: DatabaseError if the update fails
    func markAsConsumed(id itemId: UUID, userId: UUID) async throws {
        debugLog("PantrySupabaseService: Marking item \(itemId) as consumed")

        try await client
            .from("pantry_items")
            .update(["is_consumed": true, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("PantrySupabaseService: Successfully marked item \(itemId) as consumed")
    }

    /// Marks an item as shared
    /// - Parameters:
    ///   - itemId: Item ID to mark as shared
    ///   - userId: User ID for verification
    /// - Throws: DatabaseError if the update fails
    func markAsShared(id itemId: UUID, userId: UUID) async throws {
        debugLog("PantrySupabaseService: Marking item \(itemId) as shared")

        try await client
            .from("pantry_items")
            .update(["is_shared": true, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("PantrySupabaseService: Successfully marked item \(itemId) as shared")
    }

    /// Marks an item as donated
    /// - Parameters:
    ///   - itemId: Item ID to mark as donated
    ///   - userId: User ID for verification
    /// - Throws: DatabaseError if the update fails
    func markAsDonated(id itemId: UUID, userId: UUID) async throws {
        debugLog("PantrySupabaseService: Marking item \(itemId) as donated")

        try await client
            .from("pantry_items")
            .update(["is_donated": true, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("PantrySupabaseService: Successfully marked item \(itemId) as donated")
    }

    /// Updates the quantity of an item
    /// - Parameters:
    ///   - itemId: Item ID to update
    ///   - userId: User ID for verification
    ///   - quantity: New quantity value
    /// - Throws: DatabaseError if the update fails
    func updateQuantity(for itemId: UUID, userId: UUID, to quantity: Double) async throws {
        debugLog("PantrySupabaseService: Updating quantity for item \(itemId)")

        try await client
            .from("pantry_items")
            .update(["quantity": quantity, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("PantrySupabaseService: Successfully updated quantity for item \(itemId)")
    }

    /// Updates the expiry date of an item
    /// - Parameters:
    ///   - itemId: Item ID to update
    ///   - userId: User ID for verification
    ///   - expiryDate: New expiry date
    /// - Throws: DatabaseError if the update fails
    func updateExpiryDate(for itemId: UUID, userId: UUID, to expiryDate: Date) async throws {
        debugLog("PantrySupabaseService: Updating expiry date for item \(itemId)")

        let dateString = ISO8601DateFormatter().string(from: expiryDate)
        try await client
            .from("pantry_items")
            .update(["expiry_date": dateString, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("PantrySupabaseService: Successfully updated expiry date for item \(itemId)")
    }

    // MARK: - Delete Operations

    /// Deletes a pantry item
    /// - Parameters:
    ///   - itemId: Item ID to delete
    ///   - userId: User ID for verification
    /// - Throws: DatabaseError if the delete fails
    func deleteItem(id itemId: UUID, userId: UUID) async throws {
        debugLog("PantrySupabaseService: Deleting item \(itemId)")

        try await client
            .from("pantry_items")
            .delete()
            .eq("id", value: itemId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("PantrySupabaseService: Successfully deleted item \(itemId)")
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
                return "Failed to fetch pantry items: \(message)"
            case .insertFailed(let message):
                return "Failed to add pantry item: \(message)"
            case .updateFailed(let message):
                return "Failed to update pantry item: \(message)"
            case .deleteFailed(let message):
                return "Failed to delete pantry item: \(message)"
            case .itemNotFound:
                return "Pantry item not found"
            case .accessDenied:
                return "Access denied to this pantry item"
            }
        }
    }
}

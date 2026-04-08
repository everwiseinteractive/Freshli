import Foundation
import SwiftData
import Supabase

// MARK: - SyncService
// Bridges SwiftData (local, offline-first) with Supabase (remote).
// Strategy: SwiftData is the source of truth. Sync pushes local changes
// to Supabase and pulls remote changes on demand.

@Observable
final class SyncService {
    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?

    private let client = AppSupabase.client

    // MARK: - Pantry Items

    /// Push a single pantry item to Supabase (upsert).
    func pushPantryItem(_ item: PantryItem, userId: UUID) async {
        let dto = PantryItemDTO(from: item, userId: userId)
        do {
            try await client
                .from("pantry_items")
                .upsert(dto)
                .execute()
        } catch {
            syncError = "Failed to sync item: \(error.localizedDescription)"
        }
    }

    /// Push all active pantry items to Supabase.
    func pushAllPantryItems(_ items: [PantryItem], userId: UUID) async {
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        let dtos = items.map { PantryItemDTO(from: $0, userId: userId) }

        do {
            try await client
                .from("pantry_items")
                .upsert(dtos)
                .execute()
            syncError = nil
        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
        }
    }

    /// Pull pantry items from Supabase and merge into SwiftData.
    func pullPantryItems(userId: UUID, modelContext: ModelContext) async {
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        do {
            let remoteDTOs: [PantryItemDTO] = try await client
                .from("pantry_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            // Fetch existing local IDs for dedup
            let localDescriptor = FetchDescriptor<PantryItem>()
            let localItems = (try? modelContext.fetch(localDescriptor)) ?? []
            let localIds = Set(localItems.map(\.id))

            for dto in remoteDTOs where !localIds.contains(dto.id) {
                let item = PantryItem(
                    name: dto.name,
                    category: FoodCategory(rawValue: dto.category) ?? .other,
                    storageLocation: StorageLocation(rawValue: dto.storageLocation) ?? .pantry,
                    quantity: dto.quantity,
                    unit: MeasurementUnit(rawValue: dto.unit) ?? .pieces,
                    expiryDate: dto.expiryDate,
                    barcode: dto.barcode,
                    notes: dto.notes
                )
                // Preserve the remote UUID
                item.id = dto.id
                item.isConsumed = dto.isConsumed
                item.isShared = dto.isShared
                item.isDonated = dto.isDonated
                modelContext.insert(item)
            }

            try? modelContext.save()
            syncError = nil
        } catch {
            syncError = "Pull failed: \(error.localizedDescription)"
        }
    }

    /// Delete a pantry item from Supabase.
    func deletePantryItem(id: UUID) async {
        do {
            try await client
                .from("pantry_items")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            syncError = "Delete sync failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Profile

    /// Fetch the user's profile from Supabase.
    func fetchProfile(userId: UUID) async -> ProfileDTO? {
        do {
            let profiles: [ProfileDTO] = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            return profiles.first
        } catch {
            syncError = "Profile fetch failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// Update the user's profile on Supabase.
    func updateProfile(_ profile: ProfileDTO) async {
        do {
            try await client
                .from("profiles")
                .update(profile)
                .eq("id", value: profile.id.uuidString)
                .execute()
        } catch {
            syncError = "Profile update failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Shared Listings

    /// Create a shared listing on Supabase.
    func createSharedListing(_ listing: SharedListing, userId: UUID) async {
        let dto = SharedListingDTO(from: listing, userId: userId)
        do {
            try await client
                .from("shared_listings")
                .insert(dto)
                .execute()
        } catch {
            syncError = "Listing creation failed: \(error.localizedDescription)"
        }
    }

    /// Fetch all active community listings from Supabase.
    func fetchActiveListings() async -> [SharedListingDTO] {
        do {
            let listings: [SharedListingDTO] = try await client
                .from("shared_listings")
                .select()
                .eq("status", value: "active")
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            return listings
        } catch {
            syncError = "Listings fetch failed: \(error.localizedDescription)"
            return []
        }
    }

    /// Claim a shared listing.
    func claimListing(listingId: UUID, claimerId: UUID) async -> Bool {
        do {
            try await client
                .from("shared_listings")
                .update(["status": "claimed", "claimed_by": claimerId.uuidString])
                .eq("id", value: listingId.uuidString)
                .execute()
            return true
        } catch {
            syncError = "Claim failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Impact Events

    /// Record an impact event on Supabase.
    func recordImpactEvent(
        userId: UUID,
        eventType: String,
        itemName: String? = nil,
        quantity: Double? = nil,
        moneySaved: Double? = nil,
        co2Avoided: Double? = nil
    ) async {
        let event = ImpactEventDTO(
            userId: userId,
            eventType: eventType,
            itemName: itemName,
            quantity: quantity,
            estimatedMoneySaved: moneySaved,
            estimatedCo2Avoided: co2Avoided
        )

        do {
            try await client
                .from("impact_events")
                .insert(event)
                .execute()
        } catch {
            // Impact events are non-critical — log but don't surface to user
            print("[SyncService] Impact event failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Achievements

    /// Record an achievement unlock on Supabase.
    func recordAchievement(userId: UUID, key: String, title: String, description: String?) async {
        let achievement = AchievementDTO(
            userId: userId,
            achievementKey: key,
            title: title,
            description: description
        )

        do {
            try await client
                .from("achievements")
                .upsert(achievement)
                .execute()
        } catch {
            print("[SyncService] Achievement record failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Streaks

    /// Update streak data on Supabase.
    func updateStreak(userId: UUID, type: String, current: Int, longest: Int) async {
        let streak = StreakDTO(
            userId: userId,
            streakType: type,
            currentCount: current,
            longestCount: longest,
            lastActivityDate: Date()
        )

        do {
            try await client
                .from("streaks")
                .upsert(streak)
                .execute()
        } catch {
            print("[SyncService] Streak update failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Saved Recipes

    /// Save a recipe to user's saved list.
    func saveRecipe(userId: UUID, recipeId: String) async {
        let saved = SavedRecipeDTO(userId: userId, recipeId: recipeId)
        do {
            try await client
                .from("saved_recipes")
                .upsert(saved)
                .execute()
        } catch {
            print("[SyncService] Recipe save failed: \(error.localizedDescription)")
        }
    }

    /// Fetch user's saved recipe IDs.
    func fetchSavedRecipes(userId: UUID) async -> [String] {
        do {
            let saved: [SavedRecipeDTO] = try await client
                .from("saved_recipes")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            return saved.map(\.recipeId)
        } catch {
            return []
        }
    }

    // MARK: - Full Sync

    /// Perform a full bidirectional sync for the authenticated user.
    func performFullSync(userId: UUID, modelContext: ModelContext) async {
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        // 1. Push local items to remote
        let descriptor = FetchDescriptor<PantryItem>()
        let localItems = (try? modelContext.fetch(descriptor)) ?? []
        let dtos = localItems.map { PantryItemDTO(from: $0, userId: userId) }

        if !dtos.isEmpty {
            do {
                try await client
                    .from("pantry_items")
                    .upsert(dtos)
                    .execute()
            } catch {
                print("[SyncService] Push failed: \(error.localizedDescription)")
            }
        }

        // 2. Pull remote items we don't have locally
        await pullPantryItems(userId: userId, modelContext: modelContext)
    }
}

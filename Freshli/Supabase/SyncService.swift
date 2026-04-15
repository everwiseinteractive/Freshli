import Foundation
import SwiftData
import Supabase
import os

// MARK: - SyncService
// Bridges SwiftData (local, offline-first) with Supabase (remote).
// Strategy: SwiftData is the source of truth. Sync pushes local changes
// to Supabase and pulls remote changes on demand.

@Observable @MainActor
final class SyncService {
    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?

    private let client = AppSupabase.client
    private let logger = PSLogger(category: .sync)

    // MARK: - Freshli Items

    /// Push a single pantry item to Supabase (upsert).
    func pushFreshliItem(_ item: FreshliItem, userId: UUID) async {
        guard NetworkMonitor.shared.isConnected else {
            logger.info("Offline - queuing item push for later")
            if let data = try? JSONEncoder().encode(FreshliItemDTO(from: item, userId: userId)) {
                OfflineSyncQueue.shared.enqueueItemPush(itemData: data)
            }
            return
        }

        let dto = FreshliItemDTO(from: item, userId: userId)
        do {
            try await client
                .from("pantry_items")
                .upsert(dto)
                .execute()
        } catch {
            logger.error("PushFreshliItem failed: \(error.localizedDescription)")
            syncError = "Failed to sync item. Please try again."
        }
    }

    /// Push all active pantry items to Supabase.
    func pushAllFreshliItems(_ items: [FreshliItem], userId: UUID) async {
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        guard NetworkMonitor.shared.isConnected else {
            logger.info("Offline - queuing \(items.count) items for later push")
            for item in items {
                if let data = try? JSONEncoder().encode(FreshliItemDTO(from: item, userId: userId)) {
                    OfflineSyncQueue.shared.enqueueItemPush(itemData: data)
                }
            }
            syncError = "Offline - changes will sync when connection is restored."
            return
        }

        let dtos = items.map { FreshliItemDTO(from: $0, userId: userId) }

        do {
            try await client
                .from("pantry_items")
                .upsert(dtos)
                .execute()
            syncError = nil
            logger.info("Pushed \(dtos.count) items to Supabase")
        } catch {
            logger.error("PushAllFreshliItems failed for \(dtos.count) items: \(error.localizedDescription)")
            syncError = "Sync failed. Please try again."
        }
    }

    /// Pull pantry items from Supabase and merge into SwiftData.
    /// Uses pagination with limit(200) to prevent unbounded fetches.
    func pullFreshliItems(userId: UUID, modelContext: ModelContext) async {
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        do {
            let remoteDTOs: [FreshliItemDTO] = try await client
                .from("pantry_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("updated_at", ascending: false)
                .limit(200)
                .execute()
                .value

            // Fetch existing local IDs for dedup
            let localDescriptor = FetchDescriptor<FreshliItem>()
            let localItems = (try? modelContext.fetch(localDescriptor)) ?? []
            let localIds = Set(localItems.map(\.id))

            for dto in remoteDTOs where !localIds.contains(dto.id) {
                let item = FreshliItem(
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
            logger.info("Pulled \(remoteDTOs.count) items from Supabase")
        } catch {
            logger.error("PullFreshliItems failed: \(error.localizedDescription)")
            syncError = "Failed to sync items. Please try again."
        }
    }

    /// Delete a pantry item from Supabase.
    func deleteFreshliItem(id: UUID) async {
        guard NetworkMonitor.shared.isConnected else {
            logger.info("Offline - queuing item deletion for later")
            let op = OfflineSyncQueue.SyncOperation(
                id: UUID(),
                type: .deleteItem,
                payload: id.uuidString.data(using: .utf8) ?? Data(),
                createdAt: Date()
            )
            OfflineSyncQueue.shared.enqueue(op)
            return
        }

        do {
            try await client
                .from("pantry_items")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            logger.info("Deleted item: \(id.uuidString)")
        } catch {
            logger.error("DeleteFreshliItem failed: \(error.localizedDescription)")
            syncError = "Failed to delete item. Please try again."
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
            logger.debug("FetchProfile failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Update the user's profile on Supabase.
    func updateProfile(_ profile: ProfileDTO) async {
        guard NetworkMonitor.shared.isConnected else {
            logger.info("Offline - queuing profile update for later")
            if let data = try? JSONEncoder().encode(profile) {
                let op = OfflineSyncQueue.SyncOperation(
                    id: UUID(),
                    type: .updateProfile,
                    payload: data,
                    createdAt: Date()
                )
                OfflineSyncQueue.shared.enqueue(op)
            }
            return
        }

        do {
            try await client
                .from("profiles")
                .update(profile)
                .eq("id", value: profile.id.uuidString)
                .execute()
            logger.info("Profile updated successfully")
        } catch {
            logger.error("UpdateProfile failed: \(error.localizedDescription)")
            syncError = "Failed to update profile. Please try again."
        }
    }

    // MARK: - Shared Listings

    /// Create a shared listing on Supabase.
    func createSharedListing(_ listing: SharedListing, userId: UUID) async {
        guard NetworkMonitor.shared.isConnected else {
            logger.info("Offline - queuing shared listing creation for later")
            if let data = try? JSONEncoder().encode(SharedListingDTO(from: listing, userId: userId)) {
                let op = OfflineSyncQueue.SyncOperation(
                    id: UUID(),
                    type: .createListing,
                    payload: data,
                    createdAt: Date()
                )
                OfflineSyncQueue.shared.enqueue(op)
            }
            return
        }

        let dto = SharedListingDTO(from: listing, userId: userId)
        do {
            try await client
                .from("shared_listings")
                .insert(dto)
                .execute()
            logger.info("Created shared listing")
        } catch {
            logger.error("CreateSharedListing failed: \(error.localizedDescription)")
            syncError = "Failed to create listing. Please try again."
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
            logger.debug("FetchActiveListings failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Claim a shared listing (atomic update to ensure RLS safety).
    func claimListing(listingId: UUID, claimerId: UUID) async -> Bool {
        guard NetworkMonitor.shared.isConnected else {
            logger.info("Offline - queuing listing claim for later")
            let claimData = ["listingId": listingId.uuidString, "claimerId": claimerId.uuidString]
            if let data = try? JSONSerialization.data(withJSONObject: claimData) {
                let op = OfflineSyncQueue.SyncOperation(
                    id: UUID(),
                    type: .claimListing,
                    payload: data,
                    createdAt: Date()
                )
                OfflineSyncQueue.shared.enqueue(op)
            }
            return false
        }

        do {
            try await client
                .from("shared_listings")
                .update(["status": "claimed", "claimed_by": claimerId.uuidString])
                .eq("id", value: listingId.uuidString)
                .execute()
            logger.info("Claimed listing: \(listingId.uuidString)")
            return true
        } catch {
            logger.error("ClaimListing failed: \(error.localizedDescription)")
            syncError = "Failed to claim item. Please try again."
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

        guard NetworkMonitor.shared.isConnected else {
            logger.info("Offline - queuing impact event for later")
            if let data = try? JSONEncoder().encode(event) {
                OfflineSyncQueue.shared.enqueueImpactEvent(eventData: data)
            }
            return
        }

        do {
            try await client
                .from("impact_events")
                .insert(event)
                .execute()
            logger.debug("Recorded impact event: \(eventType)")
        } catch {
            logger.debug("RecordImpactEvent failed: \(error.localizedDescription)")
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
            logger.debug("Recorded achievement: \(key)")
        } catch {
            logger.debug("RecordAchievement failed: \(error.localizedDescription)")
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
            logger.debug("Updated streak: \(type)")
        } catch {
            logger.debug("UpdateStreak failed: \(error.localizedDescription)")
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
            logger.debug("Saved recipe: \(recipeId)")
        } catch {
            logger.debug("SaveRecipe failed: \(error.localizedDescription)")
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
    /// Prevents concurrent sync operations to avoid race conditions.
    func performFullSync(userId: UUID, modelContext: ModelContext) async {
        guard !isSyncing else {
            logger.debug("Sync already in progress, skipping")
            return
        }

        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        // 0. If offline, queue operations and bail out
        guard NetworkMonitor.shared.isConnected else {
            logger.info("Offline - skipping full sync, pending operations will sync when connection restored")
            return
        }

        // 1. Push local items to remote
        let descriptor = FetchDescriptor<FreshliItem>()
        let localItems = (try? modelContext.fetch(descriptor)) ?? []
        let dtos = localItems.map { FreshliItemDTO(from: $0, userId: userId) }

        if !dtos.isEmpty {
            do {
                try await client
                    .from("pantry_items")
                    .upsert(dtos)
                    .execute()
                logger.info("Pushed \(dtos.count) items during full sync")
            } catch {
                logger.error("PerformFullSync push failed: \(error.localizedDescription)")
            }
        }

        // 2. Pull remote items we don't have locally
        await pullFreshliItems(userId: userId, modelContext: modelContext)

        // 3. Process offline queue if it has pending operations
        if OfflineSyncQueue.shared.hasPendingOperations {
            await OfflineSyncQueue.shared.processQueue(using: self)
        }
    }
}

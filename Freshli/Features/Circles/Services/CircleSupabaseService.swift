import Foundation
import Supabase
import os

// MARK: - Circle Supabase Service
// Handles all Freshli Circle operations: CRUD for circles, membership, and circle-scoped listings.
// Circle listings are private by default — requires explicit "Global Share" action.

@Observable @MainActor
final class CircleSupabaseService: Sendable {
    private let client = AppSupabase.client
    private let logger = Logger(subsystem: "com.freshli.app", category: "CircleSupabaseService")

    // MARK: - Circle CRUD

    func fetchCircles(for userId: UUID) async throws -> [SupabaseCircle] {
        debugLog("CircleSupabaseService: Fetching circles for user \(userId)")

        let memberRows: [SupabaseCircleMember] = try await client
            .from("circle_members")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        guard !memberRows.isEmpty else { return [] }

        let circleIds = memberRows.map { $0.circleId }
        let circles: [SupabaseCircle] = try await client
            .from("circles")
            .select()
            .in("id", values: circleIds)
            .order("created_at", ascending: false)
            .execute()
            .value

        debugLog("CircleSupabaseService: Fetched \(circles.count) circles")
        return circles
    }

    func fetchCircle(id circleId: UUID) async throws -> SupabaseCircle {
        debugLog("CircleSupabaseService: Fetching circle \(circleId)")

        let circle: SupabaseCircle = try await client
            .from("circles")
            .select()
            .eq("id", value: circleId)
            .single()
            .execute()
            .value

        return circle
    }

    func createCircle(_ circle: SupabaseCircle) async throws -> SupabaseCircle {
        debugLog("CircleSupabaseService: Creating circle '\(circle.name)'")

        let created: SupabaseCircle = try await client
            .from("circles")
            .insert(circle)
            .select()
            .single()
            .execute()
            .value

        debugLog("CircleSupabaseService: Created circle \(created.id)")
        return created
    }

    func updateCircle(id circleId: UUID, update: CircleUpdate) async throws {
        debugLog("CircleSupabaseService: Updating circle \(circleId)")

        try await client
            .from("circles")
            .update(update)
            .eq("id", value: circleId)
            .execute()

        debugLog("CircleSupabaseService: Updated circle \(circleId)")
    }

    func deleteCircle(id circleId: UUID) async throws {
        debugLog("CircleSupabaseService: Deleting circle \(circleId)")

        try await client
            .from("circles")
            .delete()
            .eq("id", value: circleId)
            .execute()

        debugLog("CircleSupabaseService: Deleted circle \(circleId)")
    }

    // MARK: - Membership

    func fetchMembers(for circleId: UUID) async throws -> [SupabaseCircleMember] {
        debugLog("CircleSupabaseService: Fetching members for circle \(circleId)")

        let members: [SupabaseCircleMember] = try await client
            .from("circle_members")
            .select()
            .eq("circle_id", value: circleId)
            .order("joined_at", ascending: true)
            .execute()
            .value

        debugLog("CircleSupabaseService: Fetched \(members.count) members")
        return members
    }

    func addMember(_ member: SupabaseCircleMember) async throws -> SupabaseCircleMember {
        debugLog("CircleSupabaseService: Adding member \(member.userId) to circle \(member.circleId)")

        let created: SupabaseCircleMember = try await client
            .from("circle_members")
            .insert(member)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    func removeMember(userId: UUID, from circleId: UUID) async throws {
        debugLog("CircleSupabaseService: Removing member \(userId) from circle \(circleId)")

        try await client
            .from("circle_members")
            .delete()
            .eq("circle_id", value: circleId)
            .eq("user_id", value: userId)
            .execute()

        debugLog("CircleSupabaseService: Removed member \(userId)")
    }

    func updateMemberRole(userId: UUID, circleId: UUID, role: CircleMemberRole) async throws {
        debugLog("CircleSupabaseService: Updating role for \(userId) in circle \(circleId)")

        try await client
            .from("circle_members")
            .update(CircleMemberRoleUpdate(role: role.rawValue))
            .eq("circle_id", value: circleId)
            .eq("user_id", value: userId)
            .execute()
    }

    func joinByInviteCode(_ code: String, userId: UUID) async throws -> SupabaseCircle {
        debugLog("CircleSupabaseService: Joining circle with invite code")

        let circle: SupabaseCircle = try await client
            .from("circles")
            .select()
            .eq("invite_code", value: code)
            .single()
            .execute()
            .value

        let member = SupabaseCircleMember(
            id: UUID(),
            circleId: circle.id,
            userId: userId,
            role: CircleMemberRole.member.rawValue,
            displayName: nil,
            avatarUrl: nil,
            joinedAt: Date()
        )
        _ = try await addMember(member)

        debugLog("CircleSupabaseService: Joined circle \(circle.id) via invite code")
        return circle
    }

    // MARK: - Circle Listings (Private by Default)

    func fetchCircleListings(for circleId: UUID) async throws -> [SupabaseCircleListing] {
        debugLog("CircleSupabaseService: Fetching listings for circle \(circleId)")

        let listings: [SupabaseCircleListing] = try await client
            .from("circle_listings")
            .select()
            .eq("circle_id", value: circleId)
            .order("created_at", ascending: false)
            .execute()
            .value

        debugLog("CircleSupabaseService: Fetched \(listings.count) circle listings")
        return listings
    }

    func fetchAvailableListings(for circleId: UUID) async throws -> [SupabaseCircleListing] {
        debugLog("CircleSupabaseService: Fetching available listings for circle \(circleId)")

        let listings: [SupabaseCircleListing] = try await client
            .from("circle_listings")
            .select()
            .eq("circle_id", value: circleId)
            .eq("status", value: CircleListingStatus.available.rawValue)
            .order("created_at", ascending: false)
            .execute()
            .value

        return listings
    }

    func createCircleListing(_ listing: SupabaseCircleListing) async throws -> SupabaseCircleListing {
        debugLog("CircleSupabaseService: Creating circle listing '\(listing.itemName)'")

        let created: SupabaseCircleListing = try await client
            .from("circle_listings")
            .insert(listing)
            .select()
            .single()
            .execute()
            .value

        debugLog("CircleSupabaseService: Created circle listing \(created.id)")
        return created
    }

    func claimCircleListing(id listingId: UUID, claimedBy userId: UUID) async throws {
        debugLog("CircleSupabaseService: Claiming listing \(listingId) by \(userId)")

        let update = CircleListingStatusUpdate(
            status: CircleListingStatus.claimed.rawValue,
            claimedBy: userId.uuidString,
            claimedAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )

        try await client
            .from("circle_listings")
            .update(update)
            .eq("id", value: listingId)
            .execute()

        debugLog("CircleSupabaseService: Claimed listing \(listingId)")
    }

    func globalShareListing(id listingId: UUID, share: Bool) async throws {
        debugLog("CircleSupabaseService: Setting global share to \(share) for listing \(listingId)")

        let update = CircleListingGlobalShareUpdate(
            isGloballyShared: share,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )

        try await client
            .from("circle_listings")
            .update(update)
            .eq("id", value: listingId)
            .execute()
    }

    func deleteCircleListing(id listingId: UUID) async throws {
        debugLog("CircleSupabaseService: Deleting circle listing \(listingId)")

        try await client
            .from("circle_listings")
            .delete()
            .eq("id", value: listingId)
            .execute()
    }
}

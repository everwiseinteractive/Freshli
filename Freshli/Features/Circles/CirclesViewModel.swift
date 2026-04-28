import Foundation
import GroupActivities
import os

// MARK: - Circles ViewModel
// Privacy-first: all circle listings default to private (isGloballyShared = false).
// Users must explicitly perform a "Global Share" action to make items visible outside the circle.

@Observable @MainActor
final class CirclesViewModel {
    var circles: [SupabaseCircle] = []
    var selectedCircle: SupabaseCircle?
    var members: [SupabaseCircleMember] = []
    var listings: [SupabaseCircleListing] = []
    var isLoading = false
    var errorMessage: String?

    // Create Circle form state
    var newCircleName = ""
    var newCircleDescription = ""
    var newCircleEmoji = "🏠"
    var joinCode = ""

    private let service = CircleSupabaseService()
    let sharePlayManager = SharePlayManager()
    private let logger = Logger(subsystem: "com.freshli.app", category: "CirclesViewModel")

    // MARK: - Fetch Circles

    func loadCircles(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            circles = try await service.fetchCircles(for: userId)
        } catch {
            errorMessage = "Couldn't load your circles"
            logger.error("Failed to load circles: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Select & Load Circle Detail

    func selectCircle(_ circle: SupabaseCircle) async {
        selectedCircle = circle
        isLoading = true

        do {
            async let fetchedMembers = service.fetchMembers(for: circle.id)
            async let fetchedListings = service.fetchCircleListings(for: circle.id)
            members = try await fetchedMembers
            listings = try await fetchedListings
        } catch {
            errorMessage = "Couldn't load circle details"
            logger.error("Failed to load circle detail: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Create Circle

    func createCircle(userId: UUID) async -> Bool {
        guard !newCircleName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Circle name is required"
            return false
        }

        isLoading = true
        errorMessage = nil

        let inviteCode = generateInviteCode()
        let circle = SupabaseCircle(
            id: UUID(),
            createdBy: userId,
            name: newCircleName.trimmingCharacters(in: .whitespaces),
            description: newCircleDescription.isEmpty ? nil : newCircleDescription,
            emoji: newCircleEmoji,
            inviteCode: inviteCode,
            isPrivate: true,
            maxMembers: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            let created = try await service.createCircle(circle)

            // Add creator as owner
            let ownerMember = SupabaseCircleMember(
                id: UUID(),
                circleId: created.id,
                userId: userId,
                role: CircleMemberRole.owner.rawValue,
                displayName: nil,
                avatarUrl: nil,
                joinedAt: Date()
            )
            _ = try await service.addMember(ownerMember)

            circles.insert(created, at: 0)
            resetCreateForm()
            CircleHaptics.circleCreated()
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to create circle"
            logger.error("Create circle failed: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }

    // MARK: - Join by Invite Code

    func joinCircle(userId: UUID) async -> Bool {
        let code = joinCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard !code.isEmpty else {
            errorMessage = "Enter an invite code"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let circle = try await service.joinByInviteCode(code, userId: userId)
            circles.insert(circle, at: 0)
            joinCode = ""
            CircleHaptics.memberJoined()
            isLoading = false
            return true
        } catch {
            errorMessage = "Invalid invite code or circle not found"
            logger.error("Join circle failed: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }

    // MARK: - Create Circle Listing (Private by Default)

    func createListing(
        circleId: UUID,
        userId: UUID,
        itemName: String,
        description: String?,
        quantity: String?,
        expiryDate: Date?
    ) async -> Bool {
        let listing = SupabaseCircleListing(
            id: UUID(),
            circleId: circleId,
            userId: userId,
            itemName: itemName,
            itemDescription: description,
            quantity: quantity,
            expiryDate: expiryDate,
            status: CircleListingStatus.available.rawValue,
            isGloballyShared: false, // Privacy-first: private by default
            claimedBy: nil,
            claimedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            let created = try await service.createCircleListing(listing)
            listings.insert(created, at: 0)
            PSHaptics.shared.success()
            return true
        } catch {
            errorMessage = "Failed to share item"
            logger.error("Create circle listing failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Claim Item

    func claimItem(listingId: UUID, userId: UUID) async {
        do {
            try await service.claimCircleListing(id: listingId, claimedBy: userId)
            if let index = listings.firstIndex(where: { $0.id == listingId }) {
                listings[index].status = CircleListingStatus.claimed.rawValue
                listings[index].claimedBy = userId
                listings[index].claimedAt = Date()
            }
            CircleHaptics.itemClaimed()
        } catch {
            errorMessage = "Failed to claim item"
            logger.error("Claim failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Global Share (Explicit Action Required)

    func toggleGlobalShare(listingId: UUID) async {
        guard let index = listings.firstIndex(where: { $0.id == listingId }) else { return }
        let newValue = !listings[index].isGloballyShared

        do {
            try await service.globalShareListing(id: listingId, share: newValue)
            listings[index].isGloballyShared = newValue
            CircleHaptics.globalShareToggled()
        } catch {
            errorMessage = "Failed to update sharing"
            logger.error("Global share toggle failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Remove Member

    func removeMember(userId: UUID, from circleId: UUID) async {
        do {
            try await service.removeMember(userId: userId, from: circleId)
            members.removeAll { $0.userId == userId }
        } catch {
            errorMessage = "Failed to remove member"
            logger.error("Remove member failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Leave Circle

    func leaveCircle(userId: UUID, circleId: UUID) async {
        do {
            try await service.removeMember(userId: userId, from: circleId)
            circles.removeAll { $0.id == circleId }
            if selectedCircle?.id == circleId {
                selectedCircle = nil
                members = []
                listings = []
            }
        } catch {
            errorMessage = "Failed to leave circle"
        }
    }

    // MARK: - SharePlay

    func startSharePlay() async {
        guard let circle = selectedCircle else { return }
        await sharePlayManager.startSession(circleId: circle.id, circleName: circle.name)
        CircleHaptics.sharePlayStarted()
    }

    // MARK: - Helpers

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // no ambiguous chars
        return String((0..<6).map { _ in chars.randomElement() ?? "A" })
    }

    private func resetCreateForm() {
        newCircleName = ""
        newCircleDescription = ""
        newCircleEmoji = "🏠"
    }
}

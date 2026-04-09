import Foundation
import UserNotifications
import UIKit
import os

// MARK: - Claim Status Enum

enum ClaimStatus: String, Codable, CaseIterable {
    case active
    case enRoute
    case expired
    case completed

    var displayName: String {
        switch self {
        case .active: return String(localized: "Active")
        case .enRoute: return String(localized: "En Route")
        case .expired: return String(localized: "Expired")
        case .completed: return String(localized: "Completed")
        }
    }
}

// MARK: - Claim Reservation Model

struct ClaimReservation: Identifiable, Codable {
    let id: UUID
    let listingId: UUID
    let claimerId: UUID
    let claimedAt: Date
    var expiresAt: Date
    var status: ClaimStatus = .active

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case claimerId = "claimer_id"
        case claimedAt = "claimed_at"
        case expiresAt = "expires_at"
        case status
    }

    var remainingTime: TimeInterval {
        max(0, expiresAt.timeIntervalSince(Date()))
    }

    var isExpired: Bool {
        remainingTime <= 0
    }

    var formattedTimeRemaining: String {
        let interval = remainingTime
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60

        if minutes > 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return String(format: "00:%02d", seconds)
        }
    }
}

// MARK: - Smart Reservation Service

@Observable
final class SmartReservationService {
    private let userDefaultsKey = "com.everwise.freshli.claims"
    private let expiryInterval: TimeInterval = 2 * 60 * 60 // 2 hours
    private let earlyNotificationTime: TimeInterval = 30 * 60 // 30 minutes before expiry
    private let logger = PSLogger(category: .community)

    var activeClaims: [ClaimReservation] = []
    var selectedClaim: ClaimReservation?

    init() {
        loadActiveClaims()
        scheduleExpiryCheck()
    }

    // MARK: - Claim Management

    /// Create a new claim for a listing with 2-hour expiry
    func claimItem(listingId: UUID, claimerId: UUID) -> ClaimReservation {
        let now = Date()
        let expiresAt = now.addingTimeInterval(expiryInterval)

        let claim = ClaimReservation(
            id: UUID(),
            listingId: listingId,
            claimerId: claimerId,
            claimedAt: now,
            expiresAt: expiresAt,
            status: .active
        )

        activeClaims.append(claim)
        saveClaims()

        scheduleExpiryNotifications(for: claim)
        logger.info("Created claim for listing \(listingId.uuidString): expires in 2 hours")

        return claim
    }

    /// Mark claim as "en route" to prevent expiry
    func confirmEnRoute(reservationId: UUID) -> Bool {
        guard let index = activeClaims.firstIndex(where: { $0.id == reservationId }) else {
            logger.warning("Claim not found: \(reservationId.uuidString)")
            return false
        }

        var claim = activeClaims[index]
        claim.status = .enRoute
        activeClaims[index] = claim

        saveClaims()
        logger.info("Claim \(reservationId.uuidString) marked as en route")

        return true
    }

    /// Complete a handoff and record quality rating
    func completeHandoff(
        reservationId: UUID,
        qualityRating: Int?,
        goodNeighborService: GoodNeighborService
    ) -> Bool {
        guard let index = activeClaims.firstIndex(where: { $0.id == reservationId }) else {
            logger.warning("Claim not found for completion: \(reservationId.uuidString)")
            return false
        }

        var claim = activeClaims[index]
        let wasOnTime = !claim.isExpired && claim.status == .enRoute

        claim.status = .completed
        activeClaims[index] = claim

        // Record in Good Neighbor Service
        goodNeighborService.recordHandoff(
            successful: true,
            onTime: wasOnTime,
            qualityRating: qualityRating
        )

        saveClaims()
        logger.info("Completed handoff for claim \(reservationId.uuidString): onTime=\(wasOnTime), rating=\(qualityRating ?? 0)")

        return true
    }

    /// Cancel a claim
    func cancelClaim(reservationId: UUID) -> Bool {
        guard let index = activeClaims.firstIndex(where: { $0.id == reservationId }) else {
            logger.warning("Claim not found for cancellation: \(reservationId.uuidString)")
            return false
        }

        activeClaims.remove(at: index)
        saveClaims()
        logger.info("Cancelled claim: \(reservationId.uuidString)")

        return true
    }

    /// Check for expired claims and update their status
    func checkExpiredClaims() {
        var updated = false

        for i in 0..<activeClaims.count {
            if activeClaims[i].status == .active && activeClaims[i].isExpired {
                activeClaims[i].status = .expired
                logger.info("Claim \(activeClaims[i].id.uuidString) expired")
                updated = true
            }
        }

        if updated {
            saveClaims()
        }
    }

    // MARK: - Query Methods

    /// Get active claim by listing ID
    func claimForListing(_ listingId: UUID) -> ClaimReservation? {
        activeClaims.first { $0.listingId == listingId && $0.status != .completed }
    }

    /// Get all non-expired claims for a user
    func activeClaims(for claimerId: UUID) -> [ClaimReservation] {
        activeClaims.filter {
            $0.claimerId == claimerId &&
            !$0.isExpired &&
            $0.status != .completed
        }
    }

    // MARK: - Private Persistence

    private func saveClaims() {
        if let encoded = try? JSONEncoder().encode(activeClaims) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            logger.debug("Saved \(self.activeClaims.count) claims to UserDefaults")
        }
    }

    private func loadActiveClaims() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ClaimReservation].self, from: data) {
            activeClaims = decoded
            logger.info("Loaded \(decoded.count) claims from UserDefaults")
        }
    }

    // MARK: - Notifications

    private func scheduleExpiryNotifications(for claim: ClaimReservation) {
        let notificationTime = claim.expiresAt.addingTimeInterval(-earlyNotificationTime)

        // Schedule 30-minute warning notification
        let warningRequest = UNNotificationRequest(
            identifier: "claim_expiry_warning_\(claim.id.uuidString)",
            content: {
                let content = UNMutableNotificationContent()
                content.title = String(localized: "Claim Expiring Soon")
                content.body = String(localized: "Your claim expires in 30 minutes. Confirm you're en route to complete the pickup.")
                content.sound = .default
                content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
                return content
            }(),
            trigger: UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime),
                repeats: false
            )
        )

        // Schedule expiry notification
        let expiryRequest = UNNotificationRequest(
            identifier: "claim_expired_\(claim.id.uuidString)",
            content: {
                let content = UNMutableNotificationContent()
                content.title = String(localized: "Claim Expired")
                content.body = String(localized: "Your claim has expired. The item is back in the community.")
                content.sound = .default
                return content
            }(),
            trigger: UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: claim.expiresAt),
                repeats: false
            )
        )

        UNUserNotificationCenter.current().add(warningRequest) { error in
            if let error = error {
                self.logger.error("Failed to schedule warning notification: \(error.localizedDescription)")
            }
        }

        UNUserNotificationCenter.current().add(expiryRequest) { error in
            if let error = error {
                self.logger.error("Failed to schedule expiry notification: \(error.localizedDescription)")
            }
        }

        logger.debug("Scheduled notifications for claim \(claim.id.uuidString)")
    }

    // MARK: - Periodic Check

    private func scheduleExpiryCheck() {
        // Check for expired claims every minute
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkExpiredClaims()
        }
    }
}

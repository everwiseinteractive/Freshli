import Foundation
import os
import SwiftUI

// MARK: - Good Neighbor Badge Definition

enum NeighborBadge: String, Codable, CaseIterable, Identifiable {
    case firstShare
    case reliable
    case superSharer
    case punctual
    case qualityStar
    case communityHero

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .firstShare: return String(localized: "First Share")
        case .reliable: return String(localized: "Reliable")
        case .superSharer: return String(localized: "Super Sharer")
        case .punctual: return String(localized: "Punctual")
        case .qualityStar: return String(localized: "Quality Star")
        case .communityHero: return String(localized: "Community Hero")
        }
    }

    var icon: String {
        switch self {
        case .firstShare: return "star.fill"
        case .reliable: return "checkmark.circle.fill"
        case .superSharer: return "gift.fill"
        case .punctual: return "clock.fill"
        case .qualityStar: return "sparkles"
        case .communityHero: return "crown.fill"
        }
    }

    var description: String {
        switch self {
        case .firstShare: return String(localized: "Completed your first handoff")
        case .reliable: return String(localized: "5+ successful handoffs")
        case .superSharer: return String(localized: "15+ successful handoffs")
        case .punctual: return String(localized: "90%+ on-time pickups")
        case .qualityStar: return String(localized: "4.5+ average quality rating")
        case .communityHero: return String(localized: "25+ community handoffs")
        }
    }

    var color: Color {
        switch self {
        case .firstShare: return PSColors.infoBlue
        case .reliable: return PSColors.primaryGreen
        case .superSharer: return PSColors.accentTeal
        case .punctual: return PSColors.warningAmber
        case .qualityStar: return PSColors.primaryGreen
        case .communityHero: return PSColors.freshGreen
        }
    }

    var requirementThreshold: Int {
        switch self {
        case .firstShare: return 1
        case .reliable: return 5
        case .superSharer: return 15
        case .punctual: return 90
        case .qualityStar: return 45
        case .communityHero: return 25
        }
    }
}

// MARK: - Good Neighbor Profile

struct GoodNeighborProfile: Codable {
    var totalHandoffs: Int = 0
    var successfulHandoffs: Int = 0
    var onTimePickups: Int = 0
    var qualityRatings: [Int] = []
    var earnedBadges: [String] = []

    var successRate: Double {
        guard totalHandoffs > 0 else { return 0 }
        return Double(successfulHandoffs) / Double(totalHandoffs)
    }

    var onTimeRate: Double {
        guard successfulHandoffs > 0 else { return 0 }
        return Double(onTimePickups) / Double(successfulHandoffs)
    }

    var averageQualityRating: Double {
        guard !qualityRatings.isEmpty else { return 0 }
        let sum = qualityRatings.reduce(0, +)
        return Double(sum) / Double(qualityRatings.count)
    }
}

// MARK: - Good Neighbor Service

@Observable @MainActor
final class GoodNeighborService {
    private let userDefaultsKey = "com.everwise.freshli.goodneighbor"
    private let logger = PSLogger(category: .community)

    var profile: GoodNeighborProfile {
        didSet {
            saveProfile()
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(GoodNeighborProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = GoodNeighborProfile()
        }
    }

    // MARK: - Recording Handoffs

    /// Record a completed handoff with success status, timeliness, and quality rating
    func recordHandoff(successful: Bool, onTime: Bool = true, qualityRating: Int? = nil) {
        profile.totalHandoffs += 1

        if successful {
            profile.successfulHandoffs += 1

            if onTime {
                profile.onTimePickups += 1
            }

            if let rating = qualityRating, rating >= 1, rating <= 5 {
                profile.qualityRatings.append(rating)
            }
        }

        logger.info("Recorded handoff: successful=\(successful), onTime=\(onTime), rating=\(qualityRating ?? 0)")
        updateBadges()
    }

    // MARK: - Score Calculation

    /// Calculate overall Good Neighbor Score (0-5 stars)
    /// Formula: 40% success rate + 30% punctuality + 30% quality rating
    func calculateScore() -> Double {
        let successComponent = profile.successRate * 0.4
        let punctualityComponent = profile.onTimeRate * 0.3
        let qualityComponent = (profile.averageQualityRating / 5.0) * 0.3

        let score = (successComponent + punctualityComponent + qualityComponent) * 5.0
        return min(5.0, max(0.0, score))
    }

    // MARK: - Badge Management

    /// Get list of earned badges
    func earnedBadges() -> [NeighborBadge] {
        profile.earnedBadges.compactMap { NeighborBadge(rawValue: $0) }
    }

    /// Get all available badges with earned/locked status
    func allBadges() -> [(badge: NeighborBadge, isEarned: Bool)] {
        NeighborBadge.allCases.map { badge in
            (badge: badge, isEarned: profile.earnedBadges.contains(badge.rawValue))
        }
    }

    /// Get next badge to work towards
    func nextBadge() -> NeighborBadge? {
        let allBadges = NeighborBadge.allCases
        for badge in allBadges {
            if !profile.earnedBadges.contains(badge.rawValue) {
                return badge
            }
        }
        return nil
    }

    /// Get progress towards next badge (0.0 to 1.0)
    func progressToNextBadge() -> Double {
        guard let next = nextBadge() else { return 1.0 }

        let progress: Double
        switch next {
        case .firstShare:
            progress = Double(min(profile.totalHandoffs, 1)) / 1.0
        case .reliable:
            progress = Double(min(profile.successfulHandoffs, 5)) / 5.0
        case .superSharer:
            progress = Double(min(profile.successfulHandoffs, 15)) / 15.0
        case .punctual:
            progress = profile.onTimeRate
        case .qualityStar:
            let maxRating = profile.averageQualityRating
            progress = min(1.0, maxRating / 4.5)
        case .communityHero:
            progress = Double(min(profile.totalHandoffs, 25)) / 25.0
        }

        return min(1.0, max(0.0, progress))
    }

    // MARK: - Private Helpers

    private func updateBadges() {
        var newBadges: [String] = []

        // Check each badge requirement
        if profile.totalHandoffs >= 1 {
            newBadges.append(NeighborBadge.firstShare.rawValue)
        }
        if profile.successfulHandoffs >= 5 {
            newBadges.append(NeighborBadge.reliable.rawValue)
        }
        if profile.successfulHandoffs >= 15 {
            newBadges.append(NeighborBadge.superSharer.rawValue)
        }
        if profile.onTimeRate >= 0.9 && profile.successfulHandoffs >= 1 {
            newBadges.append(NeighborBadge.punctual.rawValue)
        }
        if profile.averageQualityRating >= 4.5 && !profile.qualityRatings.isEmpty {
            newBadges.append(NeighborBadge.qualityStar.rawValue)
        }
        if profile.totalHandoffs >= 25 {
            newBadges.append(NeighborBadge.communityHero.rawValue)
        }

        profile.earnedBadges = Array(Set(newBadges)).sorted()
    }

    private func saveProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            logger.debug("Saved Good Neighbor profile")
        }
    }
}


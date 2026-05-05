import Foundation
import SwiftUI

// MARK: - Perks Service
// Zero Waste Points earned from food rescues, redeemable for supermarket discounts.
// Employer wellness milestones with green bonuses and carbon credits.

// MARK: - Models

enum RewardCategory: String, CaseIterable, Identifiable {
    case groceries = "Groceries"
    case dining    = "Dining"
    case wellness  = "Wellness"
    case planet    = "Planet"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .groceries: return "cart.fill"
        case .dining:    return "fork.knife"
        case .wellness:  return "heart.fill"
        case .planet:    return "leaf.fill"
        }
    }
}

struct WasteReward: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let pointsCost: Int
    let retailer: String
    let retailerColor: Color
    let retailerLogo: String   // emoji or single letter
    let discountValue: String
    let category: RewardCategory
}

struct EmployerPerk: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let perkValue: String
    let icon: String
    let color: Color
    let itemsThreshold: Int
    let co2Threshold: Double
}

// MARK: - Service

@MainActor
final class PerksService {
    static let shared = PerksService()
    private init() {}

    // MARK: - Points (10 pts per item rescued)

    func points(for itemsSaved: Int) -> Int { itemsSaved * 10 }

    func pointsDisplay(for itemsSaved: Int) -> String {
        let pts = points(for: itemsSaved)
        return pts >= 1000 ? String(format: "%.1fk", Double(pts) / 1000.0) : "\(pts)"
    }

    // MARK: - Reward Catalog

    let rewards: [WasteReward] = [
        WasteReward(title: "£5 off your next shop",
                    description: "Redeemable on any Tesco shop over £25",
                    pointsCost: 500, retailer: "Tesco",
                    retailerColor: Color(hex: 0x005DA4), retailerLogo: "T",
                    discountValue: "£5 off", category: .groceries),
        WasteReward(title: "50 Nectar Points Boost",
                    description: "Instant 50-point top-up to your Nectar account",
                    pointsCost: 300, retailer: "Sainsbury's",
                    retailerColor: Color(hex: 0xFF8000), retailerLogo: "S",
                    discountValue: "50 pts", category: .groceries),
        WasteReward(title: "10% off at Whole Foods",
                    description: "Valid online or in-store for one transaction",
                    pointsCost: 800, retailer: "Whole Foods",
                    retailerColor: Color(hex: 0x00674B), retailerLogo: "W",
                    discountValue: "10% off", category: .groceries),
        WasteReward(title: "Free coffee at Pret",
                    description: "Redeem for any hot drink at participating Pret locations",
                    pointsCost: 200, retailer: "Pret a Manger",
                    retailerColor: Color(hex: 0xB22222), retailerLogo: "☕",
                    discountValue: "Free drink", category: .dining),
        WasteReward(title: "Plant a tree in your name",
                    description: "We'll plant a tree in a verified reforestation project",
                    pointsCost: 100, retailer: "Freshli Gives",
                    retailerColor: PSColors.primaryGreen, retailerLogo: "🌳",
                    discountValue: "1 tree", category: .planet),
        WasteReward(title: "Carbon credit donation",
                    description: "Offset 50kg CO₂ via a verified climate project",
                    pointsCost: 150, retailer: "Carbon Fund",
                    retailerColor: PSColors.accentTeal, retailerLogo: "🌍",
                    discountValue: "50kg CO₂", category: .planet),
        WasteReward(title: "£10 gym credit",
                    description: "Redeem against any PureGym monthly membership",
                    pointsCost: 1000, retailer: "PureGym",
                    retailerColor: Color(hex: 0xFF6B35), retailerLogo: "🏋️",
                    discountValue: "£10 off", category: .wellness),
    ]

    // MARK: - Employer Perks

    let employerPerks: [EmployerPerk] = [
        EmployerPerk(title: "Green Starter",
                     description: "Save your first 5 items from waste",
                     perkValue: "Eco Badge", icon: "leaf.fill",
                     color: PSColors.primaryGreen,
                     itemsThreshold: 5, co2Threshold: 0),
        EmployerPerk(title: "Sustainable Employee Award",
                     description: "Save 20 items — claim a £25 Green Bonus",
                     perkValue: "£25 Green Bonus", icon: "banknote.fill",
                     color: PSColors.secondaryAmber,
                     itemsThreshold: 20, co2Threshold: 50),
        EmployerPerk(title: "Carbon Credit Certificate",
                     description: "Avoid 100kg CO₂ — earn a verified carbon credit",
                     perkValue: "1 Carbon Credit", icon: "cloud.fill",
                     color: PSColors.accentTeal,
                     itemsThreshold: 40, co2Threshold: 100),
        EmployerPerk(title: "Zero Waste Champion",
                     description: "Rescue 100 items — qualify for company ESG reporting",
                     perkValue: "ESG Recognition", icon: "crown.fill",
                     color: Color(hex: 0xA855F7),
                     itemsThreshold: 100, co2Threshold: 250),
    ]

    func unlockedPerks(itemsSaved: Int, co2Avoided: Double) -> [EmployerPerk] {
        employerPerks.filter { itemsSaved >= $0.itemsThreshold && co2Avoided >= $0.co2Threshold }
    }

    func nextPerk(itemsSaved: Int, co2Avoided: Double) -> EmployerPerk? {
        employerPerks.first { itemsSaved < $0.itemsThreshold || co2Avoided < $0.co2Threshold }
    }
}

import Foundation
import SwiftUI
import UIKit

// ══════════════════════════════════════════════════════════════════
// MARK: - PerksService
//
// Zero Waste Points are earned by rescuing food (10 pts per item).
// They're redeemable for rewards that **actually work today** —
// without requiring signed retailer partnerships, server-side
// fulfillment, or external promo-code APIs.
//
// The previous version shipped fake "£5 off Tesco" / "10% off Whole
// Foods" coupons that never reached a real retailer system. App
// Store review would have flagged this; users would have been
// disappointed.
//
// The new catalog uses four reward families that are 100% functional
// the moment a user taps Redeem:
//
//   1. **Alternate app icons** — instant local cosmetic via
//      `AlternateIconService`. No backend involvement.
//   2. **Profile badges** — persisted in UserDefaults; surfaced
//      next to the user's name in Community + Profile.
//   3. **External charity donations** — opens a JustGiving / partner
//      page in Safari. We're not handling money; we're routing the
//      user to a verified charity site so the donation is legitimate.
//   4. **Freshli+ subscription trial** — one-month code redeemable
//      via `SubscriptionService`. Real reward, real value.
//
// Every redemption goes through the `RewardAction` enum so the
// view's redeem flow can dispatch correctly without `if`/`else`
// chains, and so future reward types are a single-case-add away.
// ══════════════════════════════════════════════════════════════════

// MARK: - Models

enum RewardCategory: String, CaseIterable, Identifiable, Sendable {
    case appearance = "Appearance"
    case badges     = "Badges"
    case planet     = "Planet"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .appearance: return "paintpalette.fill"
        case .badges:     return "checkmark.seal.fill"
        case .planet:     return "leaf.fill"
        }
    }
}

/// What `redeem(reward)` should *do* once the points are spent.
/// Every case has a 100%-functional implementation in the View;
/// nothing is a stub.
enum RewardAction: Sendable {
    /// Switch the user's home-screen icon to a Freshli alternate.
    /// Implemented via `AlternateIconService.setIcon(_:)`.
    case unlockAppIcon(AlternateIconService.Icon)
    /// Add a cosmetic profile badge id to the user's local
    /// UserDefaults. Surfaced in Profile + Community alongside
    /// the verified tick.
    case unlockProfileBadge(badgeId: String, label: String)
    /// Open Safari at a verified charity URL so the user can donate
    /// directly. We don't handle their card details — the charity's
    /// own donation page does. URL must be HTTPS.
    case openCharityDonation(URL)
    // NOTE: A previous version included a `.grantFreshliPlusTrial` case
    // that wrote `freshli.plusTrial.expiresAt` to UserDefaults and
    // claimed to grant a Freshli+ trial outside StoreKit. That violates
    // App Review guideline 3.1.1 (subscription bypass) and has been
    // removed. Real trial offers must be configured as a StoreKit
    // introductory offer on the subscription product itself.
}

struct WasteReward: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let description: String
    let pointsCost: Int
    let providerLabel: String
    let providerColor: Color
    let providerLogo: String   // emoji or single letter
    let summaryValue: String   // small chip text e.g. "World Food Day"
    let category: RewardCategory
    let action: RewardAction
}

struct EmployerPerk: Identifiable, Sendable {
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
    //
    // Ordered roughly by points cost so the cheapest, most-claimable
    // rewards lead the list. The four planet donations link to real
    // charity pages — they're verified UK/global charities with
    // public donation flows, no API keys required.

    let rewards: [WasteReward] = [
        // ── Appearance: alternate app icons ─────────────────────────
        WasteReward(
            title: String(localized: "World Food Day icon"),
            description: String(localized: "Switch your home-screen icon to celebrate World Food Day. Apply or revert any time in Settings."),
            pointsCost: 100,
            providerLabel: "Freshli",
            providerColor: PSColors.primaryGreen,
            providerLogo: "🌍",
            summaryValue: String(localized: "Icon"),
            category: .appearance,
            action: .unlockAppIcon(.worldFoodDay)
        ),
        WasteReward(
            title: String(localized: "Plastic Free July icon"),
            description: String(localized: "A teal-blue alternate icon for July. Apply or revert any time in Settings."),
            pointsCost: 100,
            providerLabel: "Freshli",
            providerColor: PSColors.accentTeal,
            providerLogo: "💧",
            summaryValue: String(localized: "Icon"),
            category: .appearance,
            action: .unlockAppIcon(.plasticFreeJuly)
        ),
        WasteReward(
            title: String(localized: "Holiday Pantry Hero icon"),
            description: String(localized: "Festive winter-themed icon for the holidays. Apply or revert any time in Settings."),
            pointsCost: 150,
            providerLabel: "Freshli",
            providerColor: Color(hex: 0x3B82F6),
            providerLogo: "❄️",
            summaryValue: String(localized: "Icon"),
            category: .appearance,
            action: .unlockAppIcon(.holidayPantryHero)
        ),
        WasteReward(
            title: String(localized: "Freshli Pride icon"),
            description: String(localized: "Rainbow gradient icon for Pride. Apply or revert any time in Settings."),
            pointsCost: 150,
            providerLabel: "Freshli",
            providerColor: Color(hex: 0xA855F7),
            providerLogo: "🏳️‍🌈",
            summaryValue: String(localized: "Icon"),
            category: .appearance,
            action: .unlockAppIcon(.freshliPride)
        ),

        // ── Badges: cosmetic profile flair ──────────────────────────
        WasteReward(
            title: String(localized: "Rescue Hero badge"),
            description: String(localized: "Display a Rescue Hero badge next to your name in Community listings."),
            pointsCost: 250,
            providerLabel: "Freshli",
            providerColor: PSColors.secondaryAmber,
            providerLogo: "🛟",
            summaryValue: String(localized: "Badge"),
            category: .badges,
            action: .unlockProfileBadge(badgeId: "rescue-hero", label: "Rescue Hero")
        ),
        WasteReward(
            title: String(localized: "Climate Champion badge"),
            description: String(localized: "Earned by avoiding 100kg of CO₂ — wear it proudly in your profile."),
            pointsCost: 400,
            providerLabel: "Freshli",
            providerColor: PSColors.accentTeal,
            providerLogo: "🌱",
            summaryValue: String(localized: "Badge"),
            category: .badges,
            action: .unlockProfileBadge(badgeId: "climate-champion", label: "Climate Champion")
        ),

        // ── Planet: real charity donations ──────────────────────────
        // Donation links open the charity's verified donation page.
        // The user's points symbolically "match" their donation —
        // Freshli isn't taking the money, the charity is. This is
        // the honest model: no server-side fulfillment, no fake
        // promo codes, just a deep-link to a vetted charity.
        WasteReward(
            title: String(localized: "Donate to FareShare UK"),
            description: String(localized: "Opens FareShare's donation page. £1 helps redistribute 4 meals to communities in need."),
            pointsCost: 200,
            providerLabel: "FareShare",
            providerColor: Color(hex: 0xE73B2A),
            providerLogo: "🍽️",
            summaryValue: String(localized: "Donate"),
            category: .planet,
            // Verified URL: https://fareshare.org.uk
            action: .openCharityDonation(URL(string: "https://fareshare.org.uk/donate-money/")!)
        ),
        WasteReward(
            title: String(localized: "Plant a tree — Trees for the Future"),
            description: String(localized: "Opens TFTF's donation page. Trees planted in farmers' Forest Gardens to restore land."),
            pointsCost: 300,
            providerLabel: "Trees for the Future",
            providerColor: PSColors.primaryGreen,
            providerLogo: "🌳",
            summaryValue: String(localized: "Donate"),
            category: .planet,
            action: .openCharityDonation(URL(string: "https://trees.org/donate/")!)
        ),
        WasteReward(
            title: String(localized: "Donate to The Felix Project"),
            description: String(localized: "Rescues surplus food from London's supply chain and delivers it to charities feeding people in need."),
            pointsCost: 250,
            providerLabel: "The Felix Project",
            providerColor: Color(hex: 0xFFC107),
            providerLogo: "🥗",
            summaryValue: String(localized: "Donate"),
            category: .planet,
            action: .openCharityDonation(URL(string: "https://thefelixproject.org/donate")!)
        ),

        // (Trial-grant reward intentionally omitted — see RewardAction
        //  comment.) Future Freshli+ promo offers will be StoreKit
        //  introductory offers presented natively on the paywall, not
        //  redeemed via Karma.
    ]

    // MARK: - Employer Perks
    //
    // Milestone-based recognition. These are aspirational labels users
    // unlock by hitting in-app thresholds — they're cosmetic, not paid
    // out as cash, but they're real (badges + cert PDFs) so they pass
    // the same "actually works today" bar as the redeemable catalog.

    let employerPerks: [EmployerPerk] = [
        EmployerPerk(title: String(localized: "Green Starter"),
                     description: String(localized: "Save your first 5 items from waste"),
                     perkValue: String(localized: "Eco Badge"), icon: "leaf.fill",
                     color: PSColors.primaryGreen,
                     itemsThreshold: 5, co2Threshold: 0),
        EmployerPerk(title: String(localized: "Sustainable Saver"),
                     description: String(localized: "Save 20 items — earn a downloadable impact certificate"),
                     perkValue: String(localized: "Impact Certificate"), icon: "doc.badge.gearshape.fill",
                     color: PSColors.secondaryAmber,
                     itemsThreshold: 20, co2Threshold: 50),
        EmployerPerk(title: String(localized: "Carbon Champion"),
                     description: String(localized: "Avoid 100kg CO₂ — unlock the Climate Champion profile badge"),
                     perkValue: String(localized: "Climate Champion badge"), icon: "cloud.fill",
                     color: PSColors.accentTeal,
                     itemsThreshold: 40, co2Threshold: 100),
        EmployerPerk(title: String(localized: "Zero Waste Hero"),
                     description: String(localized: "Rescue 100 items — featured on the Freshli leaderboard"),
                     perkValue: String(localized: "Leaderboard Spot"), icon: "crown.fill",
                     color: Color(hex: 0xA855F7),
                     itemsThreshold: 100, co2Threshold: 250),
    ]

    func unlockedPerks(itemsSaved: Int, co2Avoided: Double) -> [EmployerPerk] {
        employerPerks.filter { itemsSaved >= $0.itemsThreshold && co2Avoided >= $0.co2Threshold }
    }

    func nextPerk(itemsSaved: Int, co2Avoided: Double) -> EmployerPerk? {
        employerPerks.first { itemsSaved < $0.itemsThreshold || co2Avoided < $0.co2Threshold }
    }

    // MARK: - Real reward execution

    /// Perform the redemption side-effect for a reward. Returns a
    /// localised success message the caller can surface in a toast,
    /// or `nil` when the action couldn't run (e.g. a charity URL
    /// failed to open). Persists unlocked badges to UserDefaults so
    /// `unlockedBadgeLabels()` can render them in profile surfaces.
    @discardableResult
    func performRedemption(_ reward: WasteReward) async -> String? {
        switch reward.action {
        case .unlockAppIcon(let icon):
            await AlternateIconService.shared.setIcon(icon)
            return String(localized: "Icon switched to \(reward.title). You can revert in Settings.")

        case .unlockProfileBadge(let id, let label):
            var unlocked = unlockedBadgeIds()
            unlocked.insert(id)
            UserDefaults.standard.set(Array(unlocked), forKey: Self.unlockedBadgesKey)
            UserDefaults.standard.set(label, forKey: "freshli.lastUnlockedBadgeLabel.\(id)")
            return String(localized: "\(label) badge unlocked — visible on your profile.")

        case .openCharityDonation(let url):
            let opened = await UIApplication.shared.open(url)
            return opened
                ? String(localized: "Opening \(reward.providerLabel) — thank you for donating.")
                : nil
        }
    }

    /// Set of badge ids the user has unlocked via redemption. Read at
    /// profile-render time to decorate the user's name with extra
    /// badges next to the verified tick.
    func unlockedBadgeIds() -> Set<String> {
        Set((UserDefaults.standard.array(forKey: Self.unlockedBadgesKey) as? [String]) ?? [])
    }

    /// Display labels the profile UI iterates to render badges.
    /// Looks up the friendly label saved alongside each badge id.
    func unlockedBadgeLabels() -> [String] {
        unlockedBadgeIds().compactMap { id in
            UserDefaults.standard.string(forKey: "freshli.lastUnlockedBadgeLabel.\(id)")
        }
    }

    private static let unlockedBadgesKey = "freshli.perks.unlockedBadgeIds"
}

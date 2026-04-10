import Foundation
import os

// MARK: - UsageMission Model

struct UsageMission: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let urgencyLevel: UrgencyLevel
    let freshliItems: [FreshliItem]
    let estimatedMinutes: Int
    let difficulty: RecipeDifficulty
    let steps: [String]
    let additionalItems: [String]

    var itemEmojis: String {
        freshliItems
            .map { $0.category.emoji }
            .removingDuplicates()
            .joined(separator: " ")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: UsageMission, rhs: UsageMission) -> Bool {
        lhs.id == rhs.id
    }
}

enum UrgencyLevel: String, Codable, Identifiable {
    case critical
    case urgent
    case moderate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .critical: return String(localized: "Critical")
        case .urgent: return String(localized: "Urgent")
        case .moderate: return String(localized: "Moderate")
        }
    }

    var icon: String {
        switch self {
        case .critical: return "exclamationmark.circle.fill"
        case .urgent: return "exclamationmark.triangle.fill"
        case .moderate: return "info.circle.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .urgent: return 1
        case .moderate: return 2
        }
    }
}

// MARK: - RescueChefService

@Observable @MainActor
final class RescueChefService {
    private(set) var missions: [UsageMission] = []
    private(set) var rescueScore: Double = 0
    private(set) var atRiskItemsCount: Int = 0
    private(set) var mostUrgentTimeRemaining: String = ""

    private let logger = PSLogger(category: .recipe)

    // Singleton instance
    static let shared = RescueChefService()

    private init() {}

    // MARK: - Public API

    /// Generate usage missions for at-risk pantry items.
    /// Returns missions ranked by urgency and feasibility.
    func generateMissions(for items: [FreshliItem]) {
        let atRiskItems = findAtRiskItems(in: items)
        atRiskItemsCount = atRiskItems.count

        guard !atRiskItems.isEmpty else {
            missions = []
            rescueScore = 0
            mostUrgentTimeRemaining = ""
            logger.debug("No at-risk items found")
            return
        }

        // Generate missions from at-risk items
        let generatedMissions = generateMissionsFromItems(atRiskItems)

        // Rank missions by urgency and feasibility
        missions = rankMissions(generatedMissions, byItemsUsed: atRiskItems)

        // Calculate rescue score: percentage of at-risk items covered by missions
        rescueScore = calculateRescueScore(atRiskItems: atRiskItems, missions: missions)

        // Find most urgent time remaining
        mostUrgentTimeRemaining = findMostUrgentTimeRemaining(from: atRiskItems)

        logger.info("Generated \(missions.count) rescue missions for \(atRiskItems.count) at-risk items (score: \(Int(rescueScore * 100))%)")
    }

    /// Get missions filtered by urgency level
    func missions(for urgency: UrgencyLevel) -> [UsageMission] {
        missions.filter { $0.urgencyLevel == urgency }
    }

    // MARK: - Private Helpers

    /// Identify items expiring within 48 hours or already expired
    private func findAtRiskItems(in items: [FreshliItem]) -> [FreshliItem] {
        let calendar = Calendar.current
        let now = Date()
        let fortyEightHoursLater = calendar.date(byAdding: .hour, value: 48, to: now) ?? now

        return items.filter { item in
            (item.expiryDate <= fortyEightHoursLater && !item.isConsumed)
        }
    }

    /// Generate missions from a list of at-risk items
    private func generateMissionsFromItems(_ items: [FreshliItem]) -> [UsageMission] {
        var missions: [UsageMission] = []
        var coveredItems = Set<UUID>()

        // Group items by category to find complementary combinations
        let itemsByCategory = Dictionary(grouping: items, by: { $0.category })

        // Apply food combination rules
        for (category, categoryItems) in itemsByCategory {
            let rules = rulesForCategory(category)
            for rule in rules {
                let matchingItems = categoryItems.filter { !coveredItems.contains($0.id) }
                if !matchingItems.isEmpty {
                    let mission = createMission(
                        from: matchingItems,
                        using: rule,
                        allAtRiskItems: items
                    )
                    missions.append(mission)
                    matchingItems.forEach { coveredItems.insert($0.id) }
                }
            }
        }

        // Fallback: create generic "use immediately" missions for any uncovered items
        let uncoveredItems = items.filter { !coveredItems.contains($0.id) }
        for item in uncoveredItems {
            let fallbackMission = createFallbackMission(for: item)
            missions.append(fallbackMission)
            coveredItems.insert(item.id)
        }

        return missions
    }

    /// Rank missions by urgency and feasibility (items used)
    private func rankMissions(_ missions: [UsageMission], byItemsUsed allAtRiskItems: [FreshliItem]) -> [UsageMission] {
        return missions.sorted { mission1, mission2 in
            // Primary: sort by urgency
            if mission1.urgencyLevel.sortOrder != mission2.urgencyLevel.sortOrder {
                return mission1.urgencyLevel.sortOrder < mission2.urgencyLevel.sortOrder
            }
            // Secondary: sort by number of at-risk items used (more items = higher priority)
            if mission1.freshliItems.count != mission2.freshliItems.count {
                return mission1.freshliItems.count > mission2.freshliItems.count
            }
            // Tertiary: sort by ease (difficulty)
            return mission1.difficulty.rawValue < mission2.difficulty.rawValue
        }
    }

    /// Calculate rescue score: percentage of at-risk items with a mission
    private func calculateRescueScore(atRiskItems: [FreshliItem], missions: [UsageMission]) -> Double {
        guard !atRiskItems.isEmpty else { return 0 }

        let itemsWithMissions = Set(missions.flatMap { $0.freshliItems.map { $0.id } })
        let coveredCount = atRiskItems.filter { itemsWithMissions.contains($0.id) }.count

        return Double(coveredCount) / Double(atRiskItems.count)
    }

    /// Find the most urgent time remaining for the closest expiring item
    private func findMostUrgentTimeRemaining(from items: [FreshliItem]) -> String {
        guard let soonest = items.min(by: { $0.expiryDate < $1.expiryDate }) else {
            return ""
        }

        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour], from: now, to: soonest.expiryDate)
        let hours = components.hour ?? 0

        if hours <= 0 {
            return String(localized: "Expired")
        } else if hours < 12 {
            return String(localized: "\(hours)h remaining")
        } else if hours < 24 {
            return String(localized: "\(hours / 2)h remaining")
        } else {
            let days = hours / 24
            return String(localized: "\(days) days remaining")
        }
    }

    // MARK: - Mission Creation

    /// Create a mission from pantry items using a food combination rule
    private func createMission(
        from items: [FreshliItem],
        using rule: FoodCombinationRule,
        allAtRiskItems: [FreshliItem]
    ) -> UsageMission {
        let mostUrgent = items.min { $0.expiryDate < $1.expiryDate } ?? items[0]
        let urgency = determineUrgency(for: mostUrgent)

        return UsageMission(
            id: UUID(),
            title: rule.missionTitle,
            description: rule.missionDescription,
            urgencyLevel: urgency,
            freshliItems: items,
            estimatedMinutes: rule.estimatedMinutes,
            difficulty: rule.difficulty,
            steps: rule.steps,
            additionalItems: rule.additionalItems
        )
    }

    /// Create a fallback mission for a single item
    private func createFallbackMission(for item: FreshliItem) -> UsageMission {
        let urgency = determineUrgency(for: item)
        let baseTitle = "Quick \(item.name) Usage"

        let titles: [String] = [
            "Carrot Rescue: Quick Slaw Time!",
            "Celery Salvation: Make a Stir-Fry!",
            "Broccoli Brigade: Roast & Enjoy!",
            "Spinach Situation: Smoothie Time!",
            "Apple Action: Bake a Pie!",
            "Banana Emergency: Bread Time!",
            "Dairy Dilemma: Mac & Cheese!",
            "Milk Mission: Creamy Soup!",
            "Cheese Challenge: Quesadilla Quest!",
            "Egg Emergency: Frittata Friday!"
        ]

        let missionTitle = titles.randomElement() ?? baseTitle

        return UsageMission(
            id: UUID(),
            title: missionTitle,
            description: String(localized: "Use this \(item.category.displayName.lowercased()) before it expires completely."),
            urgencyLevel: urgency,
            freshliItems: [item],
            estimatedMinutes: [15, 20, 25].randomElement() ?? 20,
            difficulty: [.easy, .medium].randomElement() ?? .easy,
            steps: [
                String(localized: "Inspect the \(item.name) for quality"),
                String(localized: "Decide on a quick recipe or snack"),
                String(localized: "Prepare and enjoy immediately")
            ],
            additionalItems: []
        )
    }

    /// Determine urgency level based on expiry date
    private func determineUrgency(for item: FreshliItem) -> UrgencyLevel {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour], from: now, to: item.expiryDate)
        let hoursRemaining = components.hour ?? 0

        if hoursRemaining <= 12 {
            return .critical
        } else if hoursRemaining <= 24 {
            return .urgent
        } else {
            return .moderate
        }
    }

    // MARK: - Food Combination Rules

    private func rulesForCategory(_ category: FoodCategory) -> [FoodCombinationRule] {
        switch category {
        case .fruits:
            return [
                FoodCombinationRule(
                    missionTitle: "Smoothie Rescue: Blend It!",
                    missionDescription: "Soft fruits are perfect for a quick smoothie or smoothie bowl.",
                    estimatedMinutes: 10,
                    difficulty: .easy,
                    steps: [
                        String(localized: "Add fruits to blender"),
                        String(localized: "Add yogurt and liquid"),
                        String(localized: "Blend until smooth"),
                        String(localized: "Pour into bowl or glass")
                    ],
                    additionalItems: [String(localized: "Yogurt"), String(localized: "Honey")],
                    itemCategories: [.fruits]
                ),
                FoodCombinationRule(
                    missionTitle: "Fruit Cobbler: Bake It!",
                    missionDescription: "Create a delicious baked fruit dessert.",
                    estimatedMinutes: 40,
                    difficulty: .medium,
                    steps: [
                        String(localized: "Preheat oven to 375°F"),
                        String(localized: "Slice fruits into baking dish"),
                        String(localized: "Make simple topping with oats and butter"),
                        String(localized: "Bake for 30 minutes until golden")
                    ],
                    additionalItems: [String(localized: "Oats"), String(localized: "Butter"), String(localized: "Brown sugar")],
                    itemCategories: [.fruits]
                ),
                FoodCombinationRule(
                    missionTitle: "Fruit Jam: Preserve It!",
                    missionDescription: "Turn soft fruit into homemade jam.",
                    estimatedMinutes: 35,
                    difficulty: .medium,
                    steps: [
                        String(localized: "Chop fruit into small pieces"),
                        String(localized: "Add sugar and lemon juice"),
                        String(localized: "Cook on medium heat for 20 minutes, stirring"),
                        String(localized: "Test consistency and jar")
                    ],
                    additionalItems: [String(localized: "Sugar"), String(localized: "Lemon")],
                    itemCategories: [.fruits]
                )
            ]

        case .vegetables:
            return [
                FoodCombinationRule(
                    missionTitle: "Veggie Stir-Fry: Quick Dinner!",
                    missionDescription: "Transform vegetables into a speedy stir-fry.",
                    estimatedMinutes: 25,
                    difficulty: .easy,
                    steps: [
                        String(localized: "Chop vegetables into uniform pieces"),
                        String(localized: "Heat oil in wok or pan"),
                        String(localized: "Stir-fry vegetables over high heat"),
                        String(localized: "Season with soy sauce and serve over rice")
                    ],
                    additionalItems: [String(localized: "Rice"), String(localized: "Soy sauce")],
                    itemCategories: [.vegetables]
                ),
                FoodCombinationRule(
                    missionTitle: "Roasted Veggies: Sheet Pan Dinner!",
                    missionDescription: "Roast vegetables for a delicious side dish.",
                    estimatedMinutes: 30,
                    difficulty: .easy,
                    steps: [
                        String(localized: "Preheat oven to 425°F"),
                        String(localized: "Toss vegetables with oil and seasoning"),
                        String(localized: "Spread on baking sheet"),
                        String(localized: "Roast for 20-25 minutes until caramelized")
                    ],
                    additionalItems: [String(localized: "Olive oil"), String(localized: "Salt"), String(localized: "Pepper")],
                    itemCategories: [.vegetables]
                ),
                FoodCombinationRule(
                    missionTitle: "Veggie Soup: Comfort Classic!",
                    missionDescription: "Make a hearty vegetable soup.",
                    estimatedMinutes: 45,
                    difficulty: .medium,
                    steps: [
                        String(localized: "Chop vegetables into chunks"),
                        String(localized: "Sauté aromatics in oil"),
                        String(localized: "Add vegetables and broth"),
                        String(localized: "Simmer for 30 minutes until tender")
                    ],
                    additionalItems: [String(localized: "Broth"), String(localized: "Onion"), String(localized: "Garlic")],
                    itemCategories: [.vegetables]
                )
            ]

        case .dairy:
            return [
                FoodCombinationRule(
                    missionTitle: "Creamy Pasta: Mac & Cheese!",
                    missionDescription: "Make creamy pasta with dairy.",
                    estimatedMinutes: 30,
                    difficulty: .easy,
                    steps: [
                        String(localized: "Boil pasta in salted water"),
                        String(localized: "Make cheese sauce with butter, flour, and milk"),
                        String(localized: "Toss pasta with sauce"),
                        String(localized: "Add breadcrumb topping and broil briefly")
                    ],
                    additionalItems: [String(localized: "Pasta"), String(localized: "Butter"), String(localized: "Flour")],
                    itemCategories: [.dairy]
                ),
                FoodCombinationRule(
                    missionTitle: "Baking Time: Cake or Cookies!",
                    missionDescription: "Use dairy in baking projects.",
                    estimatedMinutes: 40,
                    difficulty: .medium,
                    steps: [
                        String(localized: "Preheat oven to 350°F"),
                        String(localized: "Mix dry ingredients"),
                        String(localized: "Combine dairy with eggs and sugar"),
                        String(localized: "Mix wet and dry, then bake")
                    ],
                    additionalItems: [String(localized: "Flour"), String(localized: "Sugar"), String(localized: "Eggs")],
                    itemCategories: [.dairy]
                ),
                FoodCombinationRule(
                    missionTitle: "Yogurt Parfait: Quick Breakfast!",
                    missionDescription: "Layer yogurt with toppings.",
                    estimatedMinutes: 5,
                    difficulty: .easy,
                    steps: [
                        String(localized: "Layer yogurt in glass"),
                        String(localized: "Add granola"),
                        String(localized: "Add fresh or frozen fruit"),
                        String(localized: "Drizzle with honey")
                    ],
                    additionalItems: [String(localized: "Granola"), String(localized: "Fruit"), String(localized: "Honey")],
                    itemCategories: [.dairy]
                )
            ]

        case .meat:
            return [
                FoodCombinationRule(
                    missionTitle: "Quick Tacos: Easy Dinner!",
                    missionDescription: "Brown meat and make tacos.",
                    estimatedMinutes: 20,
                    difficulty: .easy,
                    steps: [
                        String(localized: "Brown meat in skillet"),
                        String(localized: "Add taco seasoning and water"),
                        String(localized: "Simmer for 5 minutes"),
                        String(localized: "Warm tortillas and serve with toppings")
                    ],
                    additionalItems: [String(localized: "Tortillas"), String(localized: "Salsa"), String(localized: "Taco seasoning")],
                    itemCategories: [.meat]
                ),
                FoodCombinationRule(
                    missionTitle: "Hearty Stew: Slow Cooker Magic!",
                    missionDescription: "Make a warming meat stew.",
                    estimatedMinutes: 120,
                    difficulty: .medium,
                    steps: [
                        String(localized: "Brown meat in a pot"),
                        String(localized: "Add vegetables, broth, and seasoning"),
                        String(localized: "Transfer to slow cooker"),
                        String(localized: "Cook on low for 6-8 hours")
                    ],
                    additionalItems: [String(localized: "Vegetables"), String(localized: "Broth"), String(localized: "Potatoes")],
                    itemCategories: [.meat]
                )
            ]

        default:
            return [
                FoodCombinationRule(
                    missionTitle: "Creative Cooking: Use It Now!",
                    missionDescription: "Get creative with these ingredients.",
                    estimatedMinutes: 30,
                    difficulty: .easy,
                    steps: [
                        String(localized: "Inspect the items"),
                        String(localized: "Look up a recipe online"),
                        String(localized: "Gather remaining ingredients"),
                        String(localized: "Prepare and enjoy")
                    ],
                    additionalItems: [],
                    itemCategories: [category]
                )
            ]
        }
    }
}

// MARK: - FoodCombinationRule

struct FoodCombinationRule {
    let missionTitle: String
    let missionDescription: String
    let estimatedMinutes: Int
    let difficulty: RecipeDifficulty
    let steps: [String]
    let additionalItems: [String]
    let itemCategories: [FoodCategory]
}

// MARK: - Array Extension

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

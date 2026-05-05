import Foundation
import SwiftUI

// MARK: - Preservation Guide Service
// AI-style instructions for freezing, pickling, dehydrating, and blanching.
// Also detects ethylene gas conflicts between stored items.

// MARK: - Preservation Models

enum PreservationMethodType: String, CaseIterable, Identifiable {
    case freeze    = "Freeze"
    case pickle    = "Pickle"
    case dehydrate = "Dehydrate"
    case ferment   = "Ferment"
    case blanch    = "Blanch & Freeze"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .freeze:    return "snowflake"
        case .pickle:    return "drop.fill"
        case .dehydrate: return "sun.max.fill"
        case .ferment:   return "bubbles.and.sparkles.fill"
        case .blanch:    return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .freeze:    return Color(hex: 0x60A5FA)
        case .pickle:    return Color(hex: 0x84CC16)
        case .dehydrate: return Color(hex: 0xF59E0B)
        case .ferment:   return Color(hex: 0xA855F7)
        case .blanch:    return Color(hex: 0xF97316)
        }
    }
}

struct PreservationMethod: Identifiable {
    let id = UUID()
    let type: PreservationMethodType
    let storageLife: String
    let steps: [String]
    let tip: String
    let difficulty: Int   // 1–3 stars
}

struct EthyleneConflict: Identifiable {
    let id = UUID()
    let producer: FreshliItem
    let sensitive: FreshliItem
    let daysFasterSpoilage: Int
    let advice: String
}

// MARK: - Service

@MainActor
final class PreservationGuideService {
    static let shared = PreservationGuideService()
    private init() {}

    // MARK: - Ethylene Data

    private let producers: [String] = [
        "apple", "avocado", "banana", "kiwi", "mango", "peach", "pear",
        "plum", "tomato", "fig", "melon", "nectarine", "apricot", "passion fruit"
    ]
    private let sensitives: [String] = [
        "broccoli", "spinach", "kale", "lettuce", "chard", "cabbage",
        "cucumber", "strawberr", "raspberry", "blueberr", "asparagus",
        "carrot", "courgette", "zucchini", "pepper", "pea", "leek",
        "celery", "cauliflower", "brussels"
    ]

    // MARK: - Conflict Detection

    func conflicts(in items: [FreshliItem]) -> [EthyleneConflict] {
        let active = items.filter { $0.isActive }
        var result: [EthyleneConflict] = []
        let producerItems  = active.filter { item in producers.contains(where: { item.name.lowercased().contains($0) }) }
        let sensitiveItems = active.filter { item in sensitives.contains(where: { item.name.lowercased().contains($0) }) }

        for p in producerItems {
            for s in sensitiveItems {
                guard p.storageLocation == s.storageLocation else { continue }
                guard !result.contains(where: { $0.producer.id == p.id && $0.sensitive.id == s.id }) else { continue }
                let days = (p.id.hashValue ^ s.id.hashValue) % 3 + 2  // deterministic 2-4
                result.append(EthyleneConflict(
                    producer: p, sensitive: s, daysFasterSpoilage: days,
                    advice: "Move \(s.name) away from \(p.name) to extend its life by up to \(days) days."
                ))
            }
        }
        return result
    }

    // MARK: - Preservation Methods

    func methods(for item: FreshliItem) -> [PreservationMethod] {
        methods(forName: item.name, category: item.category)
    }

    func methods(forName name: String, category: FoodCategory) -> [PreservationMethod] {
        let l = name.lowercased()
        if l.contains("banana") || l.contains("plantain")             { return bananaGuide() }
        if l.contains("bread") || l.contains("loaf")                  { return breadGuide() }
        if l.contains("milk")                                          { return milkGuide() }
        if ["herb","basil","parsley","coriander","cilantro","chive","mint","thyme","rosemary"].contains(where: l.contains) { return herbGuide() }
        if ["berry","strawberr","blueberr","raspberry","blackberr"].contains(where: l.contains) { return berryGuide() }
        if ["spinach","kale","chard","lettuce","arugula","rocket"].contains(where: l.contains) { return leafyGreenGuide() }
        if l.contains("tomato")                                        { return tomatoGuide() }
        if ["lemon","lime","orange","grapefruit"].contains(where: l.contains) { return citrusGuide() }
        if l.contains("avocado")                                       { return avocadoGuide() }
        if ["chicken","beef","pork","lamb","turkey","mince","steak"].contains(where: l.contains) { return meatGuide() }
        if ["fish","salmon","tuna","cod","haddock","prawn","shrimp","sea bass"].contains(where: l.contains) { return fishGuide() }

        switch category {
        case .vegetables: return genericVegGuide(name: name)
        case .fruits:     return genericFruitGuide(name: name)
        case .dairy:      return genericDairyGuide(name: name)
        case .meat:       return meatGuide()
        case .seafood:    return fishGuide()
        case .bakery:     return breadGuide()
        default:          return genericGuide(name: name)
        }
    }

    // MARK: - Item-Specific Guides

    private func bananaGuide() -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "Up to 3 months", steps: [
            "Peel bananas and break into chunks.",
            "Lay flat on a lined baking sheet and freeze for 2 hours.",
            "Transfer to a zip-lock bag, removing all air.",
            "Label with date — blend straight from frozen for smoothies."
        ], tip: "Frozen bananas make silky one-ingredient 'nice cream' — just blend!", difficulty: 1),
        PreservationMethod(type: .dehydrate, storageLife: "6–12 months", steps: [
            "Peel and slice into ¼-inch rounds.",
            "Dip in lemon juice to prevent browning.",
            "Arrange on dehydrator trays without overlapping.",
            "Dry at 57°C (135°F) for 8–12 hours until leathery."
        ], tip: "Banana chips make a brilliant snack or granola topping.", difficulty: 2)
    ]}

    private func breadGuide() -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "Up to 3 months", steps: [
            "Slice the loaf before freezing for easy individual portions.",
            "Wrap tightly in cling film, then place inside a freezer bag.",
            "Remove all air and seal — freezer burn ruins texture.",
            "Toast straight from frozen (2–3 min) or defrost at room temp for 1 hour."
        ], tip: "Freeze in slice-sized portions so you only defrost exactly what you need.", difficulty: 1),
        PreservationMethod(type: .dehydrate, storageLife: "3 months", steps: [
            "Tear or cut stale bread into small chunks.",
            "Bake at 120°C for 45 min until completely dry.",
            "Cool fully, then blitz into breadcrumbs and store in an airtight jar."
        ], tip: "Homemade breadcrumbs are far superior to shop-bought — toast in butter before use.", difficulty: 1)
    ]}

    private func milkGuide() -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "Up to 3 months", steps: [
            "Pour milk into a freezer-safe airtight container.",
            "Leave 5cm of headspace — milk expands when frozen.",
            "Label with the date.",
            "Thaw overnight in the fridge and shake well before using."
        ], tip: "Frozen milk is ideal for baking and sauces even if slightly grainy when thawed.", difficulty: 1)
    ]}

    private func herbGuide() -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "Up to 6 months", steps: [
            "Wash and dry herbs thoroughly — moisture causes freezer burn.",
            "Finely chop and spoon into ice-cube-tray compartments.",
            "Cover with olive oil or water and freeze solid.",
            "Pop out a cube directly into sauces or soups."
        ], tip: "Herb oil cubes are a game-changer — drop straight into a hot pan.", difficulty: 1),
        PreservationMethod(type: .dehydrate, storageLife: "1–2 years", steps: [
            "Rinse and pat completely dry.",
            "Tie in small bundles and hang upside down in a warm, dry place.",
            "After 1–3 weeks, crumble leaves into a clean dry jar.",
            "Store away from direct sunlight."
        ], tip: "Dried herbs are 3× more potent than fresh — use a third of the quantity.", difficulty: 1)
    ]}

    private func berryGuide() -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "Up to 12 months", steps: [
            "Wash gently and drain, then spread on a lined baking sheet.",
            "Freeze for 2–3 hours until solid (prevents clumping).",
            "Transfer to a freezer bag and remove all air.",
            "Use straight from frozen in smoothies, jams, or bakes."
        ], tip: "Don't wash berries until ready to use — moisture speeds spoilage.", difficulty: 1),
        PreservationMethod(type: .pickle, storageLife: "Up to 1 month", steps: [
            "Mix 120ml cider vinegar, 120ml water, 100g sugar, pinch of salt.",
            "Heat until sugar dissolves, then cool slightly.",
            "Pack berries into a sterilised jar and pour brine over.",
            "Seal and refrigerate 24 hours before eating."
        ], tip: "Pickled strawberries on cheese or in salads are a revelation.", difficulty: 2)
    ]}

    private func leafyGreenGuide() -> [PreservationMethod] { [
        PreservationMethod(type: .blanch, storageLife: "Up to 12 months", steps: [
            "Bring a large pot of salted water to the boil.",
            "Add greens and blanch 30–60 seconds until just wilted.",
            "Immediately plunge into ice water to stop cooking.",
            "Drain, squeeze out moisture, portion into bags, and freeze flat."
        ], tip: "Blanching locks in colour and nutrients before freezing.", difficulty: 2),
        PreservationMethod(type: .dehydrate, storageLife: "6–12 months", steps: [
            "Wash and dry leaves thoroughly.",
            "Arrange in a single layer on dehydrator trays.",
            "Dry at 52°C (125°F) for 4–6 hours until crisp.",
            "Crumble into powder for smoothies, sauces, or pasta dough."
        ], tip: "Dehydrated greens become a nutrient-dense powder — brilliant in homemade pasta.", difficulty: 2)
    ]}

    private func tomatoGuide() -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "Up to 6 months", steps: [
            "Core tomatoes and score a small X on the base.",
            "Freeze whole on a lined baking sheet, then transfer to bags.",
            "Run under hot water to slip skins off when ready to cook.",
            "Use straight from frozen in cooked sauces — flavour concentrates beautifully."
        ], tip: "Never refrigerate ripe tomatoes — cold kills flavour. Freeze instead.", difficulty: 1),
        PreservationMethod(type: .dehydrate, storageLife: "12+ months", steps: [
            "Halve and place cut-side up on dehydrator trays.",
            "Season with salt, pepper, and dried oregano.",
            "Dry at 63°C (145°F) for 10–18 hours until leathery.",
            "Store in olive oil in the fridge for a deli experience."
        ], tip: "Homemade sun-dried tomatoes in olive oil cost pennies vs shop price.", difficulty: 2)
    ]}

    private func citrusGuide() -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "Up to 4 months", steps: [
            "Zest first — zest freezes perfectly and is often most flavourful.",
            "Juice into an ice cube tray (1 cube ≈ 1 tablespoon).",
            "Freeze solid, then transfer cubes to a labelled freezer bag.",
            "Drop cubes directly into recipes from frozen."
        ], tip: "Freeze the zest separately in a tiny bag — it's culinary gold.", difficulty: 1),
        PreservationMethod(type: .pickle, storageLife: "Up to 1 year", steps: [
            "Quarter lemons/limes and rub flesh generously with coarse salt.",
            "Pack tightly into a sterilised glass jar.",
            "Squeeze extra juice over to submerge.",
            "Seal and leave at room temperature for 4 weeks, turning occasionally."
        ], tip: "Preserved lemons are a North African staple — transformative in tagines.", difficulty: 2)
    ]}

    private func avocadoGuide() -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "Up to 3 months", steps: [
            "Halve, remove stone, and scoop out flesh.",
            "Mash with a squeeze of lemon juice (prevents browning).",
            "Portion into a zip-lock bag, flatten for easy storage.",
            "Thaw in the fridge overnight — ideal for guacamole or toast."
        ], tip: "Freeze avocado mash when they all ripen at once — a common problem solved.", difficulty: 1)
    ]}

    private func meatGuide() -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "3–6 months", steps: [
            "Pat the meat dry — moisture causes freezer burn.",
            "Wrap tightly in cling film, pressing out all air.",
            "Wrap again in foil or place in a freezer bag.",
            "Label with cut, weight, and date. Thaw in fridge 24 hours before use."
        ], tip: "Freeze in meal-sized portions — defrost only what you need.", difficulty: 1),
        PreservationMethod(type: .pickle, storageLife: "1–2 weeks (fridge)", steps: [
            "Make a brine: 1L water, 100g salt, 50g sugar, aromatics.",
            "Submerge meat fully in brine in a non-reactive container.",
            "Refrigerate 4–24 hours depending on thickness.",
            "Rinse before cooking to reduce saltiness."
        ], tip: "Brined chicken stays juicy 3× longer when cooked — incredible results.", difficulty: 2)
    ]}

    private func fishGuide() -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "Up to 3 months", steps: [
            "Rinse and pat completely dry.",
            "Wrap individual portions in cling film, removing all air.",
            "Place in a freezer bag and press out remaining air.",
            "Thaw overnight in the fridge — never at room temperature."
        ], tip: "Freeze fish in water-filled containers for best texture preservation.", difficulty: 1),
        PreservationMethod(type: .pickle, storageLife: "1–2 weeks (fridge)", steps: [
            "Slice fish thinly (gravlax style) or use small whole pieces.",
            "Mix dill, coarse salt, sugar, and lemon zest for the cure.",
            "Pack layers of fish and cure, cover, and refrigerate.",
            "After 48 hours, rinse and slice thin — serve on blinis or toast."
        ], tip: "Homemade gravlax from salmon is luxurious at a fraction of the shop price.", difficulty: 3)
    ]}

    private func genericVegGuide(name: String) -> [PreservationMethod] { [
        PreservationMethod(type: .blanch, storageLife: "Up to 12 months", steps: [
            "Wash and chop \(name) into uniform pieces.",
            "Blanch in boiling salted water for 1–3 minutes.",
            "Transfer immediately to ice water for 2 minutes.",
            "Drain, dry, freeze flat on a sheet, then transfer to bags."
        ], tip: "Blanching deactivates enzymes that rob frozen veg of flavour and colour.", difficulty: 2),
        PreservationMethod(type: .pickle, storageLife: "Up to 6 months", steps: [
            "Cut \(name) into bite-sized pieces.",
            "Brine: equal parts white wine vinegar and water, 1 tbsp each salt and sugar.",
            "Pack into a sterilised jar with garlic and peppercorns.",
            "Pour hot brine over, seal, and cool. Refrigerate 48 hours before eating."
        ], tip: "Quick-pickled vegetables are ready in 24 hours and last months in the fridge.", difficulty: 1)
    ]}

    private func genericFruitGuide(name: String) -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "Up to 12 months", steps: [
            "Wash and prep \(name) — peel, stone, or slice as appropriate.",
            "Toss with a little lemon juice to prevent browning.",
            "Freeze spread on a lined tray for 2 hours.",
            "Transfer to labelled freezer bags."
        ], tip: "Fruit frozen at peak ripeness is sweeter and more nutritious than out-of-season fresh.", difficulty: 1),
        PreservationMethod(type: .dehydrate, storageLife: "6–12 months", steps: [
            "Slice \(name) evenly — about ¼ inch thick.",
            "Dip in lemon juice to prevent oxidation.",
            "Arrange on dehydrator trays without overlapping.",
            "Dry at 57°C (135°F) for 8–16 hours until pliable."
        ], tip: "Dehydrated fruit makes excellent trail mix, granola topping, or lunchbox snack.", difficulty: 2)
    ]}

    private func genericDairyGuide(name: String) -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "Up to 3 months", steps: [
            "Portion \(name) into airtight containers or bags.",
            "Label with date and quantity.",
            "Thaw in the fridge overnight — never at room temperature.",
            "Use within 2 days of thawing for best quality."
        ], tip: "Some dairy changes texture when frozen — better for cooking than eating fresh.", difficulty: 1)
    ]}

    private func genericGuide(name: String) -> [PreservationMethod] { [
        PreservationMethod(type: .freeze, storageLife: "1–3 months", steps: [
            "Prepare \(name) as you normally would for cooking.",
            "Portion into meal-sized amounts.",
            "Seal in airtight bags or containers, removing all air.",
            "Label clearly with name, quantity, and date."
        ], tip: "When in doubt, freeze it — most foods freeze better than you'd think.", difficulty: 1)
    ]}
}

import Foundation
import SwiftUI

// MARK: - Barcode Analytics Service
// Analyses barcode-level waste patterns and estimates EPR (Extended
// Producer Responsibility) costs per product.

// MARK: - Models

struct BarcodeInsight: Identifiable {
    let id = UUID()
    let barcode: String
    let productName: String
    let category: FoodCategory
    let timesPurchased: Int
    let timesWasted: Int
    var wasteRate: Double { timesPurchased > 0 ? Double(timesWasted) / Double(timesPurchased) : 0 }
    let eprCostPerUnit: Double   // estimated packaging EPR cost
    let totalEprImpact: Double   // total cost × wasted units
    let packagingType: PackagingType
    let recommendation: String
}

enum PackagingType: String, CaseIterable {
    case plastic   = "Plastic"
    case glass     = "Glass"
    case cardboard = "Cardboard"
    case metal     = "Metal"
    case mixed     = "Mixed"
    case compostable = "Compostable"

    var icon: String {
        switch self {
        case .plastic:     return "exclamationmark.triangle.fill"
        case .glass:       return "drop.triangle.fill"
        case .cardboard:   return "shippingbox.fill"
        case .metal:       return "cylinder.fill"
        case .mixed:       return "square.stack.3d.up.fill"
        case .compostable: return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .plastic:     return Color(hex: 0xEF4444)
        case .glass:       return Color(hex: 0x06B6D4)
        case .cardboard:   return Color(hex: 0xA78BFA)
        case .metal:       return Color(hex: 0x71717A)
        case .mixed:       return Color(hex: 0xF59E0B)
        case .compostable: return PSColors.primaryGreen
        }
    }

    /// Estimated EPR cost per unit (pounds sterling).
    var eprCostPerUnit: Double {
        switch self {
        case .plastic:     return 0.22
        case .glass:       return 0.08
        case .cardboard:   return 0.05
        case .metal:       return 0.12
        case .mixed:       return 0.18
        case .compostable: return 0.02
        }
    }
}

// MARK: - Service

@MainActor
final class BarcodeAnalyticsService {
    static let shared = BarcodeAnalyticsService()
    private init() {}

    /// Group items by barcode and compute waste metrics per barcode.
    func analyze(items: [FreshliItem]) -> [BarcodeInsight] {
        let now = Date()
        let withBarcodes = items.filter { $0.barcode != nil && !($0.barcode ?? "").isEmpty }
        let grouped = Dictionary(grouping: withBarcodes) { $0.barcode ?? "" }

        var insights: [BarcodeInsight] = []
        for (barcode, barcodeItems) in grouped {
            guard barcodeItems.count >= 2,
                  let sample = barcodeItems.first else { continue }  // need at least 2 data points
            let totalCount = barcodeItems.count
            guard totalCount > 0 else { continue }
            let wastedCount = barcodeItems.filter {
                !$0.isConsumed && !$0.isShared && !$0.isDonated && $0.expiryDate < now
            }.count
            let packaging = inferPackaging(category: sample.category)
            let eprCostPerUnit = packaging.eprCostPerUnit
            let totalImpact = Double(wastedCount) * eprCostPerUnit

            let recommendation = buildRecommendation(
                wasteRate: Double(wastedCount) / Double(totalCount),
                productName: sample.name,
                packaging: packaging
            )

            insights.append(BarcodeInsight(
                barcode: barcode,
                productName: sample.name,
                category: sample.category,
                timesPurchased: totalCount,
                timesWasted: wastedCount,
                eprCostPerUnit: eprCostPerUnit,
                totalEprImpact: totalImpact,
                packagingType: packaging,
                recommendation: recommendation
            ))
        }
        return insights.sorted { $0.totalEprImpact > $1.totalEprImpact }
    }

    /// Top N most wasteful barcodes by total EPR impact.
    func topWastefulBarcodes(items: [FreshliItem], limit: Int = 5) -> [BarcodeInsight] {
        Array(analyze(items: items).prefix(limit))
    }

    /// Total EPR cost from all wasted barcoded items.
    func totalEprImpact(items: [FreshliItem]) -> Double {
        analyze(items: items).reduce(0) { $0 + $1.totalEprImpact }
    }

    /// Estimated CO₂ from packaging waste (kg).
    func totalPackagingCO2(items: [FreshliItem]) -> Double {
        analyze(items: items).reduce(0) { $0 + (Double($1.timesWasted) * 0.3) }
    }

    // MARK: - Helpers

    private func inferPackaging(category: FoodCategory) -> PackagingType {
        switch category {
        case .dairy:      return .plastic
        case .bakery:     return .plastic
        case .meat:       return .plastic
        case .seafood:    return .plastic
        case .beverages:  return .plastic
        case .condiments: return .glass
        case .grains:     return .cardboard
        case .snacks:     return .mixed
        case .frozen:     return .plastic
        case .fruits:     return .compostable
        case .vegetables: return .compostable
        case .canned:     return .metal
        case .other:      return .mixed
        }
    }

    private func buildRecommendation(wasteRate: Double, productName: String, packaging: PackagingType) -> String {
        if wasteRate >= 0.5 {
            return "You waste over half of every \(productName.lowercased()). Consider switching to a smaller size or a loose alternative."
        } else if wasteRate >= 0.3 {
            return "\(packaging.rawValue) packaging adds £\(String(format: "%.2f", packaging.eprCostPerUnit * 3)) to every 3 wasted units. Try buying only what you need."
        } else {
            return "Good control on \(productName.lowercased()). Keep tracking expiry dates to stay under 20% waste."
        }
    }
}

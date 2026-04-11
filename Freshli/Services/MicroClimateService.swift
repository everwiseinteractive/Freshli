import Foundation
import SwiftUI
import UserNotifications

// MARK: - Micro-Climate Service
// Uses local weather data (simulated) to proactively protect pantry items
// from spoilage during heatwaves, cold snaps, and humidity extremes.

// MARK: - Models

enum ClimateCondition: String {
    case normal     = "Normal"
    case heatwave   = "Heatwave"
    case coldSnap   = "Cold Snap"
    case humid      = "High Humidity"
    case dry        = "Very Dry"

    var icon: String {
        switch self {
        case .normal:   return "sun.and.horizon.fill"
        case .heatwave: return "thermometer.sun.fill"
        case .coldSnap: return "snowflake"
        case .humid:    return "drop.fill"
        case .dry:      return "wind"
        }
    }

    var color: Color {
        switch self {
        case .normal:   return PSColors.primaryGreen
        case .heatwave: return Color(hex: 0xEF4444)
        case .coldSnap: return Color(hex: 0x06B6D4)
        case .humid:    return Color(hex: 0x8B5CF6)
        case .dry:      return Color(hex: 0xF59E0B)
        }
    }
}

enum ClimateAlertSeverity {
    case info, warning, critical
    var color: Color {
        switch self {
        case .info:     return Color(hex: 0x3B82F6)
        case .warning:  return PSColors.secondaryAmber
        case .critical: return PSColors.expiredRed
        }
    }
}

struct ClimateAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let affectedItemNames: [String]
    let severity: ClimateAlertSeverity
    let recommendedAction: String
    let condition: ClimateCondition
}

// MARK: - Service

@MainActor
@Observable
final class MicroClimateService {
    static let shared = MicroClimateService()
    private init() {}

    // Simulated weather — in production wire up WeatherKit.
    var currentTempCelsius: Double = 22
    var forecastHighCelsius: Double = 25
    var humidity: Double = 55       // 0–100
    var locationName: String = "Your Area"

    var currentCondition: ClimateCondition {
        if forecastHighCelsius >= 28 { return .heatwave }
        if forecastHighCelsius < 5   { return .coldSnap }
        if humidity >= 80            { return .humid }
        if humidity < 25             { return .dry }
        return .normal
    }

    // MARK: - Alert Generation

    func checkForAlerts(items: [FreshliItem]) -> [ClimateAlert] {
        var alerts: [ClimateAlert] = []
        let active = items.filter { $0.isActive }

        switch currentCondition {
        case .heatwave:
            // Counter bread / fruit are at risk
            let counterItems = active.filter { $0.storageLocation == .counter }
            let bread = counterItems.filter { $0.name.lowercased().contains("bread") }
            if !bread.isEmpty {
                alerts.append(ClimateAlert(
                    title: "It's \(Int(forecastHighCelsius))°C today",
                    message: "Move your bread to the fridge to prevent mould for 4 more days.",
                    affectedItemNames: bread.map { $0.name },
                    severity: .critical,
                    recommendedAction: "Move \(bread.count) item\(bread.count == 1 ? "" : "s") to fridge",
                    condition: .heatwave
                ))
            }
            let fruit = counterItems.filter { $0.category == .fruits }
            if !fruit.isEmpty {
                alerts.append(ClimateAlert(
                    title: "Heatwave alert — fruit at risk",
                    message: "Soft fruit on the counter will over-ripen in this heat. Consider moving to the fridge.",
                    affectedItemNames: fruit.map { $0.name },
                    severity: .warning,
                    recommendedAction: "Refrigerate soft fruit",
                    condition: .heatwave
                ))
            }
        case .coldSnap:
            // Tropical fruit / tomatoes / basil shouldn't get too cold
            let tropical = active.filter {
                let n = $0.name.lowercased()
                return n.contains("banana") || n.contains("mango") || n.contains("pineapple") || n.contains("basil")
            }
            if !tropical.isEmpty {
                alerts.append(ClimateAlert(
                    title: "Cold snap — \(Int(currentTempCelsius))°C",
                    message: "Keep tropical produce away from cold windows and the garage — they bruise below 10°C.",
                    affectedItemNames: tropical.map { $0.name },
                    severity: .warning,
                    recommendedAction: "Move to warm interior",
                    condition: .coldSnap
                ))
            }
        case .humid:
            let grains = active.filter { $0.category == .grains || $0.category == .snacks }
            if !grains.isEmpty {
                alerts.append(ClimateAlert(
                    title: "Humid day — airtight containers",
                    message: "Open packets of flour, cereal, and crackers go stale 2× faster at this humidity.",
                    affectedItemNames: grains.map { $0.name },
                    severity: .info,
                    recommendedAction: "Reseal or decant into airtight jars",
                    condition: .humid
                ))
            }
        case .dry:
            let greens = active.filter { $0.category == .vegetables && $0.storageLocation == .fridge }
            if !greens.isEmpty {
                alerts.append(ClimateAlert(
                    title: "Very dry air",
                    message: "Leafy greens wilt faster when humidity drops. Wrap in a damp paper towel inside the crisper drawer.",
                    affectedItemNames: greens.map { $0.name },
                    severity: .info,
                    recommendedAction: "Add moisture barrier",
                    condition: .dry
                ))
            }
        case .normal:
            break
        }

        return alerts
    }

    // MARK: - Notification Scheduling

    func scheduleNotifications(for alerts: [ClimateAlert]) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.message
            content.sound = .default
            content.categoryIdentifier = "micro_climate"

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request = UNNotificationRequest(
                identifier: "climate_\(alert.id.uuidString)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}

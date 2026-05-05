import Foundation
import SwiftUI

// MARK: - Community Pods Service
// Hyper-local "Verified Pods" for apartment buildings, offices, and streets.
// Also manages community fridge location data for the map view.

// MARK: - Pod Models

enum PodType: String, Codable, CaseIterable, Identifiable {
    case apartment = "Apartment Building"
    case office    = "Office Building"
    case street    = "Street"
    case school    = "School"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .apartment: return "building.2.fill"
        case .office:    return "briefcase.fill"
        case .street:    return "road.lanes"
        case .school:    return "graduationcap.fill"
        }
    }

    var color: Color {
        switch self {
        case .apartment: return Color(hex: 0x3B82F6)
        case .office:    return Color(hex: 0x8B5CF6)
        case .street:    return Color(hex: 0x10B981)
        case .school:    return Color(hex: 0xF59E0B)
        }
    }
}

struct LocalPod: Identifiable {
    let id: UUID
    let name: String
    let address: String
    let podType: PodType
    let memberCount: Int
    let isVerified: Bool
    let activeListings: Int
    let distanceMetres: Double
    let joinCode: String
}

// MARK: - Community Fridge Models

enum FridgeStatus: String {
    case available  = "Available"
    case nearlyFull = "Nearly Full"
    case full       = "Full"
    case maintenance = "Maintenance"

    var color: Color {
        switch self {
        case .available:   return PSColors.primaryGreen
        case .nearlyFull:  return PSColors.secondaryAmber
        case .full:        return PSColors.expiredRed
        case .maintenance: return PSColors.textTertiary
        }
    }

    var icon: String {
        switch self {
        case .available:   return "checkmark.circle.fill"
        case .nearlyFull:  return "exclamationmark.circle.fill"
        case .full:        return "xmark.circle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        }
    }
}

struct CommunityFridge: Identifiable {
    let id: UUID
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let isOpen24h: Bool
    let openingHours: String?
    let currentStatus: FridgeStatus
    let acceptedItems: [String]
    let organisedBy: String
}

// MARK: - Service

@MainActor
@Observable
final class CommunityPodsService {
    static let shared = CommunityPodsService()
    private init() { loadJoinedPods() }

    var joinedPodIds: Set<UUID> = []
    private let joinedKey = "community_joined_pod_ids"

    // MARK: - Simulated Pods

    let nearbyPods: [LocalPod] = [
        LocalPod(id: UUID(), name: "Maple Court Residents", address: "12–24 Maple Court",
                 podType: .apartment, memberCount: 34, isVerified: true, activeListings: 7,
                 distanceMetres: 45, joinCode: "MAPLE7"),
        LocalPod(id: UUID(), name: "Level 4 — Tech Hub", address: "Innovation House, Floor 4",
                 podType: .office, memberCount: 18, isVerified: true, activeListings: 3,
                 distanceMetres: 120, joinCode: "TECH4H"),
        LocalPod(id: UUID(), name: "Elm Street Pod", address: "Elm Street, nos. 1–40",
                 podType: .street, memberCount: 52, isVerified: false, activeListings: 12,
                 distanceMetres: 280, joinCode: "ELMS40"),
        LocalPod(id: UUID(), name: "Greenwood School Families", address: "Greenwood Primary School",
                 podType: .school, memberCount: 89, isVerified: true, activeListings: 4,
                 distanceMetres: 550, joinCode: "GRNSCO"),
    ]

    // MARK: - Simulated Community Fridges

    let communityFridges: [CommunityFridge] = [
        CommunityFridge(id: UUID(), name: "The Real Junk Food Project",
                        address: "14 Market St, Leeds",
                        latitude: 53.7996, longitude: -1.5490,
                        isOpen24h: true, openingHours: nil, currentStatus: .available,
                        acceptedItems: ["All food welcome"],
                        organisedBy: "Real Junk Food Project"),
        CommunityFridge(id: UUID(), name: "Hackney Community Fridge",
                        address: "2 Andrews Rd, Hackney, London",
                        latitude: 51.5391, longitude: -0.0666,
                        isOpen24h: false, openingHours: "Mon–Sat 9am–6pm",
                        currentStatus: .nearlyFull,
                        acceptedItems: ["Fresh produce", "Packaged food", "Dairy"],
                        organisedBy: "Hackney Council"),
        CommunityFridge(id: UUID(), name: "Bristol Free Fridge",
                        address: "Stokes Croft, Bristol",
                        latitude: 51.4629, longitude: -2.5908,
                        isOpen24h: true, openingHours: nil, currentStatus: .available,
                        acceptedItems: ["All food", "No alcohol"],
                        organisedBy: "Feed Bristol"),
        CommunityFridge(id: UUID(), name: "NYC Free Fridge — Bronx",
                        address: "Grand Concourse, Bronx, NY",
                        latitude: 40.8448, longitude: -73.9285,
                        isOpen24h: true, openingHours: nil, currentStatus: .available,
                        acceptedItems: ["All food"],
                        organisedBy: "Community Fridge NYC"),
        CommunityFridge(id: UUID(), name: "Chicago Community Fridge",
                        address: "Logan Square, Chicago",
                        latitude: 41.9214, longitude: -87.7070,
                        isOpen24h: true, openingHours: nil, currentStatus: .full,
                        acceptedItems: ["Fresh produce", "Non-perishables"],
                        organisedBy: "Invisible Hands Chicago"),
    ]

    // MARK: - Actions

    func join(pod: LocalPod) {
        joinedPodIds.insert(pod.id)
        savePods()
    }

    func leave(pod: LocalPod) {
        joinedPodIds.remove(pod.id)
        savePods()
    }

    func isJoined(_ pod: LocalPod) -> Bool { joinedPodIds.contains(pod.id) }

    private func savePods() {
        UserDefaults.standard.set(joinedPodIds.map { $0.uuidString }, forKey: joinedKey)
    }

    private func loadJoinedPods() {
        if let ids = UserDefaults.standard.array(forKey: joinedKey) as? [String] {
            joinedPodIds = Set(ids.compactMap { UUID(uuidString: $0) })
        }
    }
}

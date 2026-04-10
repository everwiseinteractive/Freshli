import Foundation
import MapKit
import os

// MARK: - Neutral Spot Category

enum NeutralSpotCategory: String, Codable, CaseIterable, Identifiable {
    case coffeeShop
    case communityCenter
    case library
    case park
    case groceryStore

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coffeeShop: return String(localized: "Coffee Shop")
        case .communityCenter: return String(localized: "Community Center")
        case .library: return String(localized: "Library")
        case .park: return String(localized: "Park")
        case .groceryStore: return String(localized: "Grocery Store")
        }
    }

    var icon: String {
        switch self {
        case .coffeeShop: return "cup.and.saucer.fill"
        case .communityCenter: return "building.2.fill"
        case .library: return "books.vertical.fill"
        case .park: return "tree.fill"
        case .groceryStore: return "cart.fill"
        }
    }

    var searchTerms: [String] {
        switch self {
        case .coffeeShop: return ["coffee shop", "cafe", "coffee"]
        case .communityCenter: return ["community center", "community hall", "civic center"]
        case .library: return ["library", "public library"]
        case .park: return ["park", "public park", "green space"]
        case .groceryStore: return ["grocery store", "supermarket", "market"]
        }
    }
}

// MARK: - Neutral Spot Model

struct NeutralSpot: Identifiable {
    let id: UUID
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let category: NeutralSpotCategory
    let distance: CLLocationDistance

    init(
        name: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        category: NeutralSpotCategory,
        distance: CLLocationDistance
    ) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.category = category
        self.distance = distance
    }

    var formattedDistance: String {
        let meters = distance
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            let kilometers = meters / 1000
            return String(format: "%.1f km", kilometers)
        }
    }
}

// MARK: - Neutral Spot Service

@Observable @MainActor
final class NeutralSpotService {
    var spots: [NeutralSpot] = []
    var isSearching = false
    var selectedSpot: NeutralSpot?
    var error: String?

    private let logger = PSLogger(category: .community)

    // MARK: - Search Nearby Spots

    /// Search for neutral meeting spots near a given location
    func searchNearbySpots(
        near coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance = 2000
    ) async -> [NeutralSpot] {
        isSearching = true
        defer { isSearching = false }
        error = nil

        var allSpots: [NeutralSpot] = []

        // Search for each category in parallel
        await withTaskGroup(of: [NeutralSpot].self) { group in
            for category in NeutralSpotCategory.allCases {
                group.addTask {
                    await self.searchForCategory(
                        category,
                        near: coordinate,
                        radius: radius
                    )
                }
            }

            for await categorySpots in group {
                allSpots.append(contentsOf: categorySpots)
            }
        }

        // Sort by distance
        allSpots.sort { $0.distance < $1.distance }
        self.spots = allSpots

        logger.info("Found \(allSpots.count) neutral spots near coordinate")
        return allSpots
    }

    /// Select a specific spot as pickup location
    func selectSpot(_ spot: NeutralSpot) {
        selectedSpot = spot
        logger.info("Selected neutral spot: \(spot.name)")
    }

    /// Create a custom spot at a given coordinate (for user-pinned locations)
    func createCustomSpot(
        at coordinate: CLLocationCoordinate2D,
        name: String = "Custom Location"
    ) async -> NeutralSpot {
        let customSpot = NeutralSpot(
            name: name,
            address: "Custom location",
            coordinate: coordinate,
            category: .park,
            distance: 0
        )
        selectedSpot = customSpot
        logger.info("Created custom spot at \(coordinate.latitude), \(coordinate.longitude)")
        return customSpot
    }

    // MARK: - Private Helpers

    private func searchForCategory(
        _ category: NeutralSpotCategory,
        near coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance
    ) async -> [NeutralSpot] {
        var categorySpots: [NeutralSpot] = []

        for searchTerm in category.searchTerms {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchTerm
            request.region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: 0.05,
                    longitudeDelta: 0.05
                )
            )

            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                for item in response.mapItems.prefix(3) {
                    guard let mapItemLocation = item.placemark.location else { continue }

                    let distance = CLLocation(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    .distance(from: CLLocation(
                        latitude: mapItemLocation.coordinate.latitude,
                        longitude: mapItemLocation.coordinate.longitude
                    ))

                    if distance <= radius {
                        let address = formatAddress(item.placemark)
                        let spot = NeutralSpot(
                            name: item.name ?? searchTerm,
                            address: address,
                            coordinate: mapItemLocation.coordinate,
                            category: category,
                            distance: distance
                        )
                        categorySpots.append(spot)
                    }
                }
            } catch {
                logger.debug("Search failed for '\(searchTerm)': \(error.localizedDescription)")
            }
        }

        return categorySpots
    }

    private func formatAddress(_ placemark: CLPlacemark) -> String {
        var addressParts: [String] = []

        if let street = placemark.thoroughfare {
            addressParts.append(street)
        }
        if let city = placemark.locality {
            addressParts.append(city)
        }

        return addressParts.joined(separator: ", ")
    }
}

import Foundation
import Supabase
import CoreLocation
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - AreaService
//
// Bridge between Apple's CLGeocoder output (a `ResolvedArea` value)
// and the Supabase `community_areas` table. Wraps two RPCs:
//
//   • `find_or_create_area(name, display_name, locality, country_code,
//     lat, lng) -> uuid`
//        Canonicalises by slug + proximity. Returns an existing area
//        when the user lands within ~1.5km of one with a matching
//        name; otherwise inserts a brand-new row and returns its id.
//
//   • `set_current_area(area_id) -> void`
//        Persists the user's chosen area to `profiles.current_area_id`
//        so the Community feed defaults to it on next launch.
//
// Why: the Areas system geofences the Community feed so people only
// see listings from neighbours in the same area — keeping food
// sharing local and minimising pickup-vehicle emissions, exactly the
// product brief.
//
// `@Observable @MainActor` so SwiftUI views can read `currentArea`
// without explicit subscription, and so all mutations (which touch
// the network) happen on the main actor — the surface area is small
// (handful of RPCs) and keeping it MainActor avoids Sendable churn
// across actor boundaries for the UI surfaces that actually call it.
// ══════════════════════════════════════════════════════════════════

@Observable @MainActor
final class AreaService {
    /// Singleton — matches the LocationService.shared pattern used
    /// elsewhere in the codebase. SWIFT_APPROACHABLE_CONCURRENCY in
    /// the project settings allows this without `nonisolated(unsafe)`.
    static let shared = AreaService()

    // MARK: - Public observable state

    /// The user's currently selected community area. Drives the
    /// Community feed filter and the create-listing form's default.
    private(set) var currentArea: AreaRow?

    /// True while a network request is in flight (find_or_create or
    /// fetch). Bind to spinners.
    private(set) var isLoading: Bool = false

    /// Most recent error string (already localised). Cleared when the
    /// next request starts.
    private(set) var lastError: String?

    private let client = AppSupabase.client
    private let logger = Logger(subsystem: "com.freshli.app", category: "AreaService")

    private init() {}

    // MARK: - Public API

    /// Resolve a `ResolvedArea` (from CLGeocoder) into a Supabase area
    /// row, creating it if necessary. The returned row's `id` is what
    /// callers store in `shared_listings.area_id` and
    /// `profiles.current_area_id`.
    @discardableResult
    func findOrCreate(_ resolved: ResolvedArea) async throws -> AreaRow {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        struct Params: Encodable {
            let p_name: String
            let p_display_name: String
            let p_locality: String
            let p_country_code: String
            let p_lat: Double
            let p_lng: Double
        }

        let params = Params(
            p_name: resolved.neighbourhood,
            p_display_name: resolved.displayName,
            p_locality: resolved.locality,
            p_country_code: resolved.countryCode,
            p_lat: resolved.coordinate.latitude,
            p_lng: resolved.coordinate.longitude
        )

        // The RPC returns a bare UUID; PostgREST renders it as a
        // single-string body, so decode straight to UUID.
        let areaId: UUID
        do {
            areaId = try await client.rpc("find_or_create_area", params: params)
                .execute()
                .value
        } catch {
            logger.error("find_or_create_area failed: \(error.localizedDescription, privacy: .public)")
            lastError = String(localized: "Couldn't save your neighbourhood. Please try again.")
            throw AreaError.rpcFailed
        }

        // Fetch the full row so we can render its name in the UI.
        let row = try await fetchArea(id: areaId)
        currentArea = row
        return row
    }

    /// Persist the user's preferred area to `profiles.current_area_id`.
    /// Idempotent — calling with the same id is a no-op server-side.
    func setCurrentArea(_ area: AreaRow) async throws {
        struct Params: Encodable { let p_area_id: UUID }
        do {
            try await client.rpc("set_current_area", params: Params(p_area_id: area.id))
                .execute()
            currentArea = area
            logger.info("Set current area to \(area.displayName, privacy: .public)")
        } catch {
            logger.error("set_current_area failed: \(error.localizedDescription, privacy: .public)")
            lastError = String(localized: "Couldn't update your neighbourhood preference.")
            throw AreaError.rpcFailed
        }
    }

    /// Load the user's saved area from `profiles.current_area_id`.
    /// Called once on Community-tab appear so the feed and the
    /// create-listing form both default to it.
    func loadCurrentArea(for userId: UUID) async throws -> AreaRow? {
        struct ProfileSlice: Decodable {
            let currentAreaId: UUID?
            enum CodingKeys: String, CodingKey { case currentAreaId = "current_area_id" }
        }
        let profile: ProfileSlice
        do {
            profile = try await client
                .from("profiles")
                .select("current_area_id")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
        } catch {
            logger.warning("loadCurrentArea profile fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        guard let areaId = profile.currentAreaId else {
            currentArea = nil
            return nil
        }
        let row = try await fetchArea(id: areaId)
        currentArea = row
        return row
    }

    /// Look up a single area by id. Public so the create-listing flow
    /// can resolve the user's `current_area_id` at submit time.
    func fetchArea(id: UUID) async throws -> AreaRow {
        do {
            let row: AreaRow = try await client
                .from("community_areas")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            return row
        } catch {
            logger.error("fetchArea failed: \(error.localizedDescription, privacy: .public)")
            throw AreaError.notFound
        }
    }

    /// Pre-populated suggestions for the manual area picker — the
    /// nearest already-existing areas the user might want to switch to.
    /// Returns up to `limit` rows ordered by distance from `from`.
    func nearbyAreas(from coord: CLLocationCoordinate2D, limit: Int = 12) async throws -> [AreaRow] {
        // Wide bounding box (~30km in each direction) — the user might
        // legitimately want to browse the next neighbourhood over.
        let latPad = 0.30
        let lngPad = 0.40
        do {
            var rows: [AreaRow] = try await client
                .from("community_areas")
                .select()
                .gte("centroid_lat", value: coord.latitude - latPad)
                .lte("centroid_lat", value: coord.latitude + latPad)
                .gte("centroid_lng", value: coord.longitude - lngPad)
                .lte("centroid_lng", value: coord.longitude + lngPad)
                .limit(60)
                .execute()
                .value

            // Client-side haversine sort — Postgres doesn't have PostGIS
            // enabled and the row count at this stage is trivial.
            rows.sort { lhs, rhs in
                Self.squaredDistance(lhs, from: coord) < Self.squaredDistance(rhs, from: coord)
            }
            return Array(rows.prefix(limit))
        } catch {
            logger.warning("nearbyAreas fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func squaredDistance(_ row: AreaRow, from coord: CLLocationCoordinate2D) -> Double {
        guard let lat = row.centroidLat, let lng = row.centroidLng else { return .greatestFiniteMagnitude }
        let dLat = lat - coord.latitude
        let dLng = lng - coord.longitude
        return dLat * dLat + dLng * dLng
    }
}

// MARK: - AreaRow

/// Mirror of `public.community_areas`. `Sendable` so it can be
/// stored in observable state without isolation warnings.
struct AreaRow: Codable, Identifiable, Sendable, Equatable, Hashable {
    let id: UUID
    let slug: String
    let name: String
    let displayName: String
    let locality: String?
    let countryCode: String?
    let centroidLat: Double?
    let centroidLng: Double?
    let radiusM: Int
    let memberCount: Int
    let listingCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case name
        case displayName  = "display_name"
        case locality
        case countryCode  = "country_code"
        case centroidLat  = "centroid_lat"
        case centroidLng  = "centroid_lng"
        case radiusM      = "radius_m"
        case memberCount  = "member_count"
        case listingCount = "listing_count"
    }
}

// MARK: - Errors

enum AreaError: LocalizedError, Sendable {
    case rpcFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .rpcFailed:
            return String(localized: "Couldn't save your neighbourhood. Please try again.")
        case .notFound:
            return String(localized: "Couldn't find that neighbourhood.")
        }
    }
}

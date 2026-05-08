import Foundation
import CoreLocation
import Combine
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - LocationService
//
// Centralised wrapper around CLLocationManager for community / map
// features. Replaces the ad-hoc `CLLocationManager()` allocations that
// were sprinkled across PickupLocationView, NeutralSpotService, and
// CommunityMarketplaceViewModel — none of which actually published a
// usable location to Supabase distance queries, so "nearby listings"
// silently fell back to "all listings."
//
// Design:
//   • Single shared instance, MainActor-isolated.
//   • Exposes `authorizationStatus` and `currentLocation` as @Observable
//     properties so SwiftUI views can react to authorization changes
//     and location updates without subscribing to the delegate manually.
//   • Uses `kCLLocationAccuracyHundredMeters` — community features need
//     "what neighbourhood" granularity, never street-level.
//   • Auto-pauses when backgrounded (we're not a navigation app); the
//     last-known location is cached so cold-start queries can still
//     show approximate-nearby data without waiting for a fresh fix.
//   • Honours the privacy policy commitment that exact addresses are
//     never persisted: the cached location is rounded to 3 decimal
//     places (~110m at the equator) before being written to UserDefaults.
//
// Privacy:
//   - Only requests `WhenInUseAuthorization` (matches Info.plist).
//   - Coordinates are used for Supabase RPC distance filters; the
//     RPC server-side never returns the user's coordinate to other
//     users — only listings that match the requested radius.
//   - Coarse-only: the rounded cache is what gets read by widgets
//     and the Watch companion via App Group UserDefaults.
// ══════════════════════════════════════════════════════════════════

@Observable @MainActor
final class LocationService: NSObject {
    static let shared = LocationService()

    // MARK: - Public observable state

    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var currentLocation: CLLocation?
    private(set) var lastError: Error?

    /// True while a location request is in flight.
    private(set) var isLocating: Bool = false

    /// Cached approximate location persisted to App Group UserDefaults
    /// (rounded to 3 decimal places ≈ 110m). Used by the widgets,
    /// the Watch companion, and as a cold-start fallback when the
    /// user opens the Community tab before a fresh fix arrives.
    var cachedApproximateCoordinate: CLLocationCoordinate2D? {
        let defaults = UserDefaults(suiteName: "group.everwise.interactive.Freshli") ?? .standard
        let lat = defaults.double(forKey: "freshli.location.cachedLat")
        let lon = defaults.double(forKey: "freshli.location.cachedLon")
        guard lat != 0 || lon != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Private

    private let manager = CLLocationManager()
    private let logger = Logger(subsystem: "com.freshli.app", category: "Location")

    /// Continuation queue for one-shot `requestLocation()` callers.
    private var pendingRequests: [CheckedContinuation<CLLocation, Error>] = []

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = true
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Public API

    /// Trigger the system permission prompt if the user hasn't decided yet.
    /// On `denied` / `restricted` the caller must show its own UI explaining
    /// how to enable Location in iOS Settings.
    func requestPermissionIfNeeded() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// One-shot location fix. Returns the freshest available coordinate
    /// (or the cached one if the user is offline / has just opened the
    /// app and a real fix hasn't yet arrived).
    ///
    /// Throws `LocationError.permissionDenied` if Location is denied or
    /// restricted, or `LocationError.unavailable` if the device has no
    /// way to obtain a fix and we have no cached fallback.
    func requestLocation() async throws -> CLLocation {
        switch authorizationStatus {
        case .notDetermined:
            requestPermissionIfNeeded()
            // Wait for the user to decide (max 8s); polling keeps the
            // implementation simple and doesn't require a delegate hook.
            for _ in 0..<32 {
                try? await Task.sleep(for: .milliseconds(250))
                if authorizationStatus != .notDetermined { break }
            }
        case .denied, .restricted:
            throw LocationError.permissionDenied
        default: break
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }

        // Fast path: a recent fix already in memory.
        if let recent = currentLocation,
           Date().timeIntervalSince(recent.timestamp) < 60 {
            return recent
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests.append(continuation)
            isLocating = true
            manager.requestLocation()
        }
    }

    /// Best-effort coordinate for views that prefer to render with a
    /// cached fallback rather than `await` and show a spinner. Returns
    /// the freshest in-memory fix, falling back to the App Group cache.
    func bestAvailableCoordinate() -> CLLocationCoordinate2D? {
        currentLocation?.coordinate ?? cachedApproximateCoordinate
    }

    // MARK: - Reverse geocoding (Apple Maps)
    //
    // `CLGeocoder` is Apple's first-party reverse geocoder — same data
    // path as Apple Maps. We translate raw coordinates into the
    // hierarchical neighbourhood / locality / country triple that the
    // Areas feature uses to resolve a `community_areas` row via the
    // `find_or_create_area` RPC.
    //
    // Privacy: the geocoder is invoked over Apple's privacy-preserving
    // service (see https://developer.apple.com/documentation/corelocation/clgeocoder).
    // No third-party servers see the user's coordinate.

    private let geocoder = CLGeocoder()
    private var lastReverseGeocode: (coord: CLLocationCoordinate2D, result: ResolvedArea, at: Date)?

    /// Reverse-geocode a coordinate into a human-readable neighbourhood
    /// + locality + country triple.
    ///
    /// Result is cached in-memory for 5 minutes per coordinate (rounded
    /// to 3 decimals, ~110m) so consecutive calls from a fresh fix
    /// don't re-hit Apple's reverse-geocode service. CLGeocoder is
    /// rate-limited; callers should not invoke this in tight loops.
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> ResolvedArea {
        // 5-minute cache — the user's neighbourhood doesn't change.
        if let last = lastReverseGeocode,
           Self.coordsApproximatelyEqual(last.coord, coordinate),
           Date().timeIntervalSince(last.at) < 300 {
            return last.result
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.reverseGeocodeLocation(location)
        } catch {
            logger.warning("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
            throw LocationError.geocodeFailed
        }
        guard let placemark = placemarks.first else {
            throw LocationError.geocodeFailed
        }

        // Pick the most specific neighbourhood label CL provides:
        //   subLocality (e.g. "Headingley") → locality (e.g. "Leeds")
        //   → name (e.g. "Whitehall Road"). Always prefer subLocality.
        let neighbourhood = placemark.subLocality
            ?? placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.name
            ?? String(localized: "Unknown area")

        let locality = placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? ""

        let country = placemark.country ?? ""
        let countryCode = placemark.isoCountryCode ?? ""

        // Display name: "<Neighbourhood>, <City>, <Country>" when all
        // three are known; degrade gracefully when they aren't.
        var parts: [String] = [neighbourhood]
        if !locality.isEmpty, locality != neighbourhood { parts.append(locality) }
        if !country.isEmpty { parts.append(country) }
        let displayName = parts.joined(separator: ", ")

        let resolved = ResolvedArea(
            neighbourhood: neighbourhood,
            locality: locality,
            country: country,
            countryCode: countryCode,
            displayName: displayName,
            coordinate: coordinate
        )
        lastReverseGeocode = (coordinate, resolved, Date())
        return resolved
    }

    /// Forward geocode — turn a free-text place query into a coordinate
    /// + canonicalised area triple. Used by the manual area picker
    /// when the user types "Camden Town" instead of using GPS.
    func forwardGeocode(_ query: String) async throws -> ResolvedArea {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LocationError.geocodeFailed }

        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.geocodeAddressString(trimmed)
        } catch {
            logger.warning("Forward geocode failed: \(error.localizedDescription, privacy: .public)")
            throw LocationError.geocodeFailed
        }
        guard let placemark = placemarks.first,
              let coord = placemark.location?.coordinate else {
            throw LocationError.geocodeFailed
        }

        // Re-use reverseGeocode's labelling logic by piping through
        // it with the resolved coordinate — keeps neighbourhood vs
        // locality vs country selection in one place.
        return try await reverseGeocode(coord)
    }

    /// Treat coordinates as equal when their 3-decimal rounding (≈110m)
    /// matches. Used as the cache key for reverse geocoding.
    private static func coordsApproximatelyEqual(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        Int(a.latitude  * 1000) == Int(b.latitude  * 1000) &&
        Int(a.longitude * 1000) == Int(b.longitude * 1000)
    }

    // MARK: - Caching

    private func cacheLocation(_ location: CLLocation) {
        // Round to 3 decimal places (≈ 110m at the equator) before
        // writing to App Group UserDefaults. The privacy policy commits
        // to never persisting exact addresses — this is the enforcement.
        let lat = (location.coordinate.latitude * 1000).rounded() / 1000
        let lon = (location.coordinate.longitude * 1000).rounded() / 1000
        let defaults = UserDefaults(suiteName: "group.everwise.interactive.Freshli") ?? .standard
        defaults.set(lat, forKey: "freshli.location.cachedLat")
        defaults.set(lon, forKey: "freshli.location.cachedLon")
        defaults.set(Date().timeIntervalSince1970, forKey: "freshli.location.cachedAt")
    }
}

// MARK: - Errors

enum LocationError: LocalizedError, Sendable {
    case permissionDenied
    case unavailable
    case timedOut
    case geocodeFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return String(localized: "Location access is required to find Community listings near you. You can enable it in Settings → Freshli → Location.")
        case .unavailable:
            return String(localized: "Couldn't determine your location. Check that Location Services is on, then try again.")
        case .timedOut:
            return String(localized: "Locating is taking longer than expected. You can keep waiting or browse all listings instead.")
        case .geocodeFailed:
            return String(localized: "We couldn't find a neighbourhood for that location. Try entering a place name instead.")
        }
    }
}

// MARK: - ResolvedArea
//
// The product of a CLGeocoder lookup. Carries everything the
// Areas server-side RPC needs: the neighbourhood label, the disambiguating
// city + country, the canonical display string, and the centroid
// coordinate. `Sendable` so it crosses actor boundaries cheanly.

struct ResolvedArea: Sendable, Equatable {
    /// e.g. "Headingley", "Le Marais", "SoMa".
    let neighbourhood: String
    /// e.g. "Leeds", "Paris", "San Francisco". Empty when unknown.
    let locality: String
    /// e.g. "United Kingdom", "France", "United States". Empty when unknown.
    let country: String
    /// ISO 3166-1 alpha-2, e.g. "GB", "FR", "US". Empty when unknown.
    let countryCode: String
    /// "Headingley, Leeds, United Kingdom".
    let displayName: String
    /// Centroid we used as the reverse-geocode probe. Carries through
    /// to `community_areas.centroid_lat / lng` on first creation.
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: ResolvedArea, rhs: ResolvedArea) -> Bool {
        lhs.neighbourhood == rhs.neighbourhood &&
        lhs.locality == rhs.locality &&
        lhs.countryCode == rhs.countryCode
    }
}

// MARK: - CLLocationManagerDelegate
//
// CLLocationManagerDelegate methods are invoked on the main thread by
// CoreLocation, so a `nonisolated` declaration with a `Task @MainActor`
// hop is the correct Swift 6 strict-concurrency pattern.

extension LocationService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        logger.info("Authorization changed: \(self.authorizationStatus.rawValue, privacy: .public)")

        // If the user just granted permission and there are pending
        // one-shot requests, kick off a fresh fix.
        if !pendingRequests.isEmpty,
           authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            isLocating = true
            manager.requestLocation()
        }

        // If the user denied, fail every pending request.
        if authorizationStatus == .denied || authorizationStatus == .restricted {
            for cont in pendingRequests {
                cont.resume(throwing: LocationError.permissionDenied)
            }
            pendingRequests.removeAll()
            isLocating = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        cacheLocation(location)
        isLocating = false
        for cont in pendingRequests {
            cont.resume(returning: location)
        }
        pendingRequests.removeAll()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error
        isLocating = false
        logger.warning("Location request failed: \(error.localizedDescription, privacy: .public)")
        for cont in pendingRequests {
            cont.resume(throwing: LocationError.unavailable)
        }
        pendingRequests.removeAll()
    }
}

import SwiftUI
import CoreLocation
import MapKit

// ══════════════════════════════════════════════════════════════════
// MARK: - AreaPickerSheet
//
// Lets the user confirm or change the neighbourhood Freshli detected
// from their location. Three columns of escape hatches in priority
// order:
//
//   1. **Use my current location** — re-runs CLGeocoder against the
//      freshest CLLocation fix. The default path; one tap and done.
//
//   2. **Browse nearby areas** — lists existing `community_areas`
//      rows within ~30km of the user's coordinate, sorted by
//      proximity. If a neighbour already created "Headingley", the
//      next person who lives there picks the existing row instead of
//      forking a new one.
//
//   3. **Search a place** — `MKLocalSearchCompleter` driven typeahead
//      so users without GPS (or visiting a different city) can find
//      their area by name. Behind the scenes this still resolves
//      through `find_or_create_area` so the canonical row gets
//      created if it doesn't already exist.
//
// On confirm, calls `onSelect(AreaRow)` and dismisses. The caller is
// responsible for persisting via `AreaService.setCurrentArea` and
// updating the listing payload.
// ══════════════════════════════════════════════════════════════════

@MainActor
struct AreaPickerSheet: View {
    /// Pre-resolved area passed in from the create-listing form's
    /// auto-detect — shown at the top as the recommended choice.
    let initial: ResolvedArea?
    let onSelect: (AreaRow) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var resolved: ResolvedArea?
    @State private var nearby: [AreaRow] = []
    @State private var query: String = ""
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var isResolving = false
    @State private var errorMessage: String?

    @State private var searchCompleter = SearchCompleterCoordinator()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let resolved {
                        autoDetectedCard(resolved)
                    }

                    if !nearby.isEmpty {
                        nearbyAreasSection
                    }

                    searchSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
            }
            .navigationTitle(String(localized: "Choose your area"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .task {
                await loadInitial()
            }
            .onChange(of: query) { _, newValue in
                searchCompleter.update(query: newValue)
            }
            .onChange(of: searchCompleter.results) { _, newResults in
                searchResults = newResults
            }
        }
    }

    // MARK: - Sections

    private func autoDetectedCard(_ area: ResolvedArea) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .foregroundStyle(.tint)
                Text(String(localized: "Detected from your location"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(area.displayName)
                .font(.system(size: 22, weight: .bold))
            HStack(spacing: 8) {
                Button {
                    Task { await selectResolved(area) }
                } label: {
                    HStack {
                        if isResolving {
                            ProgressView().controlSize(.small).tint(.white)
                        }
                        Text(String(localized: "Confirm this area"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isResolving)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var nearbyAreasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Areas nearby"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(nearby) { area in
                    Button {
                        onSelect(area)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(area.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(area.displayName)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(area.memberCount)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Or search a place"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "City or neighbourhood"), text: $query)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !searchResults.isEmpty {
                VStack(spacing: 8) {
                    ForEach(searchResults, id: \.title) { result in
                        Button {
                            Task { await selectFromCompletion(result) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadInitial() async {
        // Hydrate the auto-detected card. If the parent already passed
        // a `ResolvedArea`, use it; otherwise resolve from current
        // location.
        if let initial {
            resolved = initial
        } else {
            do {
                let location = try await LocationService.shared.requestLocation()
                resolved = try await LocationService.shared.reverseGeocode(location.coordinate)
            } catch {
                errorMessage = (error as? LocationError)?.errorDescription
                    ?? String(localized: "Couldn't detect your location.")
            }
        }
        // Load nearby existing areas around the detected centroid.
        if let coord = resolved?.coordinate {
            nearby = (try? await AreaService.shared.nearbyAreas(from: coord)) ?? []
        }
    }

    private func selectResolved(_ area: ResolvedArea) async {
        isResolving = true
        defer { isResolving = false }
        do {
            let row = try await AreaService.shared.findOrCreate(area)
            onSelect(row)
            dismiss()
        } catch {
            errorMessage = (error as? AreaError)?.errorDescription
                ?? String(localized: "Couldn't save this area. Please try again.")
        }
    }

    private func selectFromCompletion(_ completion: MKLocalSearchCompletion) async {
        isResolving = true
        defer { isResolving = false }

        // Resolve the typeahead suggestion to a concrete coordinate
        // via MKLocalSearch, then route through CLGeocoder so the
        // resulting ResolvedArea has the same shape as the auto-
        // detected one.
        let request = MKLocalSearch.Request(completion: completion)
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                errorMessage = String(localized: "Couldn't find that place.")
                return
            }
            // iOS 26 deprecated `placemark` on MKMapItem in favour of
            // `location.coordinate`. Use the new API and prefer
            // `addressRepresentations` for naming, with sensible
            // fallbacks for older runtimes.
            let coord: CLLocationCoordinate2D
            if let loc = item.location {
                coord = loc.coordinate
            } else {
                errorMessage = String(localized: "Couldn't find that place.")
                return
            }
            let resolvedArea = try await LocationService.shared.reverseGeocode(coord)
            await selectResolved(resolvedArea)
        } catch {
            errorMessage = String(localized: "Couldn't load that place. Please try again.")
        }
    }
}

// MARK: - SearchCompleterCoordinator
//
// Bridges UIKit's `MKLocalSearchCompleter` (delegate-based) to a
// SwiftUI-friendly `@Observable` value. Updates `results` whenever
// completer fires.

@MainActor
@Observable
final class SearchCompleterCoordinator: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    var results: [MKLocalSearchCompletion] = []

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            return
        }
        completer.queryFragment = trimmed
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let snapshot = completer.results
        Task { @MainActor in
            self.results = snapshot
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.results = []
        }
    }
}

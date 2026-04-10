import SwiftUI
import MapKit

// MARK: - Pickup Location View

struct PickupLocationView: View {
    @Environment(NeutralSpotService.self) private var neutralSpotService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: NeutralSpotCategory?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var showCustomPinMode = false
    @State private var customPinLocation: CLLocationCoordinate2D?
    @State private var isLoadingSpots = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onLocationSelected: ((NeutralSpot) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter
                categoryFilterBar

                // Map
                mapSection

                // Spots List
                if !filteredSpots.isEmpty {
                    spotsList
                } else if isLoadingSpots {
                    loadingView
                } else {
                    emptyView
                }

                // Selected Location Summary & Confirm Button
                if let selected = neutralSpotService.selectedSpot {
                    selectedLocationCard(selected)
                }
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle(String(localized: "Choose Pickup Location"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: PSLayout.scaledFont(24)))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
            .onAppear {
                Task {
                    await loadNearbySpots()
                }
            }
        }
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PSSpacing.sm) {
                ForEach(NeutralSpotCategory.allCases, id: \.id) { category in
                    PSFilterChip(
                        title: category.displayName,
                        isSelected: selectedCategory == category,
                        action: {
                            PSHaptics.shared.selection()
                            withAnimation(FLMotion.adaptive(PSMotion.springQuick, reduceMotion: reduceMotion)) {
                                selectedCategory = selectedCategory == category ? nil : category
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
        .padding(.vertical, PSSpacing.md)
        .background(PSColors.backgroundSecondary)
    }

    // MARK: - Map Section

    private var mapSection: some View {
        VStack(spacing: PSSpacing.sm) {
            if userLocation != nil {
                Map(position: $mapPosition) {
                    UserAnnotation()

                    ForEach(filteredSpots, id: \.id) { spot in
                        Marker(spot.name, coordinate: spot.coordinate)
                            .tag(spot.id)
                            .tint(spot.category.color)
                    }

                    if let customPin = customPinLocation {
                        Marker("Custom Location", coordinate: customPin)
                            .tint(PSColors.accentTeal)
                    }

                    if let selectedSpot = neutralSpotService.selectedSpot {
                        Marker("Selected", coordinate: selectedSpot.coordinate)
                            .tint(PSColors.primaryGreen)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .frame(height: 250)
                .cornerRadius(PSSpacing.radiusMd)
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.md)
            } else {
                VStack(spacing: PSSpacing.md) {
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: PSLayout.scaledFont(32)))
                        .foregroundStyle(PSColors.textTertiary)

                    Text(String(localized: "Location access needed"))
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)

                    Text(String(localized: "Enable location to find neutral meeting spots"))
                        .font(PSTypography.body)
                        .foregroundStyle(PSColors.textSecondary)
                }
                .frame(height: 250)
                .frame(maxWidth: .infinity)
                .background(PSColors.surfaceCard)
                .cornerRadius(PSSpacing.radiusMd)
                .padding()
            }

            // Custom Pin Button
            PSButton(
                title: String(localized: "Drop Custom Pin"),
                style: .secondary,
                isFullWidth: true,
                action: { toggleCustomPinMode() }
            )
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
    }

    // MARK: - Spots List

    private var spotsList: some View {
        ScrollView {
            VStack(spacing: PSSpacing.md) {
                ForEach(filteredSpots, id: \.id) { spot in
                    spotCard(spot)
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.md)
        }
    }

    private func spotCard(_ spot: NeutralSpot) -> some View {
        Button(action: {
            PSHaptics.shared.selection()
            withAnimation(FLMotion.adaptive(PSMotion.springBouncy, reduceMotion: reduceMotion)) {
                neutralSpotService.selectSpot(spot)
            }
        }) {
            HStack(spacing: PSSpacing.md) {
                VStack(alignment: .center, spacing: PSSpacing.xs) {
                    Image(systemName: spot.category.icon)
                        .font(.system(size: PSLayout.scaledFont(20)))
                        .foregroundStyle(spot.category.color)

                    Text(spot.category.displayName)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                }
                .frame(width: 50)

                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text(spot.name)
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)
                        .lineLimit(1)

                    Text(spot.address)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PSSpacing.xs) {
                    Text(spot.formattedDistance)
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)

                    if neutralSpotService.selectedSpot?.id == spot.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: PSLayout.scaledFont(16)))
                            .foregroundStyle(PSColors.primaryGreen)
                    }
                }
            }
            .padding(.vertical, PSSpacing.md)
            .padding(.horizontal, PSSpacing.md)
            .background(
                neutralSpotService.selectedSpot?.id == spot.id ?
                PSColors.primaryGreen.opacity(0.08) : PSColors.surfaceCard
            )
            .cornerRadius(PSSpacing.radiusMd)
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusMd)
                    .strokeBorder(
                        neutralSpotService.selectedSpot?.id == spot.id ?
                        PSColors.primaryGreen : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: PSSpacing.md) {
            ProgressView()
                .tint(PSColors.primaryGreen)

            Text(String(localized: "Finding nearby locations..."))
                .font(PSTypography.body)
                .foregroundStyle(PSColors.textSecondary)
        }
        .frame(maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .background(PSColors.backgroundPrimary)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        PSEmptyState(
            icon: "map.fill",
            title: String(localized: "No locations found"),
            message: String(localized: "Try a different category or location"),
            actionTitle: String(localized: "Try Again"),
            action: {
                Task {
                    await loadNearbySpots()
                }
            }
        )
    }

    // MARK: - Selected Location Card

    private func selectedLocationCard(_ spot: NeutralSpot) -> some View {
        VStack(spacing: PSSpacing.md) {
            PSCard {
                VStack(alignment: .leading, spacing: PSSpacing.md) {
                    HStack(spacing: PSSpacing.md) {
                        Image(systemName: spot.category.icon)
                            .font(.system(size: PSLayout.scaledFont(24)))
                            .foregroundStyle(spot.category.color)

                        VStack(alignment: .leading, spacing: PSSpacing.xs) {
                            Text(String(localized: "Selected Location"))
                                .font(PSTypography.caption1)
                                .foregroundStyle(PSColors.textSecondary)

                            Text(spot.name)
                                .font(PSTypography.headline)
                                .foregroundStyle(PSColors.textPrimary)
                        }

                        Spacer()
                    }

                    Text(spot.address)
                        .font(PSTypography.body)
                        .foregroundStyle(PSColors.textSecondary)

                    HStack(spacing: PSSpacing.md) {
                        Image(systemName: "location.fill")
                            .font(.system(size: PSLayout.scaledFont(14)))
                            .foregroundStyle(PSColors.infoBlue)

                        Text(String(localized: "Your home address is never shared"))
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                    }
                    .padding(.vertical, PSSpacing.sm)
                    .padding(.horizontal, PSSpacing.md)
                    .background(PSColors.infoBlue.opacity(0.08))
                    .cornerRadius(PSSpacing.radiusSm)
                }
            }

            PSButton(
                title: String(localized: "Confirm Location"),
                style: .primary,
                isFullWidth: true,
                action: {
                    onLocationSelected?(spot)
                    dismiss()
                }
            )
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.bottom, PSSpacing.xxl)
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }

    // MARK: - Helpers

    private var filteredSpots: [NeutralSpot] {
        if let category = selectedCategory {
            return neutralSpotService.spots.filter { $0.category == category }
        }
        return neutralSpotService.spots
    }

    private func loadNearbySpots() async {
        isLoadingSpots = true
        defer { isLoadingSpots = false }

        if let location = CLLocationManager().location?.coordinate {
            userLocation = location
            _ = await neutralSpotService.searchNearbySpots(near: location)
        }
    }

    private func toggleCustomPinMode() {
        showCustomPinMode.toggle()
        // In a full implementation, would allow user to tap map to place pin
    }
}

// MARK: - Category Color Extension

extension NeutralSpotCategory {
    var color: Color {
        switch self {
        case .coffeeShop: return PSColors.warningAmber
        case .communityCenter: return PSColors.accentTeal
        case .library: return PSColors.infoBlue
        case .park: return PSColors.primaryGreen
        case .groceryStore: return PSColors.freshGreen
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PickupLocationView()
            .environment(NeutralSpotService())
    }
}

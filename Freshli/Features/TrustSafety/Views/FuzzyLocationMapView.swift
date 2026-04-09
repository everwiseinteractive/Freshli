import SwiftUI
import MapKit

/// Displays a fuzzy 100m radius circle for available food locations.
/// The exact "Safe Handoff Point" is only revealed after the claim is approved.
struct FuzzyLocationMapView: View {
    let fuzzyLocation: FuzzyLocation
    let isClaimApproved: Bool
    let safeHandoffPoint: SafeHandoffPoint?

    @State private var cameraPosition: MapCameraPosition
    @State private var revealHandoff = false

    init(
        fuzzyLocation: FuzzyLocation,
        isClaimApproved: Bool = false,
        safeHandoffPoint: SafeHandoffPoint? = nil
    ) {
        self.fuzzyLocation = fuzzyLocation
        self.isClaimApproved = isClaimApproved
        self.safeHandoffPoint = safeHandoffPoint
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: fuzzyLocation.center,
                latitudinalMeters: 400,
                longitudinalMeters: 400
            )
        ))
    }

    var body: some View {
        VStack(spacing: PSSpacing.md) {
            mapContent
                .frame(height: PSLayout.scaled(200))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                        .stroke(PSColors.border, lineWidth: 0.5)
                )

            locationLabel
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapContent: some View {
        Map(position: $cameraPosition) {
            // Fuzzy radius circle — always visible
            MapCircle(center: fuzzyLocation.center, radius: fuzzyLocation.radiusMeters)
                .foregroundStyle(PSColors.primaryGreen.opacity(0.15))
                .stroke(PSColors.primaryGreen.opacity(0.4), lineWidth: 1.5)

            // Safe handoff pin — only after claim approval + reveal
            if isClaimApproved, revealHandoff, let point = safeHandoffPoint {
                Annotation(
                    point.name ?? String(localized: "Pickup Point"),
                    coordinate: point.coordinate.clLocationCoordinate
                ) {
                    handoffAnnotation
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var handoffAnnotation: some View {
        ZStack {
            Circle()
                .fill(PSColors.primaryGreen)
                .frame(width: 32, height: 32)
                .shadow(color: PSColors.primaryGreen.opacity(0.3), radius: 6, y: 2)

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Label

    @ViewBuilder
    private var locationLabel: some View {
        if isClaimApproved, let point = safeHandoffPoint {
            if revealHandoff {
                handoffRevealedLabel(point: point)
            } else {
                revealButton
            }
        } else {
            fuzzyLabel
        }
    }

    @ViewBuilder
    private var fuzzyLabel: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 14))
                .foregroundStyle(PSColors.textTertiary)

            Text("Approximate location (100m radius)")
                .font(PSTypography.footnote)
                .foregroundStyle(PSColors.textSecondary)
        }
    }

    @ViewBuilder
    private var revealButton: some View {
        Button {
            PSHaptics.shared.mediumTap()
            withAnimation(PSMotion.springDefault) {
                revealHandoff = true
            }
            // Re-center on the handoff point
            if let point = safeHandoffPoint {
                withAnimation(PSMotion.easeSlow) {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: point.coordinate.clLocationCoordinate,
                            latitudinalMeters: 300,
                            longitudinalMeters: 300
                        )
                    )
                }
            }
        } label: {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 14, weight: .semibold))

                Text("Reveal Safe Handoff Point")
                    .font(PSTypography.calloutMedium)
            }
            .foregroundStyle(PSColors.primaryGreen)
            .padding(.vertical, PSSpacing.sm)
            .padding(.horizontal, PSSpacing.lg)
            .background(PSColors.primaryGreen.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func handoffRevealedLabel(point: SafeHandoffPoint) -> some View {
        VStack(spacing: PSSpacing.xs) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PSColors.primaryGreen)

                Text(point.name ?? String(localized: "Safe Handoff Point"))
                    .font(PSTypography.calloutMedium)
                    .foregroundStyle(PSColors.textPrimary)
            }

            if let notes = point.notes, !notes.isEmpty {
                Text(notes)
                    .font(PSTypography.footnote)
                    .foregroundStyle(PSColors.textSecondary)
            }
        }
        .transition(PSMotion.fadeSlide)
    }
}

// MARK: - Fuzzy Location Card (for listing cards)

struct FuzzyLocationCard: View {
    let latitude: Double
    let longitude: Double
    let isClaimApproved: Bool
    let safeHandoffPoint: SafeHandoffPoint?

    var body: some View {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let fuzzy = FuzzyLocation.fuzzy(from: coordinate)

        PSGlassCard {
            VStack(spacing: PSSpacing.md) {
                HStack {
                    Label {
                        Text("Location")
                            .font(PSTypography.footnoteMedium)
                    } icon: {
                        Image(systemName: "location.circle.fill")
                            .foregroundStyle(PSColors.primaryGreen)
                    }
                    .foregroundStyle(PSColors.textPrimary)

                    Spacer()

                    if !isClaimApproved {
                        PSBadge(text: String(localized: "Approximate"), style: .subtle)
                    }
                }

                FuzzyLocationMapView(
                    fuzzyLocation: fuzzy,
                    isClaimApproved: isClaimApproved,
                    safeHandoffPoint: safeHandoffPoint
                )
            }
        }
    }
}

#Preview {
    let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    let fuzzy = FuzzyLocation.fuzzy(from: coordinate)

    ScrollView {
        VStack(spacing: 20) {
            FuzzyLocationMapView(
                fuzzyLocation: fuzzy,
                isClaimApproved: false
            )

            FuzzyLocationMapView(
                fuzzyLocation: fuzzy,
                isClaimApproved: true,
                safeHandoffPoint: SafeHandoffPoint(
                    coordinate: CodableCoordinate(latitude: 37.7750, longitude: -122.4190),
                    name: "Corner of Market & 3rd",
                    notes: "Meet by the coffee shop entrance"
                )
            )
        }
        .padding()
    }
}

import SwiftUI
import Combine

// MARK: - Claim Status View

struct ClaimStatusView: View {
    let claim: ClaimReservation
    let listing: CommunityListingDTO

    @Environment(SmartReservationService.self) private var smartReservationService
    @Environment(GoodNeighborService.self) private var goodNeighborService
    @Environment(\.dismiss) private var dismiss

    @State private var timeRemaining: TimeInterval = 0
    @State private var showQualityRating = false
    @State private var selectedRating: Int = 5
    @State private var showCancelConfirm = false
    @State private var showEnRouteConfirm = false
    @State private var status: ClaimStatus = .active

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xxl) {
                    // Countdown Ring
                    countdownSection

                    // Item Details
                    itemDetailsCard

                    // Pickup Info
                    if let address = listing.pickupAddress {
                        pickupInfoCard(address)
                    }

                    // Action Buttons
                    actionButtonsSection

                    Spacer()
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.xxl)
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle(String(localized: "Claim Status"))
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
            .onReceive(timer) { _ in
                updateTimer()
            }
            .onAppear {
                timeRemaining = claim.remainingTime
                status = claim.status
            }
            .sheet(isPresented: $showQualityRating) {
                qualityRatingSheet
                    .presentationDragIndicator(.visible)
                    .sheetTransition()
            }
            .alert(String(localized: "Confirm En Route"), isPresented: $showEnRouteConfirm) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "I'm En Route"), role: .none) {
                    confirmEnRoute()
                }
            } message: {
                Text(String(localized: "Confirm that you're on your way to pick up this item. Your claim will no longer expire."))
            }
            .alert(String(localized: "Cancel Claim"), isPresented: $showCancelConfirm) {
                Button(String(localized: "Keep Claim"), role: .cancel) {}
                Button(String(localized: "Cancel"), role: .destructive) {
                    cancelClaim()
                }
            } message: {
                Text(String(localized: "Are you sure? The item will return to the community feed."))
            }
        }
    }

    // MARK: - Countdown Section

    private var countdownSection: some View {
        VStack(spacing: PSSpacing.lg) {
            Text(String(localized: "Time Remaining"))
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textSecondary)

            ZStack {
                // Background circle
                Circle()
                    .fill(PSColors.surfaceCard)
                    .frame(width: 200, height: 200)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progressRatio)
                    .stroke(
                        statusColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                // Time display
                VStack(spacing: PSSpacing.sm) {
                    if status == .expired || timeRemaining <= 0 {
                        Text(String(localized: "Expired"))
                            .font(PSTypography.headline)
                            .foregroundStyle(PSColors.expiredRed)
                    } else {
                        Text(claim.formattedTimeRemaining)
                            .font(.system(size: PSLayout.scaledFont(48), weight: .bold, design: .monospaced))
                            .foregroundStyle(statusColor)

                        Text(String(localized: "minutes remaining"))
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }
            }

            // Status Badge
            PSBadge(
                text: status.displayName,
                color: statusColor,
                style: .filled
            )
        }
    }

    // MARK: - Item Details Card

    private var itemDetailsCard: some View {
        PSCard {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                HStack(spacing: PSSpacing.md) {
                    VStack(alignment: .center) {
                        Image(listing.categoryImageAsset)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

                        Text(listing.foodCategory ?? "")
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                    }
                    .frame(width: 60)

                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text(listing.itemName)
                            .font(PSTypography.headline)
                            .foregroundStyle(PSColors.textPrimary)

                        if let description = listing.itemDescription {
                            Text(description)
                                .font(PSTypography.caption1)
                                .foregroundStyle(PSColors.textSecondary)
                                .lineLimit(2)
                        }

                        if let quantity = listing.quantity {
                            Text("Qty: \(quantity)")
                                .font(PSTypography.body)
                                .foregroundStyle(PSColors.textSecondary)
                        }
                    }

                    Spacer()
                }

                if let expiry = listing.expiryDate {
                    Divider()

                    HStack(spacing: PSSpacing.md) {
                        Image(systemName: "calendar")
                            .font(.system(size: PSLayout.scaledFont(16)))
                            .foregroundStyle(PSColors.textSecondary)

                        VStack(alignment: .leading, spacing: PSSpacing.xs) {
                            Text(String(localized: "Expires"))
                                .font(PSTypography.caption1)
                                .foregroundStyle(PSColors.textSecondary)

                            Text(expiry.formatted(.dateTime.month().day().year()))
                                .font(PSTypography.body)
                                .foregroundStyle(PSColors.textPrimary)
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Pickup Info Card

    private func pickupInfoCard(_ address: String) -> some View {
        PSCard {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                HStack(spacing: PSSpacing.md) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(24)))
                        .foregroundStyle(PSColors.accentTeal)

                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text(String(localized: "Pickup Location"))
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)

                        Text(address)
                            .font(PSTypography.body)
                            .foregroundStyle(PSColors.textPrimary)
                    }

                    Spacer()
                }

                if let notes = listing.pickupNotes {
                    Divider()

                    HStack(spacing: PSSpacing.md) {
                        Image(systemName: "note.text")
                            .font(.system(size: PSLayout.scaledFont(16)))
                            .foregroundStyle(PSColors.textSecondary)

                        Text(notes)
                            .font(PSTypography.body)
                            .foregroundStyle(PSColors.textSecondary)

                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: PSSpacing.md) {
            if status != .completed && status != .expired {
                PSButton(
                    title: String(localized: "I'm En Route"),
                    style: .primary,
                    isFullWidth: true,
                    action: { showEnRouteConfirm = true }
                )

                PSButton(
                    title: String(localized: "Cancel Claim"),
                    style: .secondary,
                    isFullWidth: true,
                    action: { showCancelConfirm = true }
                )
            } else if status == .completed {
                PSButton(
                    title: String(localized: "Rate Quality"),
                    style: .primary,
                    isFullWidth: true,
                    action: { showQualityRating = true }
                )
            }
        }
    }

    // MARK: - Quality Rating Sheet

    private var qualityRatingSheet: some View {
        NavigationStack {
            VStack(spacing: PSSpacing.xxl) {
                VStack(spacing: PSSpacing.md) {
                    Text(String(localized: "Rate the Quality"))
                        .font(PSTypography.title2)
                        .foregroundStyle(PSColors.textPrimary)

                    Text(String(localized: "How was the quality of the item?"))
                        .font(PSTypography.body)
                        .foregroundStyle(PSColors.textSecondary)
                }

                // Star Rating
                HStack(spacing: PSSpacing.md) {
                    ForEach(1...5, id: \.self) { rating in
                        Button(action: { selectedRating = rating }) {
                            Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: PSLayout.scaledFont(36)))
                                .foregroundStyle(
                                    rating <= selectedRating ?
                                    PSColors.warningAmber : PSColors.textTertiary
                                )
                        }
                    }
                }

                Spacer()

                PSButton(
                    title: String(localized: "Submit Rating"),
                    style: .primary,
                    isFullWidth: true,
                    action: { submitRating() }
                )
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.xxl)
            .background(PSColors.backgroundPrimary)
            .navigationTitle(String(localized: "Quality Rating"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showQualityRating = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: PSLayout.scaledFont(24)))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func confirmEnRoute() {
        _ = smartReservationService.confirmEnRoute(reservationId: claim.id)
        status = .enRoute
    }

    private func cancelClaim() {
        _ = smartReservationService.cancelClaim(reservationId: claim.id)
        dismiss()
    }

    private func submitRating() {
        _ = smartReservationService.completeHandoff(
            reservationId: claim.id,
            qualityRating: selectedRating,
            goodNeighborService: goodNeighborService
        )
        status = .completed
        showQualityRating = false
    }

    private func updateTimer() {
        timeRemaining = claim.remainingTime
        if timeRemaining <= 0 {
            status = .expired
        }
    }

    // MARK: - Computed Properties

    private var progressRatio: CGFloat {
        let total = claim.expiryInterval
        guard total > 0 else { return 0 }
        let remaining = max(0, claim.remainingTime)
        return CGFloat(remaining / total)
    }

    private var statusColor: Color {
        switch status {
        case .active:
            return PSColors.primaryGreen
        case .enRoute:
            return PSColors.accentTeal
        case .expired:
            return PSColors.expiredRed
        case .completed:
            return PSColors.primaryGreen
        }
    }
}

// MARK: - Extension for Claim

extension ClaimReservation {
    var expiryInterval: TimeInterval {
        expiresAt.timeIntervalSince(claimedAt)
    }
}

// MARK: - Preview

#Preview {
    let mockListing = CommunityListingDTO(
        id: UUID(),
        userId: UUID(),
        itemName: "Fresh Tomatoes",
        itemDescription: "Organic, locally grown",
        quantity: 5,
        listingType: "share",
        status: "claimed",
        pickupAddress: "Main St & Central Ave",
        pickupNotes: "Meet at the coffee shop parking lot",
        claimedBy: UUID(),
        datePosted: Date(),
        expiryDate: Date().addingTimeInterval(86400),
        completedAt: nil,
        foodCategory: "vegetables",
        areaName: nil,
        imageUrls: nil,
        reportCount: nil,
        isFlagged: nil,
        profiles: nil
    )

    let mockClaim = ClaimReservation(
        id: UUID(),
        listingId: UUID(),
        claimerId: UUID(),
        claimedAt: Date(),
        expiresAt: Date().addingTimeInterval(3600)
    )

    return NavigationStack {
        ClaimStatusView(claim: mockClaim, listing: mockListing)
            .environment(SmartReservationService())
            .environment(GoodNeighborService())
    }
}

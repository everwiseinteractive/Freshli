import SwiftUI
import SwiftData

// MARK: - Listing Detail View
// Full-screen detail for a community listing with claim, manage, and report actions.

struct ListingDetailView: View {
    let listing: CommunityListingDTO
    var onDismissAction: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(CommunityService.self) private var communityService
    @Environment(CelebrationManager.self) private var celebrationManager
    @Environment(SyncService.self) private var syncService

    @State private var isClaiming = false
    @State private var showClaimSuccess = false
    @State private var showConfirmDelete = false
    @State private var errorMessage: String?
    @State private var successFlashTrigger = false
    @State private var errorShakeTrigger = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isOwner: Bool {
        guard let userId = authManager.currentUserId else { return false }
        return listing.userId == userId
    }

    private var canClaim: Bool {
        authManager.authState == .authenticated && !isOwner && listing.status == "active"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero header
                heroHeader

                // Content
                VStack(alignment: .leading, spacing: PSSpacing.xxl) {
                    itemInfoSection
                    descriptionSection
                    pickupSection
                    posterSection
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.top, PSSpacing.xxl)
                .padding(.bottom, PSLayout.scaled(120))
            }
        }
        .background(PSColors.backgroundPrimary)
        .overlay(alignment: .bottom) {
            bottomActionBar
        }
        .successFlash(trigger: $successFlashTrigger)
        .errorShake(trigger: $errorShakeTrigger)
        .navigationTitle(String(localized: "Listing Details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(24)))
                        .foregroundStyle(PSColors.textTertiary)
                }
            }
        }
        .overlay {
            PSSuccessCelebration(
                isPresented: $showClaimSuccess,
                title: String(localized: "Claimed!"),
                description: String(localized: "You've claimed this item. Check the listing for pickup details and coordinate with the poster."),
                actionLabel: String(localized: "Got it"),
                icon: "hand.thumbsup.fill"
            )
        }
        .alert(String(localized: "Error"), isPresented: .constant(errorMessage != nil)) {
            Button(String(localized: "OK"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .alert(String(localized: "Remove Listing"), isPresented: $showConfirmDelete) {
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Remove"), role: .destructive) {
                Task {
                    let success = await communityService.deleteListing(listingId: listing.id) ?? false
                    if success {
                        onDismissAction?()
                        dismiss()
                    } else {
                        errorMessage = String(localized: "Failed to remove listing. Please try again.")
                    }
                }
            }
        } message: {
            Text(String(localized: "This will permanently remove your listing from the community feed."))
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background based on category
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: categoryGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: PSLayout.heroHeight)
                .overlay(alignment: .center) {
                    Text(listing.categoryEmoji)
                        .font(.system(size: PSLayout.scaledFont(72)))
                        .opacity(0.3)
                }

            // Status + type overlays
            HStack(spacing: 8) {
                PSBadge(
                    text: listing.isGiveaway
                        ? String(localized: "Giveaway")
                        : String(localized: "Donation"),
                    variant: listing.isGiveaway ? .shared : .donated
                )

                PSBadge(
                    text: statusText,
                    variant: statusVariant
                )
            }
            .padding(PSSpacing.lg)
        }
    }

    // MARK: - Item Info

    private var itemInfoSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack(alignment: .top) {
                Text(listing.itemName)
                    .font(.system(size: PSLayout.scaledFont(28), weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(PSColors.textPrimary)

                Spacer()

                if let qty = listing.quantity, qty > 0 {
                    VStack(spacing: 2) {
                        Text("\(qty)")
                            .font(.system(size: PSLayout.scaledFont(22), weight: .bold))
                            .foregroundStyle(PSColors.primaryGreen)
                        Text(String(localized: "qty"))
                            .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                    .adaptiveFrame(width: 52, height: 52)
                    .background(PSColors.primaryGreen.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                }
            }

            // Category + time
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text(listing.categoryEmoji)
                    Text(listing.foodCategory?.capitalized ?? String(localized: "Other"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                }

                if !listing.timeAgo.isEmpty {
                    Text("•")
                        .foregroundStyle(PSColors.textTertiary)
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: PSLayout.scaledFont(12)))
                        Text(listing.timeAgo)
                    }
                    .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                }

                if let area = listing.areaName {
                    Text("•")
                        .foregroundStyle(PSColors.textTertiary)
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: PSLayout.scaledFont(12)))
                        Text(area)
                    }
                    .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Description

    @ViewBuilder
    private var descriptionSection: some View {
        if let desc = listing.itemDescription, !desc.isEmpty {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                Text(String(localized: "About this item"))
                    .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)

                Text(desc)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                    .foregroundStyle(PSColors.textPrimary)
                    .lineSpacing(6)
            }
        }
    }

    // MARK: - Pickup Info

    @ViewBuilder
    private var pickupSection: some View {
        if listing.pickupAddress != nil || listing.pickupNotes != nil {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                Text(String(localized: "Pickup Information"))
                    .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)

                VStack(alignment: .leading, spacing: PSSpacing.md) {
                    if let address = listing.pickupAddress {
                        HStack(alignment: .top, spacing: PSSpacing.md) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(PSColors.primaryGreen)
                                .frame(width: 24)

                            Text(address)
                                .font(.system(size: PSLayout.scaledFont(15), weight: .medium))
                                .foregroundStyle(PSColors.textPrimary)
                        }
                    }

                    if let notes = listing.pickupNotes {
                        HStack(alignment: .top, spacing: PSSpacing.md) {
                            Image(systemName: "note.text")
                                .font(.system(size: 16))
                                .foregroundStyle(PSColors.secondaryAmber)
                                .frame(width: 24)

                            Text(notes)
                                .font(.system(size: PSLayout.scaledFont(15), weight: .medium))
                                .foregroundStyle(PSColors.textPrimary)
                        }
                    }
                }
                .padding(PSSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PSColors.primaryGreen.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            }
        }
    }

    // MARK: - Poster Info

    private var posterSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text(String(localized: "Posted by"))
                .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                .foregroundStyle(PSColors.textSecondary)

            HStack(spacing: PSSpacing.md) {
                Text(listing.initials)
                    .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: PSLayout.communityAvatarSize, height: PSLayout.communityAvatarSize)
                    .background(avatarColor)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.displayName)
                        .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)

                    Text(isOwner ? String(localized: "You") : String(localized: "Community Member"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()
            }
            .padding(PSSpacing.lg)
            .background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                    .strokeBorder(PSColors.borderLight, lineWidth: 1)
            )
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()

            Group {
                if isOwner {
                    ownerActions
                } else if canClaim {
                    claimAction
                } else if listing.status != "active" {
                    statusInfoBar
                } else {
                    signInPrompt
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
            .background(.ultraThinMaterial)
        }
    }

    private var ownerActions: some View {
        HStack(spacing: 12) {
            if listing.status == "active" || listing.status == "claimed" {
                PSButton(
                    title: String(localized: "Mark Complete"),
                    icon: "checkmark.circle.fill",
                    style: .primary,
                    size: .medium
                ) {
                    Task {
                        let success = await communityService.updateListingStatus(
                            listingId: listing.id, newStatus: "completed"
                        ) ?? false
                        if success {
                            onDismissAction?()
                            dismiss()
                        }
                    }
                }

                PSButton(
                    title: String(localized: "Remove"),
                    icon: "trash",
                    style: .destructive,
                    size: .medium,
                    isFullWidth: false
                ) {
                    showConfirmDelete = true
                }
            } else {
                Text(String(localized: "This listing is \(statusText.lowercased())"))
                    .font(.system(size: PSLayout.scaledFont(15), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var claimAction: some View {
        PSButton(
            title: String(localized: "Claim This Item"),
            icon: "hand.raised.fill",
            isLoading: isClaiming
        ) {
            claimItem()
        }
    }

    private var statusInfoBar: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: statusIcon)
                .font(.system(size: 18))
            Text(String(localized: "This item has been \(statusText.lowercased())"))
                .font(.system(size: PSLayout.scaledFont(15), weight: .medium))
        }
        .foregroundStyle(PSColors.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var signInPrompt: some View {
        VStack(spacing: 8) {
            Text(String(localized: "Sign in to claim this item"))
                .font(.system(size: PSLayout.scaledFont(15), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func claimItem() {
        guard let userId = authManager.currentUserId else { return }
        PSHaptics.shared.mediumTap()
        isClaiming = true

        Task {
            let success = await communityService.claimListing(
                listingId: listing.id, claimerId: userId
            ) ?? false

            isClaiming = false

            if success {
                PSHaptics.shared.celebrate()
                successFlashTrigger = true
                showClaimSuccess = true
                AnalyticsService.shared.track(.listingClaimed, properties: .props([
                    "listing_type": listing.listingType
                ]))

                // Trigger celebration
                celebrationManager.fireShareCompleted(
                    itemName: listing.itemName,
                    modelContext: modelContext
                )

                // Record impact event
                await syncService.recordImpactEvent(
                    userId: userId,
                    eventType: "item_rescued",
                    itemName: listing.itemName
                )

                // Update widget data
                WidgetDataService.updateWidgetData(modelContext: modelContext)

                // Schedule pickup reminder notification
                let notificationService = NotificationService()
                notificationService.scheduleCommunityReminder(
                    title: String(localized: "Pick up your claimed item"),
                    body: String(localized: "Don't forget to pick up \(listing.itemName)!"),
                    delayHours: 2
                )

                onDismissAction?()
            } else {
                errorMessage = String(localized: "Failed to claim this item. Please try again.")
                errorShakeTrigger = true
            }
        }
    }

    // MARK: - Computed Helpers

    private var statusText: String {
        switch listing.status {
        case "active": return String(localized: "Active")
        case "claimed": return String(localized: "Claimed")
        case "completed": return String(localized: "Completed")
        case "expired": return String(localized: "Expired")
        default: return listing.status.capitalized
        }
    }

    private var statusVariant: PSBadgeVariant {
        switch listing.status {
        case "active": return .fresh
        case "claimed": return .claimed
        case "completed": return .shared
        case "expired": return .expired
        default: return .default
        }
    }

    private var statusIcon: String {
        switch listing.status {
        case "claimed": return "person.fill.checkmark"
        case "completed": return "checkmark.circle.fill"
        case "expired": return "clock.badge.exclamationmark"
        default: return "info.circle"
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [
            Color(hex: 0xFBBF24), Color(hex: 0x60A5FA), Color(hex: 0x4ADE80),
            Color(hex: 0xC084FC), Color(hex: 0xF87171), Color(hex: 0x2DD4BF)
        ]
        let hash = abs(listing.displayName.hashValue)
        return colors[hash % colors.count]
    }

    private var categoryGradient: [Color] {
        switch listing.foodCategory {
        case "fruits": return [Color(hex: 0xFDE68A), Color(hex: 0xFBBF24)]
        case "vegetables": return [Color(hex: 0xBBF7D0), Color(hex: 0x4ADE80)]
        case "dairy": return [Color(hex: 0xE0E7FF), Color(hex: 0xA5B4FC)]
        case "meat": return [Color(hex: 0xFECACA), Color(hex: 0xF87171)]
        case "bakery": return [Color(hex: 0xFED7AA), Color(hex: 0xFB923C)]
        case "grains": return [Color(hex: 0xFEF3C7), Color(hex: 0xF59E0B)]
        case "frozen": return [Color(hex: 0xCFFAFE), Color(hex: 0x22D3EE)]
        case "canned": return [Color(hex: 0xFECACA), Color(hex: 0xEF4444)]
        case "beverages": return [Color(hex: 0xD1FAE5), Color(hex: 0x10B981)]
        case "snacks": return [Color(hex: 0xFBCFE8), Color(hex: 0xEC4899)]
        default: return [Color(hex: 0xE5E7EB), Color(hex: 0x9CA3AF)]
        }
    }
}

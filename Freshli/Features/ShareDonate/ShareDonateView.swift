import SwiftUI
import SwiftData

struct ShareDonateView: View {
    @Query private var listings: [SharedListing]
    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?
    @Environment(PSToastManager.self) private var toastManager: PSToastManager?

    @State private var selectedType: ListingType = .share
    @State private var showCreateListing = false
    @State private var showConfirmation = false

    private var activeListings: [SharedListing] {
        listings.filter { $0.listingType == selectedType && $0.status == .active }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerControls

            if activeListings.isEmpty {
                emptyState
            } else {
                listingsContent
            }
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Share & Donate"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateListing = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }
        }
        .sheet(isPresented: $showCreateListing) {
            NavigationStack {
                CreateListingView(listingType: selectedType)
            }
            .presentationDragIndicator(.visible)
        }
    }

    private var headerControls: some View {
        VStack(spacing: PSSpacing.lg) {
            PSSegmentedControl(
                items: ListingType.allCases,
                selection: $selectedType,
                titleFor: { $0.displayName }
            )

            // Info banner
            HStack(spacing: PSSpacing.md) {
                Image(systemName: selectedType == .share ? "person.2.fill" : "heart.fill")
                    .foregroundStyle(selectedType == .share ? PSColors.infoBlue : PSColors.accentTeal)

                Text(selectedType == .share
                     ? String(localized: "Share surplus food with your local community")
                     : String(localized: "Donate to local food banks and charities"))
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)

                Spacer()
            }
            .padding(PSSpacing.md)
            .background(
                (selectedType == .share ? PSColors.infoBlue : PSColors.accentTeal).opacity(0.08)
            )
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
        .padding(.vertical, PSSpacing.md)
    }

    private var listingsContent: some View {
        ScrollView {
            LazyVStack(spacing: PSSpacing.md) {
                ForEach(Array(activeListings.enumerated()), id: \.element.id) { index, listing in
                    ListingCard(listing: listing) {
                        PSHaptics.shared.success()
                        let itemName = listing.itemName
                        withAnimation(PSMotion.springDefault) {
                            listing.status = .completed
                            do {
                                try modelContext.save()
                                PSLogger.general.info("Listing marked as completed: \(itemName)")
                            } catch {
                                PSLogger.general.error("Failed to mark listing completed: \(error.localizedDescription)")
                                toastManager?.show(.error(String(localized: "Failed to save")))
                                return
                            }
                        }
                        if listing.listingType == .share {
                            toastManager?.show(.itemShared(itemName))
                            celebrationManager?.onShareCompleted(itemName: itemName, modelContext: modelContext)
                        } else {
                            toastManager?.show(.itemDonated(itemName))
                            celebrationManager?.onDonationCompleted(itemName: itemName, modelContext: modelContext)
                        }
                        WidgetDataService.updateWidgetData(modelContext: modelContext)
                    }
                    .staggeredAppearance(index: index)
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.md)
        }
    }

    private var emptyState: some View {
        PSEmptyState(
            icon: selectedType == .share ? "hand.raised" : "heart",
            title: selectedType == .share
                ? String(localized: "No Shared Items")
                : String(localized: "No Donations Yet"),
            message: selectedType == .share
                ? String(localized: "Share surplus food with neighbors. Every item helps reduce waste.")
                : String(localized: "Donate larger surpluses to local food banks and make a difference."),
            actionTitle: selectedType == .share
                ? String(localized: "Share Something")
                : String(localized: "Donate Food")
        ) {
            showCreateListing = true
        }
        .frame(maxHeight: .infinity)
    }
}

struct ListingCard: View {
    let listing: SharedListing
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                    Text(listing.itemName)
                        .font(PSTypography.bodyMedium)
                        .foregroundStyle(PSColors.textPrimary)
                    Text(listing.itemDescription)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                PSBadge(
                    text: listing.listingType.displayName,
                    color: listing.listingType == .share ? PSColors.infoBlue : PSColors.accentTeal,
                    style: .subtle
                )
            }

            Divider()

            HStack(spacing: PSSpacing.lg) {
                Label(listing.quantity, systemImage: "number")
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)

                Label(listing.expiryDate.shortDisplay, systemImage: "calendar")
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)

                Spacer()

                Button {
                    onComplete()
                } label: {
                    Text(String(localized: "Mark Done"))
                        .font(PSTypography.caption1Medium)
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }

            if !listing.pickupAddress.isEmpty {
                Label(listing.pickupAddress, systemImage: "mappin.and.ellipse")
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(PSSpacing.cardPadding)
        .cardStyle()
    }
}

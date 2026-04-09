import SwiftUI
import MapKit

// MARK: - Freshli Community Marketplace View
struct FreshliCommunityMarketplaceView: View {
    @State private var viewModel = CommunityMarketplaceViewModel()
    @State private var selectedListing: SupabaseListing?
    @State private var showListingSheet = false
    @State private var showReportConfirmation = false
    @State private var showBlockConfirmation = false
    @State private var reportingListing: SupabaseListing?
    @State private var blockingUserId: UUID?
    @State private var claimingListingId: UUID?
    @State private var showCreateListing = false
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @Namespace private var segmentNamespace

    @Environment(\.colorScheme) private var colorScheme
    @Environment(AuthManager.self) private var authManager: AuthManager?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Header with title and filter
                headerSection

                // View mode toggle
                viewModeToggle

                // Content based on view mode
                if viewModel.viewMode == .list {
                    listModeContent
                } else {
                    mapModeContent
                }
            }
            .background(PSColors.backgroundPrimary)

            // FAB for sharing food
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    PSIconButton(
                        icon: "plus",
                        size: PSLayout.fabSize,
                        tint: .white,
                        background: PSColors.primaryGreen
                    ) {
                        showCreateListing = true
                    }
                    .padding(PSSpacing.xl)
                }
            }
        }
        .sheet(isPresented: $showListingSheet, onDismiss: { selectedListing = nil }) {
            if let listing = selectedListing {
                listingQuickPreviewSheet(for: listing)
            }
        }
        .sheet(isPresented: $showCreateListing) {
            CommunityCreateListingView(onComplete: { _ in showCreateListing = false })
        }
        .alert("Report Listing", isPresented: $showReportConfirmation, presenting: reportingListing) { listing in
            Button("Cancel", role: .cancel) {}
            Button("Report", role: .destructive) {
                Task {
                    do {
                        try await viewModel.reportListing(listing)
                        PSHaptics.shared.mediumTap()
                    } catch {
                        print("Error reporting listing: \(error)")
                    }
                }
            }
        } message: { listing in
            Text("Are you sure you want to report '\(listing.itemName)' as inappropriate?")
        }
        .alert("Block User", isPresented: $showBlockConfirmation, presenting: blockingUserId) { userId in
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) {
                viewModel.blockUser(userId)
                PSHaptics.shared.mediumTap()
            }
        } message: { _ in
            Text("You won't see listings from this user anymore. You can unblock them in settings.")
        }
        .task {
            await viewModel.loadListings()

            // Request location if available
            if let latitude = userLocation?.latitude, let longitude = userLocation?.longitude {
                await viewModel.loadNearbyListings(latitude: latitude, longitude: longitude)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Community Marketplace")
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack(alignment: .center, spacing: PSSpacing.md) {
                Text("Community\nMarketplace")
                    .font(PSTypography.title1)
                    .lineLimit(2)

                Spacer()

                categoryFilterMenu
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.md)
        }
        .background(PSColors.backgroundPrimary)
    }

    // MARK: - Category Filter Menu
    private var categoryFilterMenu: some View {
        Menu {
            Button("All Categories") {
                viewModel.selectedCategory = nil
            }

            ForEach(FoodCategory.allCases, id: \.self) { category in
                Button(action: { viewModel.selectedCategory = category }) {
                    HStack {
                        Text(category.emoji)
                        Text(category.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: PSSpacing.xs) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18, weight: .semibold))
                if let category = viewModel.selectedCategory {
                    Text(category.emoji)
                        .font(.system(size: 16))
                }
            }
            .foregroundColor(PSColors.textPrimary)
            .padding(PSSpacing.sm)
            .background(PSColors.surfaceCard)
            .clipShape(Circle())
        }
        .accessibilityLabel("Filter by category")
    }

    // MARK: - View Mode Toggle
    private var viewModeToggle: some View {
        HStack(spacing: PSSpacing.sm) {
            Spacer()

            ForEach([CommunityMarketplaceViewMode.list, .map], id: \.self) { mode in
                Button(action: {
                    withAnimation(.snappy(duration: 0.2)) {
                        viewModel.viewMode = mode
                    }
                }) {
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: mode == .list ? "list.bullet" : "map")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(
                        viewModel.viewMode == mode ? .white : PSColors.textSecondary
                    )
                    .background(
                        viewModel.viewMode == mode
                            ? PSColors.primaryGreen
                            : PSColors.surfaceCard
                    )
                    .clipShape(Capsule())
                }
                .accessibilityLabel(mode == .list ? "List view" : "Map view")
            }

            Spacer()
        }
        .padding(PSSpacing.md)
        .background(PSColors.backgroundPrimary)
    }

    // MARK: - List Mode Content
    private var listModeContent: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                // Recent Near You Section
                if !viewModel.recentNearYou.isEmpty {
                    VStack(alignment: .leading, spacing: PSSpacing.md) {
                        Text("Recent Near You")
                            .font(PSTypography.headline)
                            .padding(.horizontal, PSSpacing.screenHorizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: PSSpacing.md) {
                                ForEach(viewModel.recentNearYou, id: \.id) { listing in
                                    recentCardView(listing)
                                        .onTapGesture {
                                            selectedListing = listing
                                            showListingSheet = true
                                        }
                                }
                            }
                            .padding(.horizontal, PSSpacing.screenHorizontal)
                        }
                    }
                }

                // All Listings Section
                VStack(alignment: .leading, spacing: PSSpacing.md) {
                    Text("All Listings")
                        .font(PSTypography.headline)
                        .padding(.horizontal, PSSpacing.screenHorizontal)

                    if viewModel.isLoading {
                        loadingPlaceholders
                    } else if viewModel.filteredListings.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: PSSpacing.md) {
                            ForEach(viewModel.filteredListings, id: \.id) { listing in
                                allListingsCardView(listing)
                                    .onTapGesture {
                                        selectedListing = listing
                                        showListingSheet = true
                                    }
                            }
                        }
                        .padding(.horizontal, PSSpacing.screenHorizontal)
                    }
                }
            }
            .padding(.vertical, PSSpacing.xl)
        }
    }

    // MARK: - Recent Card View
    private func recentCardView(_ listing: SupabaseListing) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            // Placeholder image area
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        PSColors.primaryGreen.opacity(0.2),
                        PSColors.accentTeal.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Text(FoodCategory(rawValue: listing.foodCategory ?? "other")?.emoji ?? "🥬")
                    .font(.system(size: 36))
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))

            Text(listing.itemName)
                .font(PSTypography.calloutMedium)
                .lineLimit(2)
                .foregroundColor(PSColors.textPrimary)

            HStack(spacing: PSSpacing.xs) {
                if let expiryDate = listing.expiryDate {
                    let status = ExpiryStatus.from(expiryDate: expiryDate)
                    PSBadge(
                        text: status.displayName,
                        variant: .expiringSoon,
                        style: .subtle
                    )
                }
            }
        }
        .frame(width: 160)
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl))
    }

    // MARK: - All Listings Card View
    private func allListingsCardView(_ listing: SupabaseListing) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack(alignment: .top, spacing: PSSpacing.md) {
                // Category emoji
                Text(FoodCategory(rawValue: listing.foodCategory ?? "other")?.emoji ?? "🥬")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text(listing.itemName)
                        .font(PSTypography.headline)
                        .foregroundColor(PSColors.textPrimary)

                    if let description = listing.itemDescription, !description.isEmpty {
                        Text(description)
                            .font(PSTypography.caption1)
                            .foregroundColor(PSColors.textSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: PSSpacing.xs) {
                        if let expiryDate = listing.expiryDate {
                            let status = ExpiryStatus.from(expiryDate: expiryDate)
                            PSBadge(
                                text: status.displayName,
                                variant: .expiringSoon,
                                style: .filled
                            )
                        }

                        if let areaName = listing.areaName {
                            Text(areaName)
                                .font(PSTypography.caption2)
                                .foregroundColor(PSColors.textTertiary)
                        }

                        Spacer()
                    }
                }

                Spacer()
            }

            HStack(spacing: PSSpacing.sm) {
                Spacer()
                claimButton(for: listing)
            }
        }
        .padding(PSSpacing.cardPadding)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
    }

    // MARK: - Claim Button
    private func claimButton(for listing: SupabaseListing) -> some View {
        let isClaimed = viewModel.claimedListingIds.contains(listing.id)
        let isClaiming = claimingListingId == listing.id

        return Button(action: {
            Task {
                guard let userId = authManager?.currentUserId else { return }
                claimingListingId = listing.id
                do {
                    try await viewModel.claimListing(listing, claimerId: userId)
                    PSHaptics.shared.mediumTap()
                } catch {
                    print("Error claiming listing: \(error)")
                }
                claimingListingId = nil
            }
        }) {
            HStack(spacing: PSSpacing.xs) {
                if isClaiming {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isClaimed ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(isClaimed ? "Claimed" : "Claim")
                    .font(PSTypography.calloutMedium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, PSSpacing.md)
            .padding(.vertical, PSSpacing.sm)
            .background(
                isClaimed ? PSColors.accentTeal : PSColors.primaryGreen
            )
            .clipShape(Capsule())
        }
        .disabled(isClaimed || isClaiming)
    }

    // MARK: - Map Mode Content
    private var mapModeContent: some View {
        ZStack {
            Map(position: $mapCameraPosition) {
                ForEach(viewModel.annotations, id: \.id) { annotation in
                    Annotation("", coordinate: annotation.coordinate) {
                        mapAnnotationView(annotation)
                            .onTapGesture {
                                selectedListing = annotation.listing
                                showListingSheet = true
                            }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()
        }
    }

    // MARK: - Map Annotation View
    private func mapAnnotationView(_ annotation: MapAnnotationItem) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(PSColors.surfaceCard)
                    .frame(width: 44, height: 44)

                Text(FoodCategory(rawValue: annotation.listing.foodCategory ?? "other")?.emoji ?? "🥬")
                    .font(.system(size: 22))
            }
            .shadow(radius: 4)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundColor(PSColors.surfaceCard)
                .offset(y: -5)
        }
    }

    // MARK: - Listing Quick Preview Sheet
    private func listingQuickPreviewSheet(for listing: SupabaseListing) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            HStack(alignment: .top, spacing: PSSpacing.md) {
                Text(FoodCategory(rawValue: listing.foodCategory ?? "other")?.emoji ?? "🥬")
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text(listing.itemName)
                        .font(PSTypography.title3)
                        .foregroundColor(PSColors.textPrimary)

                    if let expiryDate = listing.expiryDate {
                        let status = ExpiryStatus.from(expiryDate: expiryDate)
                        PSBadge(
                            text: status.displayName,
                            variant: .expiringSoon,
                            style: .filled
                        )
                    }
                }

                Spacer()

                Menu {
                    Button("Report", action: {
                        reportingListing = listing
                        showReportConfirmation = true
                    })

                    Button("Block User", role: .destructive, action: {
                        blockingUserId = listing.userId
                        showBlockConfirmation = true
                    })
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PSColors.textSecondary)
                        .padding(PSSpacing.sm)
                        .background(PSColors.backgroundPrimary)
                        .clipShape(Circle())
                }
            }

            Divider()

            // Description
            if let description = listing.itemDescription, !description.isEmpty {
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text("Details")
                        .font(PSTypography.headline)
                        .foregroundColor(PSColors.textPrimary)

                    Text(description)
                        .font(PSTypography.body)
                        .foregroundColor(PSColors.textSecondary)
                }
            }

            // Pickup Info
            if let pickupAddress = listing.pickupAddress {
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text("Pickup Location")
                        .font(PSTypography.headline)
                        .foregroundColor(PSColors.textPrimary)

                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: "location.fill")
                            .foregroundColor(PSColors.primaryGreen)
                        Text(pickupAddress)
                            .font(PSTypography.body)
                            .foregroundColor(PSColors.textSecondary)
                    }
                }
            }

            if let pickupNotes = listing.pickupNotes, !pickupNotes.isEmpty {
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text("Pickup Notes")
                        .font(PSTypography.headline)
                        .foregroundColor(PSColors.textPrimary)

                    Text(pickupNotes)
                        .font(PSTypography.body)
                        .foregroundColor(PSColors.textSecondary)
                }
            }

            Spacer()

            claimButton(for: listing)
                .frame(maxWidth: .infinity)
        }
        .padding(PSSpacing.cardPadding)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: PSSpacing.lg) {
            Image(systemName: "basket")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(PSColors.textTertiary)

            VStack(spacing: PSSpacing.sm) {
                Text("No Listings Found")
                    .font(PSTypography.headline)
                    .foregroundColor(PSColors.textPrimary)

                Text("Try adjusting your filters or check back soon")
                    .font(PSTypography.body)
                    .foregroundColor(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PSSpacing.xxxl)
    }

    // MARK: - Loading Placeholders
    private var loadingPlaceholders: some View {
        VStack(spacing: PSSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: PSSpacing.radiusLg)
                    .fill(PSColors.surfaceCard)
                    .frame(height: 100)
                    .opacity(0.6)
            }
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }
}

// MARK: - Preview
#Preview {
    FreshliCommunityMarketplaceView()
        .environment(\.colorScheme, .light)
}

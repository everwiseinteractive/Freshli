import SwiftUI
import SwiftData
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - FLCommunityPage (Page)
// Community feed page — migrated to Atomic Design structure.
// Preserves all backend logic: CommunityService, listings,
// Magic Bag, report system, milestone card. No icon background boxes.
// ══════════════════════════════════════════════════════════════════

struct FLCommunityPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncService.self) private var syncService
    @Environment(CommunityService.self) private var communityService
    @Environment(NetworkMonitor.self) private var networkMonitor

    @State private var activeTab = 0
    @State private var showCreateListing = false
    @State private var showMagicBag = false
    @State private var showPostSuccess = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var selectedListing: CommunityListingDTO?
    @State private var showListingDetail = false
    @State private var showReportSheet = false
    @State private var reportTarget: CommunityListingDTO?
    @State private var reportReason = ""
    @State private var reportDetails = ""
    @State private var feedError: String?
    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logger = Logger(subsystem: "com.freshli.app", category: "FLCommunityPage")

    private let tabs = [
        String(localized: "Local Feed"),
        String(localized: "My Listings")
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Offline banner
                if networkMonitor.isConnected == false {
                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 14))
                        FLText(
                            localized: "You're offline. Showing cached listings.",
                            .caption,
                            color: .secondary
                        )
                    }
                    .foregroundStyle(PSColors.textSecondary)
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.vertical, PSSpacing.xs)
                    .frame(maxWidth: .infinity)
                    .background(PSColors.warningAmber.opacity(0.1))
                    .accessibilityLabel(String(localized: "Offline mode. Showing cached listings."))
                }

                stickyHeader
                feedContent
            }
            .background(PSColors.backgroundSecondary)

            fabButton
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCreateListing) {
            NavigationStack {
                CommunityCreateListingView { success in
                    if success {
                        showCreateListing = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(300))
                            showPostSuccess = true
                        }
                        Task { @MainActor in await refreshFeed() }
                    }
                }
            }
            .presentationDragIndicator(.visible)
            .sheetTransition()
        }
        .sheet(isPresented: $showMagicBag) {
            NavigationStack {
                MagicBagView { success in
                    showMagicBag = false
                    if success {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(300))
                            showPostSuccess = true
                        }
                        Task { @MainActor in await refreshFeed() }
                    }
                }
            }
            .presentationDragIndicator(.visible)
            .sheetTransition()
        }
        .sheet(item: $selectedListing) { listing in
            NavigationStack {
                ListingDetailView(listing: listing) {
                    Task { @MainActor in await refreshFeed() }
                }
            }
            .presentationDragIndicator(.visible)
            .sheetTransition()
        }
        .overlay {
            PSBottomSheet(isPresented: $showReportSheet, title: String(localized: "Report Listing")) {
                reportForm
            }
        }
        .overlay {
            PSSuccessCelebration(
                isPresented: $showPostSuccess,
                title: String(localized: "Posted!"),
                description: String(localized: "Your listing has been shared with the community. We'll notify you when someone is interested."),
                actionLabel: String(localized: "Done"),
                icon: "square.and.arrow.up"
            )
        }
        .task {
            logger.info("FLCommunityPage appeared — tab: \(activeTab)")
            await refreshFeed()
        }
    }

    // MARK: - Sticky Header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            // Title row
            HStack {
                FLText(localized: "Community", .displayLarge)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: PSSpacing.md)

                HStack(spacing: PSSpacing.sm) {
                    // Magic Bag shortcut — bare icon, no background box
                    Button {
                        PSHaptics.shared.lightTap()
                        showMagicBag = true
                    } label: {
                        Text("\u{1F381}")
                            .font(.system(size: PSLayout.scaledFont(16)))
                            .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: 0x7C3AED).opacity(0.12), Color(hex: 0xDB2777).opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(String(localized: "Post Magic Bag"))
                    .accessibilityHint(String(localized: "Double tap to create a Magic Bag listing"))

                    // Circles — bare icon, no background box
                    NavigationLink(destination: CirclesView()) {
                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: PSLayout.scaledFont(18), weight: .medium))
                            .foregroundStyle(PSColors.primaryGreen)
                            .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                    }
                    .accessibilityLabel(String(localized: "View Circles"))
                    .accessibilityHint(String(localized: "Double tap to open your community circles"))

                    // Shopping list — bare icon, no background box
                    NavigationLink(destination: ShoppingListView()) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: PSLayout.scaledFont(18), weight: .medium))
                            .foregroundStyle(PSColors.accentTeal)
                            .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                    }
                    .accessibilityLabel(String(localized: "View Shopping List"))
                    .accessibilityHint(String(localized: "Double tap to open your shopping list"))

                    // Search — bare icon, no background box
                    Button {
                        withAnimation(FLMotion.adaptive(PSMotion.springQuick, reduceMotion: reduceMotion)) { showSearch.toggle() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: PSLayout.scaledFont(18), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                            .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel(String(localized: "Search listings"))
                    .accessibilityHint(String(localized: "Double tap to toggle the search bar"))
                }
            }
            .adaptiveHPadding()
            .padding(.top, PSSpacing.md)
            .padding(.bottom, PSSpacing.lg)

            // Search bar (conditionally shown)
            if showSearch {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: PSLayout.scaledFont(16)))
                        .foregroundStyle(PSColors.textTertiary)

                    TextField(String(localized: "Search listings..."), text: $searchText)
                        .font(.system(size: PSLayout.scaledFont(16)))
                        .foregroundStyle(PSColors.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Task { @MainActor in await searchFeed() } }
                        .onChange(of: searchText) { _, newValue in
                            if newValue.isEmpty {
                                Task { @MainActor in await refreshFeed() }
                            }
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            Task { @MainActor in await refreshFeed() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: PSLayout.scaledFont(16)))
                                .foregroundStyle(PSColors.textTertiary)
                        }
                        .accessibilityLabel(String(localized: "Clear search"))
                    }
                }
                .padding(.horizontal, PSSpacing.lg)
                .frame(height: PSLayout.scaled(44))
                .background(PSColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                .adaptiveHPadding()
                .padding(.bottom, PSSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Tab row with smooth animation
            HStack(spacing: PSLayout.isCompact ? PSSpacing.lg : PSLayout.scaled(24)) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button {
                        if activeTab != index { PSHaptics.shared.selection() }
                        withAnimation(FLMotion.adaptive(PSMotion.springDefault, reduceMotion: reduceMotion)) {
                            activeTab = index
                        }
                    } label: {
                        VStack(spacing: 0) {
                            FLText(
                                tab,
                                .callout,
                                color: activeTab == index ? .green : .secondary
                            )
                            .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                            .padding(.horizontal, PSSpacing.sm)
                            .padding(.bottom, PSSpacing.lg)
                            .lineLimit(1)

                            if activeTab == index {
                                Capsule()
                                    .fill(PSColors.primaryGreen)
                                    .frame(height: 4)
                                    .matchedGeometryEffect(id: "community_tab_underline", in: tabNamespace)
                                    .transition(.scale)
                            } else {
                                Capsule()
                                    .fill(Color.clear)
                                    .frame(height: 4)
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(tab)
                    .accessibilityAddTraits(activeTab == index ? .isSelected : [])
                    .accessibilityHint(String(localized: "Double tap to switch to \(tab)"))
                }
                Spacer()
            }
            .adaptiveHPadding()
        }
        .background(PSColors.surfaceCard)
        .elevation(.z1)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            PSHaptics.shared.mediumTap()
            if networkMonitor.isConnected == false {
                PSHaptics.shared.warning()
                communityService.error = String(localized: "You must be online to create a listing")
            } else if authManager.authState == .authenticated {
                showCreateListing = true
            } else {
                PSHaptics.shared.warning()
                communityService.error = String(localized: "Sign in to create a listing")
            }
        } label: {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: PSLayout.scaledFont(20), weight: .semibold))
                FLText(localized: "New Post", .callout, color: .onDark)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, PSLayout.cardPadding)
            .padding(.vertical, PSSpacing.lg)
            .background(PSColors.primaryGreen)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
            .elevation(.z3)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(String(localized: "Create New Post"))
        .accessibilityHint(String(localized: "Double tap to create a new community listing"))
        .padding(.trailing, PSLayout.adaptiveHorizontalPadding)
        .padding(.bottom, PSLayout.scaled(100))
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        Group {
            if activeTab == 0 {
                localFeedTab
            } else {
                myListingsTab
            }
        }
    }

    // MARK: - Local Feed Tab

    private var localFeedTab: some View {
        Group {
            if communityService.isLoading == true && feedListings.isEmpty {
                // Loading state
                VStack(spacing: PSSpacing.lg) {
                    ProgressView()
                        .tint(PSColors.primaryGreen)
                    FLText(
                        localized: "Loading community feed...",
                        .callout,
                        color: .secondary
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = feedError ?? communityService.error, feedListings.isEmpty {
                // Error with no data — show retry
                VStack(spacing: PSSpacing.lg) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: PSLayout.scaledFont(40)))
                        .foregroundStyle(PSColors.textTertiary)
                    FLText(
                        localized: "Couldn't load the feed",
                        .bodyMedium
                    )
                    FLText(error, .caption, color: .secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        feedError = nil
                        communityService.error = nil
                        Task { @MainActor in await refreshFeed() }
                    } label: {
                        HStack(spacing: PSSpacing.xs) {
                            Image(systemName: "arrow.clockwise")
                            FLText(localized: "Try Again", .body, color: .onDark)
                                .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, PSSpacing.xxl)
                        .padding(.vertical, PSSpacing.md)
                        .background(PSColors.primaryGreen)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel(String(localized: "Try Again"))
                    .accessibilityHint(String(localized: "Double tap to retry loading the community feed"))
                }
                .padding(PSSpacing.screenHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if feedListings.isEmpty {
                PSEmptyState(
                    icon: "person.2",
                    title: String(localized: "No listings yet"),
                    message: String(localized: "Be the first to share food with your community! Tap 'New Post' to create a listing."),
                    actionTitle: String(localized: "Create Listing"),
                    action: { showCreateListing = true }
                )
                .padding(PSSpacing.screenHorizontal)
                .frame(maxHeight: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(localized: "No listings available"))
            } else {
                ScrollView {
                    // Error banner
                    if let error = communityService.error {
                        errorBanner(error)
                    }

                    LazyVStack(spacing: PSSpacing.xl) {
                        // Global impact milestone — pinned at top of feed
                        CommunityMilestoneCard()
                            .padding(.top, PSSpacing.xs)

                        ForEach(Array(feedListings.enumerated()), id: \.element.id) { index, listing in
                            listingCard(listing: listing)
                                .staggeredAppearance(index: index)
                                .onTapGesture { selectedListing = listing }
                        }
                    }
                    .adaptiveHPadding()
                    .padding(.top, PSSpacing.xl)
                    .listChangeAnimation(feedListings.map(\.id))
                }
                .contentMargins(.bottom, PSLayout.scaled(150), for: .scrollContent)
                .refreshable {
                    PSHaptics.shared.refreshSnap()
                    await refreshFeed()
                }
            }
        }
    }

    // MARK: - My Listings Tab

    private var myListingsTab: some View {
        Group {
            if authManager.authState != .authenticated {
                PSEmptyState(
                    icon: "person.crop.circle.badge.plus",
                    title: String(localized: "Sign in to see your listings"),
                    message: String(localized: "Create an account or sign in to manage your shared food listings and track their status.")
                )
                .padding(PSSpacing.screenHorizontal)
                .frame(maxHeight: .infinity)
            } else if !communityService.myListings.isEmpty {
                ScrollView {
                    LazyVStack(spacing: PSSpacing.lg) {
                        ForEach(Array(communityService.myListings.enumerated()), id: \.element.id) { index, listing in
                            myListingCard(listing: listing)
                                .staggeredAppearance(index: index)
                                .onTapGesture { selectedListing = listing }
                        }
                    }
                    .adaptiveHPadding()
                    .padding(.top, PSSpacing.xl)
                    .listChangeAnimation(communityService.myListings.map(\.id))
                }
                .contentMargins(.bottom, PSLayout.scaled(150), for: .scrollContent)
                .refreshable {
                    PSHaptics.shared.refreshSnap()
                    if let userId = authManager.currentUserId {
                        await communityService.fetchMyListings(userId: userId)
                    }
                }
            } else {
                PSEmptyState(
                    icon: "tray",
                    title: String(localized: "No listings yet"),
                    message: String(localized: "When you share or donate food, your listings will appear here so you can track their status."),
                    actionTitle: String(localized: "Create Listing"),
                    action: { showCreateListing = true }
                )
                .padding(PSSpacing.screenHorizontal)
                .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: - Listing Card (Feed)

    private func listingCard(listing: CommunityListingDTO) -> some View {
        let isMagicBag = listing.listingType == "magic_bag"
        return VStack(alignment: .leading, spacing: PSSpacing.lg) {
            // Magic Bag header banner
            if isMagicBag {
                HStack(spacing: PSSpacing.sm) {
                    Text("\u{1F381}")
                        .font(.system(size: PSLayout.scaledFont(14)))
                    FLText(
                        localized: "Magic Bag \u{2014} Pantry Clear-Out",
                        .caption,
                        color: .custom(Color(hex: 0x7C3AED))
                    )
                    .font(.system(size: PSLayout.scaledFont(12), weight: .black))
                    Spacer()
                    FLText(localized: "Peer to Peer", .sectionLabel, color: .onDark)
                        .padding(.horizontal, PSSpacing.sm)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x7C3AED), Color(hex: 0xDB2777)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .padding(.horizontal, PSSpacing.md)
                .padding(.vertical, PSSpacing.xs)
                .background(Color(hex: 0x7C3AED).opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
            }

            // User header
            HStack {
                // Real avatar — deterministically hashed to one of 5 photos
                Image(Self.avatarAsset(for: listing.displayName))
                    .resizable()
                    .scaledToFill()
                    .frame(width: PSLayout.communityAvatarSize, height: PSLayout.communityAvatarSize)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                            .strokeBorder(avatarColor(for: listing.displayName).opacity(0.3), lineWidth: 1.5)
                    )
                    .elevation(.z1)

                VStack(alignment: .leading, spacing: 2) {
                    FLText(listing.displayName, .callout)
                        .font(.system(size: PSLayout.scaledFont(16), weight: .bold))

                    HStack(spacing: 4) {
                        if let area = listing.areaName {
                            Image(systemName: "mappin")
                                .font(.system(size: 12))
                            Text(area)
                        }
                        if listing.areaName != nil && !listing.timeAgo.isEmpty {
                            Text("\u{2022}")
                        }
                        Text(listing.timeAgo)
                    }
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()

                PSBadge(
                    text: listing.isGiveaway
                        ? String(localized: "Giveaway")
                        : String(localized: "Donation"),
                    variant: listing.isGiveaway ? .shared : .donated
                )
            }

            // Item name + photo thumbnail
            HStack(spacing: PSSpacing.md) {
                Image(listing.categoryImageAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))

                FLText(listing.itemName, .headline)
                    .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                    .tracking(-0.2)

                if let qty = listing.quantity, qty > 0 {
                    FLText("\u{00D7}\(qty)", .callout, color: .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(PSColors.backgroundSecondary)
                        .clipShape(Capsule())
                }
            }

            // Description
            if let desc = listing.itemDescription, !desc.isEmpty {
                FLText(desc, .bodyMedium, color: .secondary)
                    .lineSpacing(4)
                    .lineLimit(3)
            }

            // Pickup info hint
            if listing.pickupAddress != nil {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                    FLText(
                        localized: "Pickup location available",
                        .subheadline,
                        color: .green
                    )
                }
                .foregroundStyle(PSColors.primaryGreen)
            }

            // Bottom action bar
            Divider()

            HStack {
                // Category tag
                HStack(spacing: 4) {
                    Text(listing.categoryEmoji)
                        .font(.system(size: 12))
                    FLText(
                        listing.foodCategory?.capitalized ?? String(localized: "Other"),
                        .caption,
                        color: .secondary
                    )
                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                }
                .foregroundStyle(PSColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(PSColors.backgroundSecondary)
                .clipShape(Capsule())

                Spacer()

                // Claim / view CTA
                if listing.status == "active" {
                    Button {
                        if networkMonitor.isConnected == false {
                            PSHaptics.shared.warning()
                            communityService.error = String(localized: "You must be online to claim an item")
                        } else {
                            selectedListing = listing
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 14))
                            FLText(localized: "Claim", .callout, color: .onDark)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(PSColors.primaryGreen)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .opacity(networkMonitor.isConnected == false ? 0.5 : 1)
                    .accessibilityLabel(String(localized: "Claim \(listing.itemName)"))
                    .accessibilityHint(String(localized: "Double tap to claim this listing"))
                } else {
                    PSBadge(
                        text: listing.status.capitalized,
                        variant: statusBadgeVariant(listing.status)
                    )
                }

                // Report button
                Menu {
                    Button(role: .destructive) {
                        reportTarget = listing
                        showReportSheet = true
                    } label: {
                        Label(String(localized: "Report"), systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(String(localized: "More options"))
                .accessibilityHint(String(localized: "Double tap to report this listing"))
            }
        }
        .padding(PSLayout.scaled(20))
        .background {
            if listing.listingType == "magic_bag" {
                LinearGradient(
                    colors: [Color(hex: 0x7C3AED).opacity(0.07), Color(hex: 0xDB2777).opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                PSColors.surfaceCard
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(
                    listing.listingType == "magic_bag"
                        ? Color(hex: 0x7C3AED).opacity(0.25)
                        : PSColors.borderLight,
                    lineWidth: listing.listingType == "magic_bag" ? 1.5 : 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(listing.itemName), \(listing.categoryEmoji)")
        .accessibilityValue("\(listing.displayName), \(listing.status.capitalized)")
        .accessibilityHint(String(localized: "Double tap to view details"))
    }

    // MARK: - My Listing Card

    private func myListingCard(listing: CommunityListingDTO) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack {
                Image(listing.categoryImageAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    FLText(listing.itemName, .headline)

                    FLText(listing.timeAgo, .subheadline, color: .secondary)
                }

                Spacer()

                PSBadge(
                    text: statusDisplayText(listing.status),
                    variant: statusBadgeVariant(listing.status)
                )
            }

            if let desc = listing.itemDescription, !desc.isEmpty {
                FLText(desc, .callout, color: .secondary)
                    .lineLimit(2)
            }

            // Action buttons for active listings
            if listing.status == "active" {
                HStack(spacing: 12) {
                    Button {
                        Task { @MainActor in
                            let success = await communityService.updateListingStatus(
                                listingId: listing.id, newStatus: "completed"
                            )
                            if success { await refreshFeed() }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            FLText(
                                localized: "Mark Complete",
                                .subheadline,
                                color: .green
                            )
                        }
                        .foregroundStyle(PSColors.primaryGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PSColors.primaryGreen.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel(String(localized: "Mark Complete"))
                    .accessibilityHint(String(localized: "Double tap to mark this listing as completed"))

                    Button {
                        Task { @MainActor in
                            let success = await communityService.deleteListing(listingId: listing.id)
                            if success { await refreshFeed() }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                            FLText(
                                localized: "Remove",
                                .subheadline,
                                color: .red
                            )
                        }
                        .foregroundStyle(PSColors.expiredRed)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PSColors.expiredRed.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel(String(localized: "Remove listing"))
                    .accessibilityHint(String(localized: "Double tap to delete this listing"))

                    Spacer()
                }
            } else if listing.status == "claimed" {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.checkmark")
                        .font(.system(size: 14))
                    FLText(
                        localized: "Someone claimed this item",
                        .subheadline,
                        color: .blue
                    )
                }
                .foregroundStyle(PSColors.infoBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PSColors.infoBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
            }
        }
        .padding(PSLayout.scaled(20))
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(listing.itemName), \(listing.categoryEmoji)")
        .accessibilityValue(statusDisplayText(listing.status))
    }

    // MARK: - Report Form

    private var reportForm: some View {
        VStack(spacing: PSSpacing.lg) {
            // Reason picker
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                FLText(localized: "Reason", .callout, color: .secondary)

                ForEach(reportReasons, id: \.self) { reason in
                    Button {
                        reportReason = reason
                    } label: {
                        HStack {
                            FLText(reason, .bodyMedium)
                            Spacer()
                            if reportReason == reason {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(PSColors.primaryGreen)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    .accessibilityLabel(reason)
                    .accessibilityAddTraits(reportReason == reason ? .isSelected : [])
                }
            }

            // Details
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                FLText(localized: "Details (Optional)", .callout, color: .secondary)

                TextField(String(localized: "Add more details..."), text: $reportDetails, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(3...5)
                    .padding(12)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            }

            // Submit
            PSButton(
                title: String(localized: "Submit Report"),
                icon: "flag.fill",
                style: .destructive
            ) {
                submitReport()
            }
            .disabled(reportReason.isEmpty)
            .opacity(reportReason.isEmpty ? 0.5 : 1)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
            FLText(message, .callout, color: .amber)
            Spacer()
            Button {
                communityService.error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
            }
            .accessibilityLabel(String(localized: "Dismiss error"))
        }
        .foregroundStyle(PSColors.warningAmber)
        .padding(12)
        .background(PSColors.warningAmber.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private var feedListings: [CommunityListingDTO] {
        communityService.listings
    }

    private func refreshFeed() async {
        PSHaptics.shared.refreshSnap()
        feedError = nil
        await communityService.fetchFeed(searchQuery: searchText.isEmpty ? nil : searchText)
        if let error = communityService.error {
            feedError = error
        }
        if let userId = authManager.currentUserId {
            await communityService.fetchMyListings(userId: userId)
        }
    }

    private func searchFeed() async {
        await communityService.fetchFeed(searchQuery: searchText.isEmpty ? nil : searchText)
    }

    private func submitReport() {
        guard let listing = reportTarget,
              let userId = authManager.currentUserId else { return }

        Task { @MainActor in
            _ = await communityService.reportListing(
                listingId: listing.id,
                reporterId: userId,
                reason: reportReason,
                details: reportDetails.isEmpty ? nil : reportDetails
            )
        }

        showReportSheet = false
        reportReason = ""
        reportDetails = ""
        reportTarget = nil
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [
            Color(hex: 0xFBBF24), Color(hex: 0x60A5FA), Color(hex: 0x4ADE80),
            Color(hex: 0xC084FC), Color(hex: 0xF87171), Color(hex: 0x2DD4BF)
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    /// Deterministically maps a display name to one of the 5 real avatar photos
    /// so the same person always gets the same portrait across sessions.
    fileprivate static func avatarAsset(for name: String) -> String {
        let assets = ["avatar_1", "avatar_2", "avatar_3", "avatar_4", "avatar_5"]
        let hash = abs(name.hashValue)
        return assets[hash % assets.count]
    }

    private func statusBadgeVariant(_ status: String) -> PSBadgeVariant {
        switch status {
        case "active": return .fresh
        case "claimed": return .claimed
        case "completed": return .shared
        case "expired": return .expired
        default: return .default
        }
    }

    private func statusDisplayText(_ status: String) -> String {
        switch status {
        case "active": return String(localized: "Active")
        case "claimed": return String(localized: "Claimed")
        case "completed": return String(localized: "Completed")
        case "expired": return String(localized: "Expired")
        default: return status.capitalized
        }
    }

    private let reportReasons = [
        String(localized: "Expired or unsafe food"),
        String(localized: "Inappropriate content"),
        String(localized: "Spam or scam"),
        String(localized: "Wrong location"),
        String(localized: "Other")
    ]
}

// MARK: - Preview

#Preview("FLCommunityPage - iPhone SE") {
    FLCommunityPage()
}

#Preview("FLCommunityPage - iPhone 16 Pro Max") {
    FLCommunityPage()
}

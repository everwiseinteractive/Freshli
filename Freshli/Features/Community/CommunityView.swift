import SwiftUI
import SwiftData

// Figma: Community.tsx — bg-neutral-50, sticky white header
// Title row: text-3xl font-bold text-neutral-900 tracking-tight + search button (p-2 bg-neutral-100 rounded-full)
// Tabs: "Local Feed", "My Listings" — layoutId="communityTab", h-1 bg-green-500 rounded-t-full
// Feed cards: bg-white rounded-3xl p-5 shadow-sm border border-neutral-100
// Avatar: w-12 h-12 rounded-[1rem] with initials
// Engagement bar: category emoji + claim CTA
// FAB: bg-neutral-900 text-white px-6 py-4 rounded-[1.25rem] + Edit3 + "New Post"
// BottomSheet: full CreateListingView form
// SuccessCelebration: "Posted!" with Share2 icon

struct CommunityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?
    @Environment(AuthManager.self) private var authManager: AuthManager?
    @Environment(SyncService.self) private var syncService: SyncService?
    @Environment(CommunityService.self) private var communityService: CommunityService?
    @Environment(NetworkMonitor.self) private var networkMonitor: NetworkMonitor?

    @State private var activeTab = 0
    @State private var showCreateListing = false
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

    private let tabs = [
        String(localized: "Local Feed"),
        String(localized: "My Listings")
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Offline banner
                if networkMonitor?.isConnected == false {
                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 14))
                        Text(String(localized: "You're offline. Showing cached listings."))
                            .font(PSTypography.caption1)
                    }
                    .foregroundStyle(PSColors.textSecondary)
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.vertical, PSSpacing.xs)
                    .frame(maxWidth: .infinity)
                    .background(PSColors.warningAmber.opacity(0.1))
                }

                stickyHeader
                feedContent
            }
            .background(PSColors.backgroundSecondary)

            // Figma: FAB — bg-neutral-900 text-white px-6 py-4 rounded-[1.25rem]
            fabButton
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCreateListing) {
            NavigationStack {
                CommunityCreateListingView { success in
                    if success {
                        showCreateListing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showPostSuccess = true
                        }
                        // Refresh feed
                        Task { await refreshFeed() }
                    }
                }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedListing) { listing in
            NavigationStack {
                ListingDetailView(listing: listing) {
                    Task { await refreshFeed() }
                }
            }
            .presentationDragIndicator(.visible)
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
            await refreshFeed()
        }
    }

    // MARK: - Sticky Header
    // Figma: bg-white px-6 pt-12 pb-2 sticky top-0 z-30 border-b border-neutral-100 shadow-sm

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            // Title row - adaptive layout for SE
            HStack {
                Text(String(localized: "Community"))
                    .font(.system(size: PSLayout.scaledFont(30), weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .psAccessibleHeader(String(localized: "Community"))

                Spacer(minLength: PSSpacing.md)

                HStack(spacing: PSSpacing.sm) {
                    NavigationLink(destination: CirclesView()) {
                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: PSLayout.scaledFont(18), weight: .medium))
                            .foregroundStyle(PSColors.primaryGreen)
                            .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                            .background(PSColors.primaryGreen.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(String(localized: "View Circles"))

                    NavigationLink(destination: ShoppingListView()) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: PSLayout.scaledFont(18), weight: .medium))
                            .foregroundStyle(PSColors.accentTeal)
                            .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                            .background(PSColors.accentTeal.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(String(localized: "View Shopping List"))

                    Button {
                        withAnimation(PSMotion.springQuick) { showSearch.toggle() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: PSLayout.scaledFont(18), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                            .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                            .background(PSColors.backgroundSecondary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel(String(localized: "Search listings"))
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
                        .onSubmit { Task { await searchFeed() } }
                        .onChange(of: searchText) { _, newValue in
                            if newValue.isEmpty {
                                Task { await refreshFeed() }
                            }
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            Task { await refreshFeed() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: PSLayout.scaledFont(16)))
                                .foregroundStyle(PSColors.textTertiary)
                        }
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
                        withAnimation(PSMotion.springDefault) {
                            activeTab = index
                        }
                    } label: {
                        VStack(spacing: 0) {
                            Text(tab)
                                .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                                .tracking(-0.2)
                                .foregroundStyle(activeTab == index ? PSColors.primaryGreen : PSColors.textSecondary)
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
                }
                Spacer()
            }
            .adaptiveHPadding()
        }
        .background(PSColors.surfaceCard)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            PSHaptics.shared.mediumTap()
            if networkMonitor?.isConnected == false {
                PSHaptics.shared.warning()
                communityService?.error = String(localized: "You must be online to create a listing")
            } else if authManager?.authState == .authenticated {
                showCreateListing = true
            } else {
                PSHaptics.shared.warning()
                communityService?.error = String(localized: "Sign in to create a listing")
            }
        } label: {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: PSLayout.scaledFont(20), weight: .semibold))
                Text(String(localized: "New Post"))
                    .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                    .tracking(-0.2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, PSLayout.cardPadding)
            .padding(.vertical, PSSpacing.lg)
            .background(PSColors.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
            .shadow(color: Color(hex: 0x171717).opacity(0.2), radius: 16, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(String(localized: "Create New Post"))
        .accessibilityHint(String(localized: "Double tap to create a new community listing"))
        .padding(.trailing, PSLayout.adaptiveHorizontalPadding)
        .padding(.bottom, PSLayout.adaptiveHorizontalPadding)
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
            if communityService?.isLoading == true && feedListings.isEmpty {
                // Loading state
                VStack(spacing: PSSpacing.lg) {
                    ProgressView()
                        .tint(PSColors.primaryGreen)
                    Text(String(localized: "Loading community feed..."))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = feedError ?? communityService?.error, feedListings.isEmpty {
                // Error with no data — show retry
                VStack(spacing: PSSpacing.lg) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: PSLayout.scaledFont(40)))
                        .foregroundStyle(PSColors.textTertiary)
                    Text(String(localized: "Couldn't load the feed"))
                        .font(PSTypography.bodyMedium)
                        .foregroundStyle(PSColors.textPrimary)
                    Text(error)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button {
                        feedError = nil
                        communityService?.error = nil
                        Task { await refreshFeed() }
                    } label: {
                        HStack(spacing: PSSpacing.xs) {
                            Image(systemName: "arrow.clockwise")
                            Text(String(localized: "Try Again"))
                        }
                        .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, PSSpacing.xxl)
                        .padding(.vertical, PSSpacing.md)
                        .background(PSColors.primaryGreen)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
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
                    if let error = communityService?.error {
                        errorBanner(error)
                    }

                    LazyVStack(spacing: PSSpacing.xl) {
                        ForEach(Array(feedListings.enumerated()), id: \.element.id) { index, listing in
                            listingCard(listing: listing)
                                .staggeredAppearance(index: index)
                                .onTapGesture { selectedListing = listing }
                        }
                    }
                    .adaptiveHPadding()
                    .padding(.top, PSSpacing.xl)
                    .padding(.bottom, PSLayout.tabBarContentPadding + PSSpacing.xl)
                }
                .refreshable { await refreshFeed() }
            }
        }
    }

    // MARK: - My Listings Tab

    private var myListingsTab: some View {
        Group {
            if authManager?.authState != .authenticated {
                PSEmptyState(
                    icon: "person.crop.circle.badge.plus",
                    title: String(localized: "Sign in to see your listings"),
                    message: String(localized: "Create an account or sign in to manage your shared food listings and track their status.")
                )
                .padding(PSSpacing.screenHorizontal)
                .frame(maxHeight: .infinity)
            } else if let myListings = communityService?.myListings, !myListings.isEmpty {
                ScrollView {
                    LazyVStack(spacing: PSSpacing.lg) {
                        ForEach(Array(myListings.enumerated()), id: \.element.id) { index, listing in
                            myListingCard(listing: listing)
                                .staggeredAppearance(index: index)
                                .onTapGesture { selectedListing = listing }
                        }
                    }
                    .adaptiveHPadding()
                    .padding(.top, PSSpacing.xl)
                    .padding(.bottom, PSLayout.tabBarContentPadding + PSSpacing.xl)
                }
                .refreshable {
                    if let userId = authManager?.currentUserId {
                        await communityService?.fetchMyListings(userId: userId)
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
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            // User header
            HStack {
                // Avatar
                Text(listing.initials)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: PSLayout.communityAvatarSize, height: PSLayout.communityAvatarSize)
                    .background(avatarColor(for: listing.displayName))
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.displayName)
                        .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)

                    HStack(spacing: 4) {
                        if let area = listing.areaName {
                            Image(systemName: "mappin")
                                .font(.system(size: 12))
                            Text(area)
                        }
                        if listing.areaName != nil && !listing.timeAgo.isEmpty {
                            Text("•")
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

            // Item name + category
            HStack(spacing: 8) {
                Text(listing.categoryEmoji)
                    .font(.system(size: PSLayout.scaledFont(20)))

                Text(listing.itemName)
                    .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(PSColors.textPrimary)

                if let qty = listing.quantity, qty > 0 {
                    Text("×\(qty)")
                        .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(PSColors.backgroundSecondary)
                        .clipShape(Capsule())
                }
            }

            // Description
            if let desc = listing.itemDescription, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineSpacing(4)
                    .lineLimit(3)
            }

            // Pickup info hint
            if listing.pickupAddress != nil {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                    Text(String(localized: "Pickup location available"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
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
                    Text(listing.foodCategory?.capitalized ?? String(localized: "Other"))
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
                        if networkMonitor?.isConnected == false {
                            PSHaptics.shared.warning()
                            communityService?.error = String(localized: "You must be online to claim an item")
                        } else {
                            selectedListing = listing
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 14))
                            Text(String(localized: "Claim"))
                                .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(PSColors.primaryGreen)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .opacity(networkMonitor?.isConnected == false ? 0.5 : 1)
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
        .accessibilityValue("\(listing.displayName), \(listing.status.capitalized)")
        .accessibilityHint(String(localized: "Double tap to view details"))
    }

    // MARK: - My Listing Card

    private func myListingCard(listing: CommunityListingDTO) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack {
                Text(listing.categoryEmoji)
                    .font(.system(size: PSLayout.scaledFont(24)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.itemName)
                        .font(.system(size: PSLayout.scaledFont(17), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)

                    Text(listing.timeAgo)
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()

                PSBadge(
                    text: statusDisplayText(listing.status),
                    variant: statusBadgeVariant(listing.status)
                )
            }

            if let desc = listing.itemDescription, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(2)
            }

            // Action buttons for active listings
            if listing.status == "active" {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            let success = await communityService?.updateListingStatus(
                                listingId: listing.id, newStatus: "completed"
                            ) ?? false
                            if success { await refreshFeed() }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text(String(localized: "Mark Complete"))
                                .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        }
                        .foregroundStyle(PSColors.primaryGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PSColors.primaryGreen.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button {
                        Task {
                            let success = await communityService?.deleteListing(listingId: listing.id) ?? false
                            if success { await refreshFeed() }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                            Text(String(localized: "Remove"))
                                .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        }
                        .foregroundStyle(PSColors.expiredRed)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PSColors.expiredRed.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())

                    Spacer()
                }
            } else if listing.status == "claimed" {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.checkmark")
                        .font(.system(size: 14))
                    Text(String(localized: "Someone claimed this item"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
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
                Text(String(localized: "Reason"))
                    .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)

                ForEach(reportReasons, id: \.self) { reason in
                    Button {
                        reportReason = reason
                    } label: {
                        HStack {
                            Text(reason)
                                .font(.system(size: PSLayout.scaledFont(15), weight: .medium))
                                .foregroundStyle(PSColors.textPrimary)
                            Spacer()
                            if reportReason == reason {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(PSColors.primaryGreen)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }

            // Details
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                Text(String(localized: "Details (Optional)"))
                    .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)

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
            Text(message)
                .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
            Spacer()
            Button {
                communityService?.error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
            }
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
        if let listings = communityService?.listings, !listings.isEmpty {
            return listings
        }
        // Fallback: show seed data when unauthenticated or no results
        return CommunityFeedData.cachedSeedListings
    }

    private func refreshFeed() async {
        PSHaptics.shared.refreshSnap()
        feedError = nil
        await communityService?.fetchFeed(searchQuery: searchText.isEmpty ? nil : searchText)
        if let error = communityService?.error {
            feedError = error
        }
        if let userId = authManager?.currentUserId {
            await communityService?.fetchMyListings(userId: userId)
        }
    }

    private func searchFeed() async {
        await communityService?.fetchFeed(searchQuery: searchText.isEmpty ? nil : searchText)
    }

    private func submitReport() {
        guard let listing = reportTarget,
              let userId = authManager?.currentUserId else { return }

        Task {
            _ = await communityService?.reportListing(
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

// MARK: - Seed Data (offline/unauthenticated fallback)

enum CommunityFeedData {
    static let cachedSeedListings: [CommunityListingDTO] = [
        CommunityListingDTO(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            userId: UUID(),
            itemName: "Fresh Lemons",
            itemDescription: "I bought too many lemons! Giving away a bag of 6 fresh organic lemons. Anyone interested?",
            quantity: 6,
            listingType: "share",
            status: "active",
            pickupAddress: nil,
            pickupNotes: nil,
            claimedBy: nil,
            datePosted: Date().addingTimeInterval(-7200),
            expiryDate: Date.daysFromNow(5),
            completedAt: nil,
            foodCategory: "fruits",
            areaName: "Downtown",
            imageUrls: nil,
            reportCount: nil,
            isFlagged: nil,
            profiles: ListingProfileDTO(displayName: "Sarah Jenkins", avatarUrl: nil)
        ),
        CommunityListingDTO(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            userId: UUID(),
            itemName: "Homemade Marinara",
            itemDescription: "Made too much pasta sauce — have 2 large jars of homemade marinara. Fresh basil and tomatoes from my garden!",
            quantity: 2,
            listingType: "share",
            status: "active",
            pickupAddress: "123 Garden St",
            pickupNotes: nil,
            claimedBy: nil,
            datePosted: Date().addingTimeInterval(-28800),
            expiryDate: Date.daysFromNow(3),
            completedAt: nil,
            foodCategory: "canned",
            areaName: "Westside",
            imageUrls: nil,
            reportCount: nil,
            isFlagged: nil,
            profiles: ListingProfileDTO(displayName: "Priya Sharma", avatarUrl: nil)
        ),
        CommunityListingDTO(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            userId: UUID(),
            itemName: "Organic Chickpeas & Rice",
            itemDescription: "Clearing out the pantry — have 4 cans of organic chickpeas and 2 bags of brown rice. All unopened.",
            quantity: 6,
            listingType: "donate",
            status: "active",
            pickupAddress: nil,
            pickupNotes: nil,
            claimedBy: nil,
            datePosted: Date().addingTimeInterval(-86400),
            expiryDate: Date.daysFromNow(30),
            completedAt: nil,
            foodCategory: "grains",
            areaName: "Northside",
            imageUrls: nil,
            reportCount: nil,
            isFlagged: nil,
            profiles: ListingProfileDTO(displayName: "David Kim", avatarUrl: nil)
        ),
        CommunityListingDTO(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            userId: UUID(),
            itemName: "Sourdough Bread",
            itemDescription: "Baked too many loaves this weekend! Two fresh sourdough loaves available. Baked yesterday.",
            quantity: 2,
            listingType: "share",
            status: "active",
            pickupAddress: nil,
            pickupNotes: "Ring the doorbell",
            claimedBy: nil,
            datePosted: Date().addingTimeInterval(-14400),
            expiryDate: Date.daysFromNow(2),
            completedAt: nil,
            foodCategory: "bakery",
            areaName: "Eastside",
            imageUrls: nil,
            reportCount: nil,
            isFlagged: nil,
            profiles: ListingProfileDTO(displayName: "Michael Chen", avatarUrl: nil)
        ),
    ]
}

#Preview("CommunityView - iPhone SE") {
    CommunityView()
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("CommunityView - iPhone 16 Pro Max") {
    CommunityView()
        .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro Max"))
}

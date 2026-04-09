import SwiftUI
import GroupActivities

// MARK: - Circle Detail View
// Shows circle members (face pile), listings, and actions.
// Privacy-first: listings private by default, explicit "Global Share" toggle.

struct CircleDetailView: View {
    let circle: SupabaseCircle
    @Bindable var viewModel: CirclesViewModel
    @Environment(AuthManager.self) private var authManager: AuthManager?
    @State private var showAddListing = false
    @State private var showInviteCode = false
    @State private var claimTrigger = false

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.lg) {
                circleHeader
                membersSection
                sharePlaySection
                listingsSection
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.screenVertical)
        }
        .claimFeedback(trigger: claimTrigger)
        .background(PSColors.backgroundPrimary)
        .navigationTitle(circle.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showInviteCode = true
                    } label: {
                        Label("Invite Code", systemImage: "ticket")
                    }

                    Button(role: .destructive) {
                        guard let userId = authManager?.currentUserId else { return }
                        Task { await viewModel.leaveCircle(userId: userId, circleId: circle.id) }
                    } label: {
                        Label("Leave Circle", systemImage: "arrow.left.circle")
                    }
                } label: {
                    PSIconButton(icon: "ellipsis") {}
                }
            }
        }
        .task {
            await viewModel.selectCircle(circle)
        }
        .sheet(isPresented: $showAddListing) {
            AddCircleListingView(circle: circle, viewModel: viewModel)
        }
        .alert("Invite Code", isPresented: $showInviteCode) {
            Button("Copy") {
                if let code = circle.inviteCode {
                    UIPasteboard.general.string = code
                    CircleHaptics.inviteCodeCopied()
                }
            }
            Button("Done", role: .cancel) {}
        } message: {
            Text("Share this code with people you trust:\n\n\(circle.inviteCode ?? "—")")
        }
    }

    // MARK: - Circle Header

    private var circleHeader: some View {
        PSGlassCard {
            VStack(spacing: PSSpacing.md) {
                Text(circle.emoji ?? "🏠")
                    .font(.system(size: 52))

                if let description = circle.description {
                    Text(description)
                        .font(PSTypography.body)
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: PSSpacing.md) {
                    PSBadge(text: "\(viewModel.members.count) members", variant: .default)
                    PSBadge(text: circle.isPrivate ? "Private" : "Open", variant: .fresh)
                }
            }
        }
    }

    // MARK: - Members Section (Face Pile)

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack {
                Text("Members")
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)

                Spacer()

                Button {
                    showInviteCode = true
                    PSHaptics.shared.lightTap()
                } label: {
                    Label("Invite", systemImage: "plus")
                        .font(PSTypography.subheadlineMedium)
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }

            PSCard {
                HStack {
                    FacePileView(members: viewModel.members, maxVisible: 5, avatarSize: 40)

                    Spacer()

                    Text("\(viewModel.members.count)")
                        .font(PSTypography.statSmall)
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }
        }
    }

    // MARK: - SharePlay Section

    private var sharePlaySection: some View {
        PSActionCard(
            icon: "shareplay",
            title: "Live Grocery Sync",
            subtitle: "Start a SharePlay session to build a grocery list together in real-time",
            iconColor: PSColors.accentTeal
        ) {
            Task {
                await viewModel.startSharePlay()
            }
        }
    }

    // MARK: - Listings Section

    private var listingsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack {
                Text("Shared Items")
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)

                Spacer()

                PSIconButton(icon: "plus", tint: PSColors.primaryGreen, background: PSColors.emeraldLight) {
                    PSHaptics.shared.lightTap()
                    showAddListing = true
                }
            }

            if viewModel.listings.isEmpty {
                PSCard {
                    VStack(spacing: PSSpacing.sm) {
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundStyle(PSColors.textTertiary)
                        Text("No items shared yet")
                            .font(PSTypography.subheadline)
                            .foregroundStyle(PSColors.textSecondary)
                        Text("Tap + to share food with your circle")
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PSSpacing.lg)
                }
            } else {
                LazyVStack(spacing: PSSpacing.sm) {
                    ForEach(viewModel.listings) { listing in
                        CircleListingRow(
                            listing: listing,
                            currentUserId: authManager?.currentUserId,
                            onClaim: {
                                guard let userId = authManager?.currentUserId else { return }
                                Task {
                                    await viewModel.claimItem(listingId: listing.id, userId: userId)
                                    claimTrigger.toggle()
                                }
                            },
                            onGlobalShare: {
                                Task {
                                    await viewModel.toggleGlobalShare(listingId: listing.id)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Circle Listing Row

private struct CircleListingRow: View {
    let listing: SupabaseCircleListing
    let currentUserId: UUID?
    let onClaim: () -> Void
    let onGlobalShare: () -> Void

    private var isClaimed: Bool {
        listing.status == CircleListingStatus.claimed.rawValue
    }

    private var isOwnListing: Bool {
        listing.userId == currentUserId
    }

    var body: some View {
        PSCard {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                        Text(listing.itemName)
                            .font(PSTypography.bodyMedium)
                            .foregroundStyle(PSColors.textPrimary)

                        if let desc = listing.itemDescription {
                            Text(desc)
                                .font(PSTypography.caption1)
                                .foregroundStyle(PSColors.textSecondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    if let qty = listing.quantity {
                        PSBadge(text: qty, variant: .default)
                    }
                }

                HStack(spacing: PSSpacing.sm) {
                    // Status badge
                    PSBadge(
                        text: isClaimed ? "Claimed" : "Available",
                        variant: isClaimed ? .claimed : .fresh
                    )

                    // Privacy indicator
                    if listing.isGloballyShared {
                        PSBadge(text: "Global", variant: .shared)
                    } else {
                        PSBadge(text: "Circle Only", variant: .default, style: .subtle)
                    }

                    if let expiryDate = listing.expiryDate {
                        let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
                        if daysLeft <= 2 {
                            PSBadge(text: "Expires soon", variant: .expiringSoon)
                        }
                    }

                    Spacer()

                    // Actions
                    if !isClaimed && !isOwnListing {
                        Button {
                            onClaim()
                        } label: {
                            Text("Claim")
                                .font(PSTypography.subheadlineMedium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, PSSpacing.md)
                                .padding(.vertical, PSSpacing.xs)
                                .background(PSColors.primaryGreen)
                                .clipShape(Capsule())
                        }
                    }

                    if isOwnListing {
                        Button {
                            onGlobalShare()
                        } label: {
                            Image(systemName: listing.isGloballyShared ? "globe" : "globe.badge.chevron.backward")
                                .font(PSTypography.subheadline)
                                .foregroundStyle(listing.isGloballyShared ? PSColors.primaryGreen : PSColors.textTertiary)
                        }
                        .accessibilityLabel(listing.isGloballyShared ? "Remove from global sharing" : "Share globally")
                    }
                }
            }
        }
    }
}

// MARK: - Add Circle Listing Sheet

private struct AddCircleListingView: View {
    let circle: SupabaseCircle
    @Bindable var viewModel: CirclesViewModel
    @Environment(AuthManager.self) private var authManager: AuthManager?
    @Environment(\.dismiss) private var dismiss

    @State private var itemName = ""
    @State private var itemDescription = ""
    @State private var quantity = ""
    @State private var expiryDate = Date().addingTimeInterval(86400 * 3)
    @State private var hasExpiry = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xxl) {
                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text("Item Name")
                            .font(PSTypography.subheadlineMedium)
                            .foregroundStyle(PSColors.textSecondary)
                        TextField("e.g. Homemade soup, Extra bananas", text: $itemName)
                            .font(PSTypography.body)
                            .padding(PSSpacing.md)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                    }

                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text("Description (optional)")
                            .font(PSTypography.subheadlineMedium)
                            .foregroundStyle(PSColors.textSecondary)
                        TextField("Any details for circle members", text: $itemDescription, axis: .vertical)
                            .font(PSTypography.body)
                            .lineLimit(2...4)
                            .padding(PSSpacing.md)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                    }

                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text("Quantity (optional)")
                            .font(PSTypography.subheadlineMedium)
                            .foregroundStyle(PSColors.textSecondary)
                        TextField("e.g. 2 jars, 1 bag", text: $quantity)
                            .font(PSTypography.body)
                            .padding(PSSpacing.md)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                    }

                    Toggle(isOn: $hasExpiry) {
                        Text("Expires")
                            .font(PSTypography.bodyMedium)
                            .foregroundStyle(PSColors.textPrimary)
                    }
                    .tint(PSColors.primaryGreen)

                    if hasExpiry {
                        DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                            .font(PSTypography.body)
                            .tint(PSColors.primaryGreen)
                    }

                    // Privacy notice
                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: "eye.slash.fill")
                            .foregroundStyle(PSColors.primaryGreen)
                        Text("This item will only be visible to \(circle.name) members.")
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                    }
                    .padding(PSSpacing.md)
                    .background(PSColors.emeraldLight.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))

                    PSButton(title: "Share with Circle", icon: "arrow.up.circle.fill", isLoading: viewModel.isLoading) {
                        guard let userId = authManager?.currentUserId else { return }
                        Task {
                            let success = await viewModel.createListing(
                                circleId: circle.id,
                                userId: userId,
                                itemName: itemName,
                                description: itemDescription.isEmpty ? nil : itemDescription,
                                quantity: quantity.isEmpty ? nil : quantity,
                                expiryDate: hasExpiry ? expiryDate : nil
                            )
                            if success { dismiss() }
                        }
                    }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.screenVertical)
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle("Share Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
    }
}

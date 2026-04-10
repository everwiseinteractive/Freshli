import SwiftUI
import SwiftData

struct CreateListingView: View {
    let listingType: ListingType
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?
    @Environment(AuthManager.self) private var authManager: AuthManager?
    @Environment(CommunityService.self) private var communityService: CommunityService?
    @Environment(SyncService.self) private var syncService: SyncService?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var itemName = ""
    @State private var description = ""
    @State private var quantity = ""
    @State private var pickupAddress = ""
    @State private var pickupNotes = ""
    @State private var expiryDate = Date.daysFromNow(3)
    @State private var showSuccess = false

    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var freshliItems: [FreshliItem]

    @State private var selectedFreshliItem: FreshliItem?

    private var isFormValid: Bool {
        !itemName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !quantity.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Int(quantity) ?? 0) > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                typeHeader
                freshliItemPicker
                formFields
                safetyNote
                submitButton
            }
            .padding(.vertical, PSSpacing.lg)
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(listingType == .share ? String(localized: "Share Food") : String(localized: "Donate Food"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Cancel")) { dismiss() }
            }
        }
        .overlay {
            if showSuccess { successOverlay }
        }
    }

    private var typeHeader: some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: listingType == .share ? "hand.raised.fill" : "heart.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(listingType == .share ? PSColors.infoBlue : PSColors.accentTeal)
                .frame(width: 52, height: 52)
                .background((listingType == .share ? PSColors.infoBlue : PSColors.accentTeal).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

            VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                Text(listingType == .share
                     ? String(localized: "Share with Neighbors")
                     : String(localized: "Donate to Food Bank"))
                    .font(PSTypography.bodyMedium)
                    .foregroundStyle(PSColors.textPrimary)
                Text(listingType == .share
                     ? String(localized: "Your surplus helps your community")
                     : String(localized: "Help those who need it most"))
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var freshliItemPicker: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text(String(localized: "Pick from Pantry (Optional)"))
                .font(PSTypography.caption1Medium)
                .foregroundStyle(PSColors.textSecondary)

            if freshliItems.isEmpty {
                Text(String(localized: "No pantry items available"))
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textTertiary)
                    .padding(PSSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PSSpacing.sm) {
                        ForEach(freshliItems) { item in
                            Button {
                                PSHaptics.shared.selection()
                                selectedFreshliItem = item
                                itemName = item.name
                                quantity = item.quantityDisplay
                            } label: {
                                HStack(spacing: PSSpacing.xs) {
                                    Image(systemName: item.category.icon)
                                        .font(.system(size: 12))
                                    Text(item.name)
                                        .font(PSTypography.caption1Medium)
                                }
                                .padding(.horizontal, PSSpacing.md)
                                .padding(.vertical, PSSpacing.sm)
                                .foregroundStyle(selectedFreshliItem?.id == item.id ? PSColors.textOnPrimary : PSColors.textSecondary)
                                .background(selectedFreshliItem?.id == item.id ? PSColors.primaryGreen : PSColors.backgroundSecondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private var formFields: some View {
        VStack(spacing: PSSpacing.lg) {
            FormField(label: String(localized: "Item Name")) {
                TextField(String(localized: "What are you sharing?"), text: $itemName)
                    .font(PSTypography.body)
                    .padding(PSSpacing.md)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
            }

            FormField(label: String(localized: "Description")) {
                TextField(String(localized: "Brief description..."), text: $description, axis: .vertical)
                    .font(PSTypography.body)
                    .lineLimit(2...4)
                    .padding(PSSpacing.md)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
            }

            FormField(label: String(localized: "Quantity")) {
                TextField(String(localized: "e.g. 3 cans, 1 bag"), text: $quantity)
                    .font(PSTypography.body)
                    .padding(PSSpacing.md)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
            }

            FormField(label: String(localized: "Best Before")) {
                DatePicker("", selection: $expiryDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(PSColors.primaryGreen)
            }

            if listingType == .share {
                FormField(label: String(localized: "Pickup Location")) {
                    TextField(String(localized: "Address or meeting point"), text: $pickupAddress)
                        .font(PSTypography.body)
                        .padding(PSSpacing.md)
                        .background(PSColors.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
                }

                FormField(label: String(localized: "Pickup Notes (Optional)")) {
                    TextField(String(localized: "e.g. Ring doorbell, leave at porch"), text: $pickupNotes)
                        .font(PSTypography.body)
                        .padding(PSSpacing.md)
                        .background(PSColors.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
                }
            }
        }
    }

    private var safetyNote: some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: "shield.checkered")
                .foregroundStyle(PSColors.primaryGreen)
            Text(String(localized: "Please ensure all shared food is safe, properly stored, and within its use-by date."))
                .font(PSTypography.caption1)
                .foregroundStyle(PSColors.textSecondary)
        }
        .padding(PSSpacing.md)
        .background(PSColors.primaryGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
    }

    private var submitButton: some View {
        PSButton(
            title: listingType == .share ? String(localized: "Share This Item") : String(localized: "List for Donation"),
            icon: listingType == .share ? "hand.raised.fill" : "heart.fill"
        ) {
            createListing()
        }
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1 : 0.5)
    }

    private func createListing() {
        // Validate quantity is positive integer
        guard let qty = Int(quantity), qty > 0 else {
            PSHaptics.shared.error()
            return
        }

        PSHaptics.shared.success()
        let listing = SharedListing(
            itemName: itemName.trimmingCharacters(in: .whitespaces),
            itemDescription: description,
            quantity: quantity,
            listingType: listingType,
            pickupAddress: pickupAddress,
            pickupNotes: pickupNotes.isEmpty ? nil : pickupNotes,
            expiryDate: expiryDate
        )
        modelContext.insert(listing)

        if let freshliItem = selectedFreshliItem {
            if listingType == .share {
                freshliItem.isShared = true
            } else {
                freshliItem.isDonated = true
            }
        }

        do {
            try modelContext.save()
            PSLogger.general.info("Listing created and saved locally")
        } catch {
            PSLogger.general.error("Failed to save listing: \(error.localizedDescription)")
            return
        }

        // Sync to Supabase if authenticated
        if let userId = authManager?.currentUserId {
            let input = CreateListingInput(
                itemName: listing.itemName,
                description: listing.itemDescription.isEmpty ? nil : listing.itemDescription,
                quantity: qty,
                listingType: listingType == .share ? "share" : "donate",
                pickupAddress: listing.pickupAddress.isEmpty ? nil : listing.pickupAddress,
                pickupNotes: listing.pickupNotes
            )
            Task {
                _ = await communityService?.createListing(input, userId: userId)
                await syncService?.recordImpactEvent(
                    userId: userId,
                    eventType: listingType == .share ? "shared" : "donated"
                )
            }
        }

        // Trigger celebration based on listing type
        if listingType == .share {
            celebrationManager?.fireShareCompleted(itemName: itemName, modelContext: modelContext)
        } else {
            celebrationManager?.fireDonationCompleted(itemName: itemName, modelContext: modelContext)
        }

        withAnimation(FLMotion.adaptive(PSMotion.springBouncy, reduceMotion: reduceMotion)) { showSuccess = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            dismiss()
        }
    }

    private var successOverlay: some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: listingType == .share ? "hand.thumbsup.fill" : "heart.fill")
                .font(.system(size: 64))
                .foregroundStyle(listingType == .share ? PSColors.infoBlue : PSColors.accentTeal)
                .symbolEffect(.bounce)
            Text(listingType == .share
                 ? String(localized: "Shared Successfully!")
                 : String(localized: "Listed for Donation!"))
                .font(PSTypography.title3)
                .foregroundStyle(PSColors.textPrimary)
            Text(String(localized: "Thank you for making a difference"))
                .font(PSTypography.callout)
                .foregroundStyle(PSColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .transition(.opacity)
    }
}

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

    @State private var itemName = ""
    @State private var description = ""
    @State private var quantity = ""
    @State private var pickupAddress = ""
    @State private var pickupNotes = ""
    @State private var expiryDate = Date.daysFromNow(3)
    @State private var showSuccess = false

    @Query(filter: #Predicate<PantryItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\PantryItem.expiryDate)])
    private var pantryItems: [PantryItem]

    @State private var selectedPantryItem: PantryItem?

    private var isFormValid: Bool {
        !itemName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !quantity.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                typeHeader
                pantryItemPicker
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

    private var pantryItemPicker: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text(String(localized: "Pick from Pantry (Optional)"))
                .font(PSTypography.caption1Medium)
                .foregroundStyle(PSColors.textSecondary)

            if pantryItems.isEmpty {
                Text(String(localized: "No pantry items available"))
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textTertiary)
                    .padding(PSSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PSSpacing.sm) {
                        ForEach(pantryItems) { item in
                            Button {
                                PSHaptics.shared.selection()
                                selectedPantryItem = item
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
                                .foregroundStyle(selectedPantryItem?.id == item.id ? PSColors.textOnPrimary : PSColors.textSecondary)
                                .background(selectedPantryItem?.id == item.id ? PSColors.primaryGreen : PSColors.backgroundSecondary)
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

        if let pantryItem = selectedPantryItem {
            if listingType == .share {
                pantryItem.isShared = true
            } else {
                pantryItem.isDonated = true
            }
        }

        try? modelContext.save()

        // Sync to Supabase if authenticated
        if let userId = authManager?.currentUserId {
            let input = CreateListingInput(
                itemName: listing.itemName,
                description: listing.itemDescription.isEmpty ? nil : listing.itemDescription,
                quantity: Int(listing.quantity) ?? 1,
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
            celebrationManager?.onShareCompleted(itemName: itemName, modelContext: modelContext)
        } else {
            celebrationManager?.onDonationCompleted(itemName: itemName, modelContext: modelContext)
        }

        withAnimation(PSMotion.springBouncy) { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
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

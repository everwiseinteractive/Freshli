import SwiftUI
import SwiftData

// MARK: - Community Create Listing View
// Full-featured form for creating Supabase-backed community listings.
// Supports item name, description, quantity, food category, listing type, pickup info.

struct CommunityCreateListingView: View {
    var onComplete: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager: AuthManager?
    @Environment(CommunityService.self) private var communityService: CommunityService?
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?
    @Environment(SyncService.self) private var syncService: SyncService?
    @Environment(PSToastManager.self) private var toastManager: PSToastManager?

    // Form state
    @State private var itemName = ""
    @State private var description = ""
    @State private var quantity: Int = 1
    @State private var foodCategory = "other"
    @State private var listingType = "share"
    @State private var pickupAddress = ""
    @State private var pickupNotes = ""
    @State private var areaName = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Pantry item picker
    @Query(filter: #Predicate<PantryItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\PantryItem.expiryDate)])
    private var pantryItems: [PantryItem]
    @State private var selectedPantryItem: PantryItem?

    private var isFormValid: Bool {
        !itemName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                listingTypeToggle
                pantryItemPicker
                formFields
                pickupFields
                safetyNote
                submitButton
            }
            .padding(.vertical, PSSpacing.lg)
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Create Listing"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Cancel")) { dismiss() }
                    .foregroundStyle(PSColors.textSecondary)
            }
        }
    }

    // MARK: - Listing Type Toggle

    private var listingTypeToggle: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text(String(localized: "Listing Type"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PSColors.textSecondary)

            HStack(spacing: 0) {
                toggleButton(
                    title: String(localized: "Share / Giveaway"),
                    icon: "hand.raised.fill",
                    type: "share"
                )
                toggleButton(
                    title: String(localized: "Donate"),
                    icon: "heart.fill",
                    type: "donate"
                )
            }
            .padding(4)
            .background(PSColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        }
    }

    private func toggleButton(title: String, icon: String, type: String) -> some View {
        Button {
            withAnimation(PSMotion.springQuick) { listingType = type }
        } label: {
            HStack(spacing: PSSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(14)))
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
            }
            .foregroundStyle(listingType == type ? PSColors.textPrimary : PSColors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PSSpacing.md)
            .background {
                if listingType == type {
                    RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                        .fill(PSColors.surfaceCard)
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                }
            }
        }
    }

    // MARK: - Pantry Item Picker

    private var pantryItemPicker: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text(String(localized: "Quick Pick from Pantry"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PSColors.textSecondary)

            if pantryItems.isEmpty {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "tray")
                        .font(.system(size: 14))
                    Text(String(localized: "No pantry items to share"))
                        .font(.system(size: 14))
                }
                .foregroundStyle(PSColors.textTertiary)
                .padding(.vertical, PSSpacing.sm)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PSSpacing.sm) {
                        ForEach(pantryItems) { item in
                            Button {
                                selectedPantryItem = item
                                itemName = item.name
                                foodCategory = mapFoodCategory(item.category)
                            } label: {
                                HStack(spacing: PSSpacing.xs) {
                                    Image(systemName: item.category.icon)
                                        .font(.system(size: 12))
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .padding(.horizontal, PSSpacing.md)
                                .padding(.vertical, PSSpacing.sm)
                                .foregroundStyle(
                                    selectedPantryItem?.id == item.id
                                    ? PSColors.textOnPrimary
                                    : PSColors.textSecondary
                                )
                                .background(
                                    selectedPantryItem?.id == item.id
                                    ? PSColors.primaryGreen
                                    : PSColors.backgroundSecondary
                                )
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Form Fields

    private var formFields: some View {
        VStack(spacing: PSSpacing.lg) {
            // Item name
            fieldGroup(label: String(localized: "Item Name"), required: true) {
                TextField(String(localized: "What are you sharing?"), text: $itemName)
                    .font(.system(size: 16))
                    .foregroundStyle(PSColors.textPrimary)
            }

            // Description
            fieldGroup(label: String(localized: "Description")) {
                TextField(String(localized: "Tell the community about this item..."), text: $description, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(3...6)
            }

            // Quantity
            fieldGroup(label: String(localized: "Quantity")) {
                HStack {
                    Button {
                        if quantity > 1 { withAnimation { quantity -= 1 } }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(quantity > 1 ? PSColors.textSecondary : PSColors.textTertiary)
                    }

                    Text("\(quantity)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                        .frame(width: 48)
                        .contentTransition(.numericText())

                    Button {
                        if quantity < 99 { withAnimation { quantity += 1 } }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(PSColors.primaryGreen)
                    }

                    Spacer()
                }
            }

            // Food category
            fieldGroup(label: String(localized: "Category")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(foodCategories, id: \.key) { cat in
                            Button {
                                withAnimation(PSMotion.springQuick) { foodCategory = cat.key }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(cat.emoji)
                                        .font(.system(size: 14))
                                    Text(cat.name)
                                        .font(.system(size: 13, weight: foodCategory == cat.key ? .bold : .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(
                                    foodCategory == cat.key ? .white : PSColors.textSecondary
                                )
                                .background(
                                    foodCategory == cat.key ? PSColors.primaryGreen : PSColors.backgroundSecondary
                                )
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pickup Fields

    private var pickupFields: some View {
        VStack(spacing: PSSpacing.lg) {
            fieldGroup(label: String(localized: "Area / Neighborhood")) {
                TextField(String(localized: "e.g. Downtown, Westside"), text: $areaName)
                    .font(.system(size: 16))
                    .foregroundStyle(PSColors.textPrimary)
            }

            if listingType == "share" {
                fieldGroup(label: String(localized: "Pickup Address")) {
                    TextField(String(localized: "Address or meeting point"), text: $pickupAddress)
                        .font(.system(size: 16))
                        .foregroundStyle(PSColors.textPrimary)
                }

                fieldGroup(label: String(localized: "Pickup Notes")) {
                    TextField(String(localized: "e.g. Ring doorbell, leave at porch"), text: $pickupNotes)
                        .font(.system(size: 16))
                        .foregroundStyle(PSColors.textPrimary)
                }
            }
        }
    }

    // MARK: - Reusable Field Group

    private func fieldGroup<Content: View>(
        label: String,
        required: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)
                if required {
                    Text("*")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PSColors.expiredRed)
                }
            }

            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(PSColors.backgroundSecondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                        .strokeBorder(PSColors.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Safety Note

    private var safetyNote: some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 18))
                .foregroundStyle(PSColors.primaryGreen)
            Text(String(localized: "Please ensure all shared food is safe, properly stored, and within its use-by date."))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
        }
        .padding(PSSpacing.md)
        .background(PSColors.primaryGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
    }

    // MARK: - Submit

    private var submitButton: some View {
        VStack(spacing: PSSpacing.md) {
            if showError {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(PSColors.expiredRed)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PSColors.expiredRed.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            }

            PSButton(
                title: listingType == "share"
                    ? String(localized: "Share with Community")
                    : String(localized: "List for Donation"),
                icon: listingType == "share" ? "hand.raised.fill" : "heart.fill",
                isLoading: isSubmitting
            ) {
                submitListing()
            }
            .disabled(!isFormValid || isSubmitting)
            .opacity(isFormValid ? 1 : 0.5)
        }
    }

    // MARK: - Submit Action

    private func submitListing() {
        guard let userId = authManager?.currentUserId else {
            PSHaptics.shared.error()
            errorMessage = String(localized: "Please sign in to create a listing.")
            withAnimation(PSMotion.springQuick) { showError = true }
            return
        }

        PSHaptics.shared.mediumTap()
        isSubmitting = true
        showError = false

        let input = CreateListingInput(
            itemName: itemName.trimmingCharacters(in: .whitespaces),
            description: description.isEmpty ? nil : description,
            quantity: quantity,
            listingType: listingType,
            pickupAddress: pickupAddress.isEmpty ? nil : pickupAddress,
            pickupNotes: pickupNotes.isEmpty ? nil : pickupNotes,
            foodCategory: foodCategory,
            areaName: areaName.isEmpty ? nil : areaName
        )

        Task {
            let success = await communityService?.createListing(input, userId: userId) ?? false
            isSubmitting = false

            if success {
                // Also create local SwiftData listing
                let localListing = SharedListing(
                    itemName: input.itemName,
                    itemDescription: input.description ?? "",
                    quantity: "\(input.quantity)",
                    listingType: listingType == "share" ? .share : .donate,
                    pickupAddress: input.pickupAddress ?? "",
                    pickupNotes: input.pickupNotes,
                    expiryDate: Date.daysFromNow(7)
                )
                modelContext.insert(localListing)
                do {
                    try modelContext.save()
                    PSLogger.general.info("Local listing created successfully")
                } catch {
                    PSLogger.general.error("Failed to save local listing: \(error.localizedDescription)")
                    toastManager?.show(.error(String(localized: "Failed to save locally. Please try again.")))
                }

                // Mark pantry item if selected
                if let pantryItem = selectedPantryItem {
                    if listingType == "share" {
                        pantryItem.isShared = true
                    } else {
                        pantryItem.isDonated = true
                    }
                    do {
                        try modelContext.save()
                        PSLogger.general.info("Pantry item marked successfully")
                    } catch {
                        PSLogger.general.error("Failed to mark pantry item: \(error.localizedDescription)")
                    }
                }

                // Trigger celebration
                if listingType == "share" {
                    celebrationManager?.onShareCompleted(itemName: itemName, modelContext: modelContext)
                } else {
                    celebrationManager?.onDonationCompleted(itemName: itemName, modelContext: modelContext)
                }

                // Record impact
                await syncService?.recordImpactEvent(
                    userId: userId,
                    eventType: listingType == "share" ? "shared" : "donated"
                )

                onComplete(true)
            } else {
                errorMessage = communityService?.error ?? String(localized: "Something went wrong. Please try again.")
                withAnimation(PSMotion.springQuick) { showError = true }
            }
        }
    }

    // MARK: - Food Categories

    private let foodCategories: [(key: String, name: String, emoji: String)] = [
        ("fruits", String(localized: "Fruits"), "🍎"),
        ("vegetables", String(localized: "Vegetables"), "🥬"),
        ("dairy", String(localized: "Dairy"), "🥛"),
        ("meat", String(localized: "Meat"), "🥩"),
        ("bakery", String(localized: "Bakery"), "🍞"),
        ("grains", String(localized: "Grains"), "🌾"),
        ("frozen", String(localized: "Frozen"), "🧊"),
        ("canned", String(localized: "Canned"), "🥫"),
        ("beverages", String(localized: "Beverages"), "🥤"),
        ("condiments", String(localized: "Condiments"), "🧂"),
        ("snacks", String(localized: "Snacks"), "🍿"),
        ("other", String(localized: "Other"), "🍽️"),
    ]

    // Map PantryItem FoodCategory to string key
    private func mapFoodCategory(_ category: FoodCategory) -> String {
        switch category {
        case .fruits: return "fruits"
        case .vegetables: return "vegetables"
        case .dairy: return "dairy"
        case .meat: return "meat"
        case .seafood: return "meat"
        case .bakery: return "bakery"
        case .grains: return "grains"
        case .frozen: return "frozen"
        case .canned: return "canned"
        case .beverages: return "beverages"
        case .condiments: return "condiments"
        case .snacks: return "snacks"
        case .other: return "other"
        }
    }
}

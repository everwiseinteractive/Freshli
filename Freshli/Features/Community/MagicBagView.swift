import SwiftUI
import SwiftData

// MARK: - Magic Bag View
// Peer-to-peer "Reverse Magic Bag" — users bundle assorted pantry items
// they're clearing out (moving house, holiday, over-bought) and post them
// for neighbours to claim for free. Inspired by the Too Good To Go merchant
// model but for individuals.

struct MagicBagView: View {
    var onComplete: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(CommunityService.self) private var communityService
    @Environment(CelebrationManager.self) private var celebrationManager
    @Environment(SyncService.self) private var syncService
    @Environment(PSToastManager.self) private var toastManager

    // MARK: - State

    @State private var bagTitle = ""
    @State private var bagDescription = ""
    @State private var pickupAddress = ""
    @State private var pickupWindow = ""
    @State private var selectedItems: Set<FreshliItem.ID> = []
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var pulseBag = false

    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var pantryItems: [FreshliItem]

    private var selectedPantryItems: [FreshliItem] {
        pantryItems.filter { selectedItems.contains($0.id) }
    }

    private var isFormValid: Bool {
        !bagTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedItems.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                heroHeader
                titleSection
                itemPickerSection
                descriptionSection
                pickupSection
                submitButton
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Post Magic Bag 🎁"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Cancel")) { dismiss() }
                    .foregroundStyle(PSColors.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseBag = true
            }
        }
        .alert(String(localized: "Error"), isPresented: $showError) {
            Button(String(localized: "OK"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x7C3AED), Color(hex: 0xDB2777)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))

            VStack(spacing: PSSpacing.sm) {
                Text("🎁")
                    .font(.system(size: PSLayout.scaledFont(48)))
                    .scaleEffect(pulseBag ? 1.08 : 1.0)

                Text(String(localized: "Your Magic Bag"))
                    .font(.system(size: PSLayout.scaledFont(22), weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(String(localized: "Bundle pantry items you're clearing out and give them to a neighbour — moving house, going on holiday, over-bought. Nothing wasted."))
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(PSSpacing.xl)
        }
    }

    // MARK: - Bag Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Label(String(localized: "Bag Name"), systemImage: "tag.fill")
                .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                .foregroundStyle(PSColors.textSecondary)

            TextField(String(localized: "e.g. Moving house — pantry clear-out"), text: $bagTitle)
                .font(.system(size: PSLayout.scaledFont(16)))
                .foregroundStyle(PSColors.textPrimary)
                .padding(PSSpacing.lg)
                .background(PSColors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                        .strokeBorder(PSColors.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Item Picker

    private var itemPickerSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack {
                Label(String(localized: "Pick Items to Bundle"), systemImage: "basket.fill")
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textSecondary)
                Spacer()
                if !selectedItems.isEmpty {
                    Text("\(selectedItems.count) selected")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(Color(hex: 0x7C3AED))
                        .padding(.horizontal, PSSpacing.sm)
                        .padding(.vertical, 3)
                        .background(Color(hex: 0x7C3AED).opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if pantryItems.isEmpty {
                HStack {
                    Image(systemName: "refrigerator")
                        .foregroundStyle(PSColors.textTertiary)
                    Text(String(localized: "Add items to your pantry first"))
                        .font(.system(size: PSLayout.scaledFont(14)))
                        .foregroundStyle(PSColors.textSecondary)
                }
                .padding(PSSpacing.lg)
                .frame(maxWidth: .infinity)
                .background(PSColors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            } else {
                LazyVStack(spacing: PSSpacing.xs) {
                    ForEach(pantryItems) { item in
                        pantryItemRow(item)
                    }
                }
                .padding(PSSpacing.sm)
                .background(PSColors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                        .strokeBorder(PSColors.border, lineWidth: 1)
                )
            }
        }
    }

    private func pantryItemRow(_ item: FreshliItem) -> some View {
        let isSelected = selectedItems.contains(item.id)
        return Button {
            PSHaptics.shared.selection()
            withAnimation(PSMotion.springBouncy) {
                if isSelected { selectedItems.remove(item.id) }
                else { selectedItems.insert(item.id) }
            }
        } label: {
            HStack(spacing: PSSpacing.md) {
                Text(item.category.emoji)
                    .font(.system(size: PSLayout.scaledFont(22)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text(item.quantityDisplay)
                        .font(.system(size: PSLayout.scaledFont(12)))
                        .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: 0x7C3AED) : PSColors.backgroundSecondary)
                        .frame(width: PSLayout.scaled(24), height: PSLayout.scaled(24))
                        .overlay(
                            Circle().strokeBorder(
                                isSelected ? Color(hex: 0x7C3AED) : PSColors.border,
                                lineWidth: 1.5
                            )
                        )
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: PSLayout.scaledFont(10), weight: .black))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, PSSpacing.md)
            .padding(.vertical, PSSpacing.sm)
            .background(isSelected ? Color(hex: 0x7C3AED).opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Label(String(localized: "Tell your neighbours more (optional)"), systemImage: "text.alignleft")
                .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                .foregroundStyle(PSColors.textSecondary)

            TextField(
                String(localized: "e.g. Everything is in good condition. Mix of tinned goods, pasta, and spices."),
                text: $bagDescription,
                axis: .vertical
            )
            .font(.system(size: PSLayout.scaledFont(15)))
            .foregroundStyle(PSColors.textPrimary)
            .lineLimit(3...6)
            .padding(PSSpacing.lg)
            .background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                    .strokeBorder(PSColors.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Pickup Details

    private var pickupSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Label(String(localized: "Pickup Details (optional)"), systemImage: "mappin.circle.fill")
                .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                .foregroundStyle(PSColors.textSecondary)

            VStack(spacing: PSSpacing.sm) {
                TextField(String(localized: "Area or postcode"), text: $pickupAddress)
                    .font(.system(size: PSLayout.scaledFont(15)))
                    .foregroundStyle(PSColors.textPrimary)
                    .padding(PSSpacing.lg)
                    .background(PSColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))

                TextField(String(localized: "Pickup window e.g. \"Evenings this week\""), text: $pickupWindow)
                    .font(.system(size: PSLayout.scaledFont(15)))
                    .foregroundStyle(PSColors.textPrimary)
                    .padding(PSSpacing.lg)
                    .background(PSColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous)
                    .strokeBorder(PSColors.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        VStack(spacing: PSSpacing.md) {
            Button {
                PSHaptics.shared.mediumTap()
                submitBag()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: PSSpacing.sm) {
                            Text("🎁")
                            Text(String(localized: "Post My Magic Bag"))
                                .font(.system(size: PSLayout.scaledFont(17), weight: .black))
                        }
                        .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PSSpacing.lg)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x7C3AED), Color(hex: 0xDB2777)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                .shadow(color: Color(hex: 0x7C3AED).opacity(0.35), radius: 16, y: 6)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!isFormValid || isSubmitting)
            .opacity(isFormValid ? 1 : 0.5)

            Text(String(localized: "Your bag will be visible to neighbours. Claim is first-come, first-served."))
                .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Submit Logic

    private func submitBag() {
        guard let userId = authManager.currentUserId else {
            errorMessage = String(localized: "Please sign in to post a Magic Bag.")
            showError = true
            return
        }
        guard isFormValid else { return }

        isSubmitting = true

        // Build a composite description
        let itemList = selectedPantryItems.map { "• \($0.name) (\($0.quantityDisplay))" }.joined(separator: "\n")
        let fullDescription = [bagDescription, itemList].filter { !$0.isEmpty }.joined(separator: "\n\n")

        let input = CreateListingInput(
            itemName: bagTitle.trimmingCharacters(in: .whitespaces),
            description: fullDescription.isEmpty ? nil : fullDescription,
            quantity: selectedItems.count,
            listingType: "magic_bag",
            pickupAddress: pickupAddress.isEmpty ? nil : pickupAddress,
            pickupNotes: pickupWindow.isEmpty ? nil : pickupWindow,
            foodCategory: "other",
            areaName: pickupAddress.isEmpty ? nil : pickupAddress
        )

        Task {
            let success = await communityService.createListing(input, userId: userId)
            isSubmitting = false

            if success {
                // Mark all selected items as shared
                for item in selectedPantryItems {
                    item.isShared = true
                }
                try? modelContext.save()

                // Record impact
                await syncService.recordImpactEvent(
                    userId: userId,
                    eventType: "magic_bag",
                    itemName: bagTitle,
                    co2Avoided: Double(selectedItems.count) * 2.5
                )

                celebrationManager.fireShareCompleted(itemName: bagTitle, modelContext: modelContext)
                onComplete(true)
            } else {
                errorMessage = String(localized: "Failed to post your Magic Bag. Please try again.")
                showError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MagicBagView { _ in }
            .environment(AuthManager())
            .environment(CommunityService())
            .environment(CelebrationManager())
    }
}

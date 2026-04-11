import SwiftUI
import SwiftData

// MARK: - Retailer Link View
// Allows users to connect supermarket loyalty accounts so purchases
// automatically appear in their digital pantry. Architecture is production-ready:
// swap out `RetailerIntegrationService.simulatedPurchases` for real OAuth flows.

struct RetailerLinkView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PSToastManager.self) private var toastManager
    @Environment(\.dismiss) private var dismiss

    @State private var retailerService = RetailerIntegrationService.shared
    @State private var connectingId: String?
    @State private var showImportSheet = false
    @State private var showDisconnectAlert = false
    @State private var disconnectTarget: RetailerDefinition?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                heroHeader
                connectedSection
                availableSection
                pendingPurchasesSection
                footerNote
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Supermarket Sync"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await retailerService.syncAll() }
        .alert(String(localized: "Disconnect \(disconnectTarget?.name ?? "")"), isPresented: $showDisconnectAlert) {
            Button(String(localized: "Disconnect"), role: .destructive) {
                if let r = disconnectTarget { retailerService.disconnect(retailer: r) }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Future purchases won't be synced. Your existing pantry items won't be removed."))
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: PSSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PSColors.primaryGreen.opacity(0.15), PSColors.accentTeal.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: PSLayout.scaled(80), height: PSLayout.scaled(80))
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: PSLayout.scaledFont(34)))
                    .foregroundStyle(PSColors.primaryGreen)
            }

            VStack(spacing: PSSpacing.xs) {
                Text(String(localized: "Connect Your Supermarket"))
                    .font(.system(size: PSLayout.scaledFont(20), weight: .black, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)
                Text(String(localized: "Link your loyalty card and your shop automatically lands in your pantry — no barcode scanning needed."))
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }

    // MARK: - Connected Retailers

    @ViewBuilder
    private var connectedSection: some View {
        if !retailerService.connectedRetailers.isEmpty {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                sectionHeader("Connected", icon: "checkmark.seal.fill", color: PSColors.primaryGreen)

                ForEach(retailerService.connectedRetailers) { retailer in
                    connectedRetailerRow(retailer)
                }
            }
        }
    }

    private func connectedRetailerRow(_ retailer: RetailerDefinition) -> some View {
        HStack(spacing: PSSpacing.lg) {
            retailerLogo(retailer, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(retailer.name)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                HStack(spacing: 4) {
                    Circle().fill(PSColors.primaryGreen).frame(width: 6, height: 6)
                    Text(String(localized: "Synced · \(retailer.loyaltyProgramName)"))
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }

            Spacer()

            Button {
                disconnectTarget = retailer
                showDisconnectAlert = true
            } label: {
                Text(String(localized: "Unlink"))
                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                    .foregroundStyle(PSColors.expiredRed)
                    .padding(.horizontal, PSSpacing.md)
                    .padding(.vertical, PSSpacing.xs)
                    .background(PSColors.expiredRed.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(PSSpacing.lg)
        .background(PSColors.primaryGreen.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(PSColors.primaryGreen.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Available Retailers

    private var availableSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            sectionHeader("Available", icon: "link.badge.plus", color: PSColors.accentTeal)

            let unconnected = RetailerDefinition.all.filter { !retailerService.connectedRetailerIds.contains($0.id) }
            ForEach(unconnected) { retailer in
                availableRetailerRow(retailer)
            }
        }
    }

    private func availableRetailerRow(_ retailer: RetailerDefinition) -> some View {
        HStack(spacing: PSSpacing.lg) {
            retailerLogo(retailer, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(retailer.name)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: retailer.supportsAutoSync ? "arrow.triangle.2.circlepath" : "qrcode")
                        .font(.system(size: PSLayout.scaledFont(10)))
                        .foregroundStyle(PSColors.textTertiary)
                    Text(retailer.supportsAutoSync ? "Auto-sync · \(retailer.loyaltyProgramName)" : "Manual import · \(retailer.loyaltyProgramName)")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
            }

            Spacer()

            if connectingId == retailer.id {
                ProgressView()
                    .tint(retailer.logoColor)
                    .frame(width: 60)
            } else {
                Button {
                    connectRetailer(retailer)
                } label: {
                    Text(String(localized: "Connect"))
                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, PSSpacing.md)
                        .padding(.vertical, PSSpacing.xs)
                        .background(retailer.logoColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Pending Purchases

    @ViewBuilder
    private var pendingPurchasesSection: some View {
        let pending = retailerService.pendingPurchases.filter { !$0.isImported }
        if !pending.isEmpty {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                sectionHeader("Ready to Import (\(pending.count))", icon: "tray.and.arrow.down.fill", color: PSColors.secondaryAmber)

                ForEach(pending) { purchase in
                    purchaseRow(purchase)
                }

                Button {
                    importAll(pending)
                } label: {
                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: "square.and.arrow.down")
                        Text(String(localized: "Import All to Pantry"))
                            .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PSSpacing.lg)
                    .background(PSColors.primaryGreen)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                    .shadow(color: PSColors.primaryGreen.opacity(0.3), radius: 12, y: 4)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, PSSpacing.xs)
            }
        }
    }

    private func purchaseRow(_ purchase: RetailerPurchase) -> some View {
        HStack(spacing: PSSpacing.lg) {
            Text(FoodCategory.fromString(purchase.category).emoji)
                .font(.system(size: PSLayout.scaledFont(24)))

            VStack(alignment: .leading, spacing: 2) {
                Text(purchase.itemName)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)
                Text("\(purchase.retailerName) · \(formatDate(purchase.purchasedAt))")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
            }

            Spacer()

            Button {
                importSingle(purchase)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: PSLayout.scaledFont(22)))
                    .foregroundStyle(PSColors.primaryGreen)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, PSSpacing.lg)
        .padding(.vertical, PSSpacing.sm)
        .background(PSColors.secondaryAmber.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                .strokeBorder(PSColors.secondaryAmber.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footerNote: some View {
        VStack(spacing: PSSpacing.xs) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: PSLayout.scaledFont(16)))
                .foregroundStyle(PSColors.textTertiary)
            Text(String(localized: "Freshli uses read-only access to your loyalty account. We never see payment info, and you can disconnect at any time."))
                .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, PSSpacing.xl)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(13)))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                .foregroundStyle(PSColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }

    private func retailerLogo(_ retailer: RetailerDefinition, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(retailer.logoColor.opacity(0.12))
                .frame(width: PSLayout.scaled(size), height: PSLayout.scaled(size))
            Text(String(retailer.name.prefix(1)))
                .font(.system(size: PSLayout.scaledFont(size * 0.4), weight: .black, design: .rounded))
                .foregroundStyle(retailer.logoColor)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func connectRetailer(_ retailer: RetailerDefinition) {
        PSHaptics.shared.mediumTap()
        connectingId = retailer.id
        Task {
            let success = await retailerService.connect(retailer: retailer)
            connectingId = nil
            if success {
                toastManager.show(.success("Connected to \(retailer.name)! Purchases are ready to import."))
            }
        }
    }

    private func importSingle(_ purchase: RetailerPurchase) {
        PSHaptics.shared.lightTap()
        createPantryItem(from: purchase)
        retailerService.markImported(purchase)
        toastManager.show(.itemAdded(purchase.itemName))
    }

    private func importAll(_ purchases: [RetailerPurchase]) {
        PSHaptics.shared.celebrate()
        for purchase in purchases {
            createPantryItem(from: purchase)
            retailerService.markImported(purchase)
        }
        toastManager.show(.success("Imported \(purchases.count) items to your pantry!"))
    }

    private func createPantryItem(from purchase: RetailerPurchase) {
        let category = FoodCategory.fromString(purchase.category)
        let item = FreshliItem(
            name: purchase.itemName,
            category: category,
            storageLocation: .fridge,
            quantity: purchase.quantity,
            unit: MeasurementUnit(rawValue: purchase.unit) ?? .pieces,
            expiryDate: Date().addingTimeInterval(TimeInterval(category.defaultExpiryDays) * 86_400),
            notes: "Imported from \(purchase.retailerName)"
        )
        modelContext.insert(item)
        try? modelContext.save()
    }
}

// MARK: - FoodCategory convenience

private extension FoodCategory {
    static func fromString(_ string: String) -> FoodCategory {
        FoodCategory.allCases.first { $0.rawValue == string } ?? .other
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RetailerLinkView()
            .environment(PSToastManager())
    }
}

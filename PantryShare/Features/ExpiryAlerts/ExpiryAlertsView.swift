import SwiftUI
import SwiftData

struct ExpiryAlertsView: View {
    @Query(filter: #Predicate<PantryItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\PantryItem.expiryDate)])
    private var allItems: [PantryItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?
    @Environment(PSToastManager.self) private var toastManager: PSToastManager?

    private var expiredItems: [PantryItem] {
        allItems.filter { $0.expiryStatus == .expired }
    }

    private var expiringTodayItems: [PantryItem] {
        allItems.filter { $0.expiryStatus == .expiringToday }
    }

    private var expiringSoonItems: [PantryItem] {
        allItems.filter { $0.expiryStatus == .expiringSoon }
    }

    private var hasAlerts: Bool {
        !expiredItems.isEmpty || !expiringTodayItems.isEmpty || !expiringSoonItems.isEmpty
    }

    private var totalUrgentCount: Int {
        expiredItems.count + expiringTodayItems.count + expiringSoonItems.count
    }

    var body: some View {
        ScrollView {
            if !hasAlerts {
                VStack(spacing: PSSpacing.xxl) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: PSLayout.scaledFont(56)))
                        .foregroundStyle(PSColors.primaryGreen)
                        .symbolEffect(.bounce)
                        .padding(.top, PSSpacing.xxxxl)

                    VStack(spacing: PSSpacing.sm) {
                        Text(String(localized: "All Clear!"))
                            .font(PSTypography.title2)
                            .foregroundStyle(PSColors.textPrimary)
                        Text(String(localized: "No items are expiring soon. Great job managing your pantry!"))
                            .font(PSTypography.callout)
                            .foregroundStyle(PSColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, PSLayout.formHorizontalPadding)
                }
            } else {
                VStack(spacing: PSSpacing.xxl) {
                    // Urgency Summary Banner
                    urgencySummary

                    if !expiredItems.isEmpty {
                        alertSection(
                            title: String(localized: "Expired"),
                            icon: "xmark.circle.fill",
                            color: PSColors.expiredRed,
                            items: expiredItems,
                            sectionIndex: 0
                        )
                    }

                    if !expiringTodayItems.isEmpty {
                        alertSection(
                            title: String(localized: "Expires Today"),
                            icon: "clock.fill",
                            color: PSColors.expiredRed.opacity(0.85),
                            items: expiringTodayItems,
                            sectionIndex: 1
                        )
                    }

                    if !expiringSoonItems.isEmpty {
                        alertSection(
                            title: String(localized: "Expiring Soon"),
                            icon: "exclamationmark.triangle.fill",
                            color: PSColors.warningAmber,
                            items: expiringSoonItems,
                            sectionIndex: 2
                        )
                    }
                }
                .padding(.vertical, PSSpacing.lg)
            }
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Expiry Alerts"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if hasAlerts { PSHaptics.shared.warning() }
        }
    }

    // MARK: - Urgency Summary

    private var urgencySummary: some View {
        HStack(spacing: PSSpacing.lg) {
            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                Text(String(localized: "\(totalUrgentCount) items need attention"))
                    .font(PSTypography.bodyMedium)
                    .foregroundStyle(.white)
                Text(String(localized: "Rescue them before they go to waste"))
                    .font(PSTypography.caption1)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: PSLayout.scaledFont(28)))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(PSSpacing.xl)
        .background(
            LinearGradient(
                colors: [PSColors.expiredRed, PSColors.expiredRed.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .screenPadding()
        .staggeredAppearance(index: 0)
    }

    private func alertSection(title: String, icon: String, color: Color, items: [PantryItem], sectionIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)
                PSBadge(text: "\(items.count)", color: color, style: .filled)
                Spacer()
            }
            .screenPadding()

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ExpiryAlertCard(item: item) { action in
                    handleAction(action, for: item)
                }
                .screenPadding()
                .staggeredAppearance(index: sectionIndex * 3 + index + 1)
            }
        }
    }

    private func handleAction(_ action: ExpiryAction, for item: PantryItem) {
        let itemName = item.name
        withAnimation(PSMotion.springDefault) {
            switch action {
            case .cook:
                PSHaptics.shared.success()
                item.isConsumed = true
                toastManager?.show(.itemConsumed(itemName))
                celebrationManager?.onFoodSaved(modelContext: modelContext)
                PSLogger.general.info("Item marked as consumed: \(itemName)")
            case .share:
                PSHaptics.shared.success()
                item.isShared = true
                toastManager?.show(.itemShared(itemName))
                celebrationManager?.onShareCompleted(itemName: itemName, modelContext: modelContext)
                PSLogger.general.info("Item marked as shared: \(itemName)")
            case .donate:
                PSHaptics.shared.success()
                item.isDonated = true
                toastManager?.show(.itemDonated(itemName))
                celebrationManager?.onDonationCompleted(itemName: itemName, modelContext: modelContext)
                PSLogger.general.info("Item marked as donated: \(itemName)")
            case .delete:
                PSHaptics.shared.heavyTap()
                modelContext.delete(item)
                toastManager?.show(.itemDeleted(itemName))
                PSLogger.general.info("Item deleted: \(itemName)")
            }
            do {
                try modelContext.save()
                WidgetDataService.updateWidgetData(modelContext: modelContext)
            } catch {
                PSLogger.general.error("Failed to save after expiry action: \(error.localizedDescription)")
                toastManager?.show(.error(String(localized: "Failed to save changes")))
            }
        }
    }
}

enum ExpiryAction {
    case cook
    case share
    case donate
    case delete
}

struct ExpiryAlertCard: View {
    let item: PantryItem
    let onAction: (ExpiryAction) -> Void

    var body: some View {
        VStack(spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.md) {
                Image(systemName: item.category.icon)
                    .font(.system(size: PSLayout.scaledFont(18), weight: .semibold))
                    .foregroundStyle(PSColors.categoryColor(for: item.category))
                    .frame(width: PSLayout.scaled(40), height: PSLayout.scaled(40))
                    .background(PSColors.categoryColor(for: item.category).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))

                VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                    Text(item.name)
                        .font(PSTypography.bodyMedium)
                        .foregroundStyle(PSColors.textPrimary)
                    Text("\(item.quantityDisplay) · \(item.expiryDate.expiryDisplayText)")
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.expiryColor(for: item.expiryStatus))
                }

                Spacer()
            }

            HStack(spacing: PSSpacing.sm) {
                ActionChip(icon: "fork.knife", title: String(localized: "Cook"), color: PSColors.primaryGreen) {
                    onAction(.cook)
                }
                ActionChip(icon: "hand.raised", title: String(localized: "Share"), color: PSColors.infoBlue) {
                    onAction(.share)
                }
                ActionChip(icon: "heart", title: String(localized: "Donate"), color: PSColors.accentTeal) {
                    onAction(.donate)
                }
            }
        }
        .padding(PSSpacing.cardPadding)
        .background(PSColors.expiryBackground(for: item.expiryStatus))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(PSColors.expiryColor(for: item.expiryStatus).opacity(0.2), lineWidth: 1)
        }
    }
}

struct ActionChip: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PSSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                Text(title)
                    .font(PSTypography.caption2Medium)
            }
            .padding(.horizontal, PSSpacing.md)
            .padding(.vertical, PSSpacing.sm)
            .foregroundStyle(color)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

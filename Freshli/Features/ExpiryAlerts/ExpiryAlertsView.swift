import SwiftUI
import SwiftData

struct ExpiryAlertsView: View {
    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var allItems: [FreshliItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CelebrationManager.self) private var celebrationManager
    @Environment(PSToastManager.self) private var toastManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false

    private var expiredItems: [FreshliItem] {
        allItems.filter { $0.expiryStatus == .expired }
    }

    private var expiringTodayItems: [FreshliItem] {
        allItems.filter { $0.expiryStatus == .expiringToday }
    }

    private var expiringSoonItems: [FreshliItem] {
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
                allClearView
            } else {
                LazyVStack(spacing: PSSpacing.xxl, pinnedViews: []) {
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
                            icon: "clock.badge.exclamationmark.fill",
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
                .padding(.bottom, PSSpacing.xxxl)
            }
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Expiry Alerts"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            let anim: Animation = reduceMotion ? .easeOut(duration: 0.15) : PSMotion.springDefault.delay(0.05)
            withAnimation(anim) { appeared = true }
            if hasAlerts { PSHaptics.shared.warning() }
        }
    }

    // MARK: - All Clear State

    private var allClearView: some View {
        VStack(spacing: PSSpacing.xxl) {
            Spacer(minLength: PSSpacing.xxxxl)

            ZStack {
                Circle()
                    .fill(PSColors.primaryGreen.opacity(0.10))
                    .frame(width: PSLayout.scaled(120), height: PSLayout.scaled(120))
                Circle()
                    .fill(PSColors.primaryGreen.opacity(0.06))
                    .frame(width: PSLayout.scaled(160), height: PSLayout.scaled(160))

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: PSLayout.scaledFont(56)))
                    .foregroundStyle(PSColors.primaryGreen)
                    .symbolEffect(.bounce)
            }
            .scaleEffect(appeared ? 1.0 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: PSSpacing.sm) {
                Text(String(localized: "All Clear!"))
                    .font(.system(size: PSLayout.scaledFont(28), weight: .black))
                    .foregroundStyle(PSColors.textPrimary)
                Text(String(localized: "Every item in your pantry is fresh.\nKeep up the great work! 🌱"))
                    .font(PSTypography.callout)
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .padding(.horizontal, PSLayout.formHorizontalPadding)

            Spacer(minLength: PSSpacing.xxxxl)
        }
    }

    // MARK: - Urgency Summary Banner

    private var urgencySummary: some View {
        ZStack(alignment: .leading) {
            // Glowing background
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            PSColors.expiredRed,
                            Color(hex: 0xC0392B)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: PSColors.expiredRed.opacity(0.45), radius: 20, x: 0, y: 8)

            // Decorative circles
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.06))
                        .frame(width: PSLayout.scaled(100), height: PSLayout.scaled(100))
                        .offset(x: 20, y: -15)
                    Circle()
                        .fill(.white.opacity(0.04))
                        .frame(width: PSLayout.scaled(60), height: PSLayout.scaled(60))
                        .offset(x: -10, y: 20)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))

            HStack(spacing: PSSpacing.lg) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: PSLayout.scaledFont(26), weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)

                VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                    Text(String(localized: "\(totalUrgentCount) item\(totalUrgentCount == 1 ? "" : "s") need attention"))
                        .font(.system(size: PSLayout.scaledFont(17), weight: .black))
                        .foregroundStyle(.white)
                    Text(String(localized: "Rescue them before they go to waste"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                        .foregroundStyle(.white.opacity(0.80))
                }

                Spacer()
            }
            .padding(.horizontal, PSSpacing.xl)
            .padding(.vertical, PSSpacing.lg)
        }
        .screenPadding()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // MARK: - Alert Section

    private func alertSection(title: String, icon: String, color: Color, items: [FreshliItem], sectionIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            // Section header pill
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: PSLayout.scaled(30), height: PSLayout.scaled(30))
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(17), weight: .black))
                    .foregroundStyle(PSColors.textPrimary)
                Text("\(items.count)")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, PSSpacing.sm)
                    .padding(.vertical, PSSpacing.xxs)
                    .background(color)
                    .clipShape(Capsule())
                Spacer()
            }
            .screenPadding()

            VStack(spacing: PSSpacing.md) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ExpiryAlertCard(item: item) { action in
                        handleAction(action, for: item)
                    }
                    .staggeredAppearance(index: sectionIndex * 4 + index + 1)
                }
            }
            .screenPadding()
        }
    }

    // MARK: - Handle Action (freeze-safe)
    // Heavy I/O (modelContext.save, WidgetDataService) runs OUTSIDE withAnimation
    // so it never blocks the main thread during the animation pass.

    @MainActor
    private func handleAction(_ action: ExpiryAction, for item: FreshliItem) {
        let itemName = item.name

        // 1. Apply state mutations (these are lightweight — just property sets)
        switch action {
        case .cook:
            item.isConsumed = true
        case .share:
            item.isShared = true
        case .donate:
            item.isDonated = true
        case .delete:
            modelContext.delete(item)
        }

        // 2. Trigger animations for state changes
        withAnimation(FLMotion.adaptive(PSMotion.springDefault, reduceMotion: reduceMotion)) {
            // SwiftData @Query will automatically update once save completes
        }

        // 3. Haptics & toasts (synchronous but fast)
        switch action {
        case .cook:
            PSHaptics.shared.success()
            toastManager.show(.itemConsumed(itemName))
        case .share:
            PSHaptics.shared.success()
            toastManager.show(.itemShared(itemName))
        case .donate:
            PSHaptics.shared.success()
            toastManager.show(.itemDonated(itemName))
        case .delete:
            PSHaptics.shared.heavyTap()
            toastManager.show(.itemDeleted(itemName))
        }

        // 4. Heavy I/O deferred off the animation pass — no more freeze
        Task { @MainActor in
            do {
                try modelContext.save()
            } catch {
                PSLogger.general.error("Failed to save after expiry action: \(error.localizedDescription)")
                toastManager.show(.error(String(localized: "Failed to save changes")))
                return
            }

            // Celebrations require modelContext, run after successful save
            switch action {
            case .cook:   celebrationManager.fireFoodSaved(modelContext: modelContext)
            case .share:  celebrationManager.fireShareCompleted(itemName: itemName, modelContext: modelContext)
            case .donate: celebrationManager.fireDonationCompleted(itemName: itemName, modelContext: modelContext)
            case .delete: break
            }

            // Widget data updated on willResignActive in AppTabView — no call needed here.
        }

        PSLogger.general.info("Expiry action '\(String(describing: action))' applied to: \(itemName)")
    }
}

// MARK: - Expiry Action

enum ExpiryAction {
    case cook
    case share
    case donate
    case delete
}

// MARK: - Expiry Alert Card

struct ExpiryAlertCard: View {
    let item: FreshliItem
    let onAction: (ExpiryAction) -> Void

    @State private var pressed = false

    private var urgencyColor: Color {
        switch item.expiryStatus {
        case .expired:       return PSColors.expiredRed
        case .expiringToday: return PSColors.expiredRed.opacity(0.85)
        case .expiringSoon:  return PSColors.warningAmber
        case .fresh:         return PSColors.freshGreen
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Coloured urgency stripe at top
            Rectangle()
                .fill(urgencyColor)
                .frame(height: 3)
                .clipShape(.rect(topLeadingRadius: PSSpacing.radiusXl, topTrailingRadius: PSSpacing.radiusXl))

            VStack(spacing: PSSpacing.lg) {
                // Item info row
                HStack(spacing: PSSpacing.md) {
                    // Category icon
                    ZStack {
                        RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                            .fill(PSColors.categoryColor(for: item.category).opacity(0.12))
                            .frame(width: PSLayout.scaled(48), height: PSLayout.scaled(48))
                        Image(systemName: item.category.icon)
                            .font(.system(size: PSLayout.scaledFont(20), weight: .semibold))
                            .foregroundStyle(PSColors.categoryColor(for: item.category))
                    }

                    VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                        Text(item.name)
                            .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                            .foregroundStyle(PSColors.textPrimary)
                            .lineLimit(1)
                        Text("\(item.quantityDisplay)")
                            .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                    }

                    Spacer()

                    // Expiry badge
                    VStack(alignment: .trailing, spacing: PSSpacing.xxs) {
                        Text(item.expiryDate.expiryDisplayText)
                            .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                            .foregroundStyle(urgencyColor)
                        Text(item.expiryStatus.displayName)
                            .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                            .foregroundStyle(urgencyColor.opacity(0.75))
                    }
                }

                // Action row
                HStack(spacing: PSSpacing.sm) {
                    ExpiryActionChip(icon: "fork.knife", title: String(localized: "Cook"), color: PSColors.primaryGreen) {
                        onAction(.cook)
                    }
                    ExpiryActionChip(icon: "hand.raised.fill", title: String(localized: "Share"), color: PSColors.infoBlue) {
                        onAction(.share)
                    }
                    ExpiryActionChip(icon: "heart.fill", title: String(localized: "Donate"), color: PSColors.accentTeal) {
                        onAction(.donate)
                    }
                    Spacer()
                    // Trash — smaller, destructive
                    Button {
                        onAction(.delete)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                            .foregroundStyle(PSColors.textTertiary)
                            .frame(width: PSLayout.scaled(34), height: PSLayout.scaled(34))
                            .background(PSColors.backgroundSecondary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(PSSpacing.cardPadding)
        }
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(urgencyColor.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: urgencyColor.opacity(0.08), radius: 12, x: 0, y: 4)
        .elevation(.z1)
    }
}

// MARK: - Expiry Action Chip

struct ExpiryActionChip: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PSSpacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, PSSpacing.md)
            .padding(.vertical, PSSpacing.sm)
            .foregroundStyle(color)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Backward Compat (ActionChip was used elsewhere)
typealias ActionChip = ExpiryActionChip

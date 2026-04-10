import SwiftUI
import SwiftData

struct RescueMissionDetailView: View {
    let mission: UsageMission

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?

    @State private var completedSteps: Set<Int> = []
    @State private var appeared = false
    @State private var showCompletionCelebration = false
    @State private var showHarvestCelebration = false

    var allStepsCompleted: Bool {
        completedSteps.count == mission.steps.count && !mission.steps.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PSSpacing.xxl) {
                heroSection
                metadataSection
                itemsYouHaveSection
                whatYouNeedSection
                stepsSection
            }
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle(mission.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Close")) { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: PSSpacing.md) {
                if allStepsCompleted {
                    markAsDoneButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(PSSpacing.lg)
            .background(PSColors.backgroundPrimary)
            .border(Color.black.opacity(0.05), width: 1)
        }
        .harvestCelebration(isActive: $showHarvestCelebration, intensity: .celebration)
        .onAppear {
            withAnimation(PSMotion.springGentle.delay(0.1)) { appeared = true }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            HStack(spacing: PSSpacing.lg) {
                VStack(alignment: .leading, spacing: PSSpacing.md) {
                    Text(mission.title)
                        .font(PSTypography.title1)
                        .foregroundStyle(PSColors.textPrimary)
                        .lineLimit(3)

                    Text(mission.description)
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()

                urgencyBadge
            }

            HStack(spacing: PSSpacing.md) {
                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: PSLayout.scaledFont(14)))
                    Text(String(localized: "\(mission.estimatedMinutes) minutes"))
                        .font(PSTypography.subheadline)
                }
                .foregroundStyle(PSColors.textSecondary)

                Spacer()

                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: mission.difficulty.icon)
                        .font(.system(size: PSLayout.scaledFont(14)))
                    Text(mission.difficulty.displayName)
                        .font(PSTypography.subheadline)
                }
                .foregroundStyle(PSColors.textSecondary)
            }
        }
        .padding(PSSpacing.cardPadding)
        .cardStyle()
        .screenPadding()
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        HStack(spacing: PSSpacing.md) {
            metadataChip(
                icon: "checkmark.circle.fill",
                value: String(mission.freshliItems.count),
                label: String(localized: "Items to Use")
            )

            metadataChip(
                icon: "exclamationmark.circle.fill",
                value: mission.urgencyLevel.displayName,
                label: String(localized: "Urgency")
            )

            metadataChip(
                icon: "list.clipboard.fill",
                value: String(mission.steps.count),
                label: String(localized: "Steps")
            )
        }
        .screenPadding()
    }

    // MARK: - Items You Have Section

    private var itemsYouHaveSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            PSSectionHeader(
                title: String(localized: "Ingredients You Have"),
                subtitle: "\(mission.freshliItems.count) item\(mission.freshliItems.count > 1 ? "s" : "")"
            )
            .screenPadding()

            VStack(spacing: PSSpacing.sm) {
                ForEach(Array(mission.freshliItems.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: PSSpacing.md) {
                        Text(item.category.emoji)
                            .font(.system(size: PSLayout.scaledFont(20)))

                        VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                            Text(item.name)
                                .font(PSTypography.body)
                                .foregroundStyle(PSColors.textPrimary)

                            Text(item.quantityDisplay)
                                .font(PSTypography.caption1)
                                .foregroundStyle(PSColors.textSecondary)
                        }

                        Spacer()

                        PSBadge(
                            text: item.expiryStatus.displayName,
                            color: expiryStatusColor(item.expiryStatus),
                            style: .subtle
                        )
                    }
                    .padding(.vertical, PSSpacing.sm)

                    if index < mission.freshliItems.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(PSSpacing.cardPadding)
            .cardStyle()
            .screenPadding()
        }
    }

    // MARK: - What You Need Section

    private var whatYouNeedSection: some View {
        Group {
            if !mission.additionalItems.isEmpty {
                VStack(alignment: .leading, spacing: PSSpacing.md) {
                    PSSectionHeader(
                        title: String(localized: "What You'll Need"),
                        subtitle: "\(mission.additionalItems.count) item\(mission.additionalItems.count > 1 ? "s" : "")"
                    )
                    .screenPadding()

                    VStack(spacing: PSSpacing.sm) {
                        ForEach(Array(mission.additionalItems.enumerated()), id: \.offset) { index, item in
                            HStack(spacing: PSSpacing.md) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: PSLayout.scaledFont(18)))
                                    .foregroundStyle(PSColors.accentTeal)

                                Text(item)
                                    .font(PSTypography.body)
                                    .foregroundStyle(PSColors.textPrimary)

                                Spacer()

                                Image(systemName: "checkbox.unchecked")
                                    .font(.system(size: PSLayout.scaledFont(16)))
                                    .foregroundStyle(PSColors.textTertiary)
                            }
                            .padding(.vertical, PSSpacing.sm)

                            if index < mission.additionalItems.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(PSSpacing.cardPadding)
                    .cardStyle()
                    .screenPadding()
                }
            }
        }
    }

    // MARK: - Steps Section

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            PSSectionHeader(
                title: String(localized: "Steps"),
                subtitle: "\(mission.steps.count) step\(mission.steps.count > 1 ? "s" : "")"
            )
            .screenPadding()

            VStack(spacing: PSSpacing.md) {
                ForEach(Array(mission.steps.enumerated()), id: \.offset) { index, step in
                    Button {
                        PSHaptics.shared.lightTap()
                        withAnimation(PSMotion.springBouncy) {
                            if completedSteps.contains(index) {
                                completedSteps.remove(index)
                            } else {
                                completedSteps.insert(index)
                                if allStepsCompleted {
                                    PSHaptics.shared.celebrate()
                                }
                            }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: PSSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(completedSteps.contains(index) ? PSColors.primaryGreen : PSColors.primaryGreen.opacity(0.12))

                                if completedSteps.contains(index) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                                        .foregroundStyle(PSColors.textOnPrimary)
                                        .scaleEffect(1.2)
                                } else {
                                    Text("\(index + 1)")
                                        .font(PSTypography.caption1Medium)
                                        .foregroundStyle(PSColors.primaryGreen)
                                }
                            }
                            .frame(width: PSLayout.scaled(28), height: PSLayout.scaled(28))

                            Text(step)
                                .font(PSTypography.body)
                                .foregroundStyle(completedSteps.contains(index) ? PSColors.textTertiary : PSColors.textPrimary)
                                .strikethrough(completedSteps.contains(index))
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.vertical, PSSpacing.sm)
                        .padding(.horizontal, PSSpacing.md)
                        .background(completedSteps.contains(index) ? PSColors.primaryGreen.opacity(0.05) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .staggeredAppearance(index: index)
                }
            }
            .padding(PSSpacing.cardPadding)
            .cardStyle()
            .screenPadding()
        }
        .padding(.bottom, PSSpacing.xxxl)
    }

    // MARK: - Mark as Done Button

    private var markAsDoneButton: some View {
        PSButton(
            title: String(localized: "Mission Complete!"),
            style: .primary,
            size: .large,
            action: completeAndMarkConsumed
        )
    }

    // MARK: - Helper Views

    private var urgencyBadge: some View {
        PSBadge(
            text: mission.urgencyLevel.displayName,
            color: urgencyBadgeColor(mission.urgencyLevel),
            style: .filled
        )
    }

    private func metadataChip(icon: String, value: String, label: String) -> some View {
        VStack(spacing: PSSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                .foregroundStyle(PSColors.primaryGreen)
            Text(value)
                .font(PSTypography.calloutMedium)
                .foregroundStyle(PSColors.textPrimary)
            Text(label)
                .font(PSTypography.caption2)
                .foregroundStyle(PSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.md)
        .background(PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
    }

    // MARK: - Actions

    @MainActor
    private func completeAndMarkConsumed() {
        let itemIds = Set(mission.freshliItems.map { $0.id })

        // Trigger haptic harvest celebration for mission completion
        HapticHarvestService.shared.streakMilestone()
        showHarvestCelebration = true

        // Fetch items and mark as consumed
        for item in mission.freshliItems {
            item.isConsumed = true
        }

        do {
            try modelContext.save()
            celebrationManager?.fireFoodSaved(modelContext: modelContext)

            // Dismiss after celebration
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                dismiss()
            }
        } catch {
            PSLogger.recipe.error("Failed to mark items as consumed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func urgencyBadgeColor(_ urgency: UrgencyLevel) -> Color {
        switch urgency {
        case .critical: return PSColors.expiredRed
        case .urgent: return PSColors.warningAmber
        case .moderate: return PSColors.accentTeal
        }
    }

    private func expiryStatusColor(_ status: ExpiryStatus) -> Color {
        switch status {
        case .fresh: return PSColors.freshGreen
        case .expiringSoon: return PSColors.warningAmber
        case .expiringToday: return PSColors.warningAmber
        case .expired: return PSColors.expiredRed
        }
    }
}

// MARK: - Preview

#Preview {
    let previewContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: FreshliItem.self, configurations: config)

        let tomorrowDate = Calendar.current.date(byAdding: .hour, value: 12, to: Date())!
        let spinach = FreshliItem(
            name: "Fresh Spinach",
            category: .vegetables,
            storageLocation: .fridge,
            quantity: 1,
            unit: .pieces,
            expiryDate: tomorrowDate
        )

        let carrots = FreshliItem(
            name: "Carrots",
            category: .vegetables,
            storageLocation: .pantry,
            quantity: 2,
            unit: .pieces,
            expiryDate: tomorrowDate
        )

        let garlic = FreshliItem(
            name: "Garlic",
            category: .vegetables,
            storageLocation: .pantry,
            quantity: 3,
            unit: .pieces,
            expiryDate: tomorrowDate
        )

        container.mainContext.insert(spinach)
        container.mainContext.insert(carrots)
        container.mainContext.insert(garlic)

        return container
    }()

    let sampleMission = UsageMission(
        id: UUID(),
        title: "Veggie Stir-Fry: Quick Dinner!",
        description: "Transform your vegetables into a speedy, delicious stir-fry.",
        urgencyLevel: .urgent,
        freshliItems: [],
        estimatedMinutes: 25,
        difficulty: .easy,
        steps: [
            "Chop vegetables into uniform pieces",
            "Heat oil in wok or pan over high heat",
            "Stir-fry vegetables for 5-7 minutes",
            "Season with soy sauce and serve over rice"
        ],
        additionalItems: ["Rice", "Soy sauce", "Vegetable oil"]
    )

    NavigationStack {
        RescueMissionDetailView(mission: sampleMission)
    }
    .modelContainer(previewContainer)
    .environment(CelebrationManager())
}

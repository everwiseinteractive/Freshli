import SwiftUI
import SwiftData

struct RescueChefView: View {
    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var pantryItems: [FreshliItem]

    @State private var rescueService = RescueChefService.shared
    @State private var selectedMission: UsageMission?
    @State private var activeFilter: UrgencyLevel = .critical
    @State private var isRefreshing = false
    @State private var appeared = false

    private var filteredMissions: [UsageMission] {
        if activeFilter == .critical {
            return rescueService.missions
        }
        return rescueService.missions.filter { $0.urgencyLevel == activeFilter }
    }

    private var hasAtRiskItems: Bool {
        rescueService.atRiskItemsCount > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            rescueHeader

            if hasAtRiskItems {
                ScrollView {
                    VStack(alignment: .leading, spacing: PSSpacing.lg) {
                        rescueDashboard
                        urgencyFilterChips
                        missionsList
                    }
                    .padding(.vertical, PSSpacing.lg)
                }
                .refreshable {
                    await refreshMissions()
                }
            } else {
                ScrollView {
                    PSEmptyState(
                        icon: "checkmark.circle.fill",
                        title: String(localized: "Your Pantry is Looking Great!"),
                        message: String(localized: "No items need rescuing right now. Add more items to your pantry to get started."),
                        actionTitle: nil,
                        action: nil
                    )
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                    .padding(.top, 60)
                }
            }
        }
        .background(PSColors.backgroundSecondary)
        .navigationBarHidden(true)
        .sheet(item: $selectedMission) { mission in
            NavigationStack {
                RescueMissionDetailView(mission: mission)
            }
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            withAnimation(PSMotion.springGentle.delay(0.1)) { appeared = true }
            rescueService.generateMissions(for: pantryItems)
        }
        .onChange(of: pantryItems.count) { _, _ in
            rescueService.generateMissions(for: pantryItems)
        }
    }

    // MARK: - Header

    private var rescueHeader: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text(String(localized: "Rescue Chef"))
                .font(.system(size: PSLayout.scaledFont(30), weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(PSColors.textPrimary)
                .adaptiveHPadding()

            if hasAtRiskItems {
                Text(String(localized: "Use items before they expire"))
                    .font(.system(size: PSLayout.scaledFont(14)))
                    .foregroundStyle(PSColors.textSecondary)
                    .adaptiveHPadding()
            }
        }
        .padding(.top, PSSpacing.md)
        .padding(.bottom, PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    // MARK: - Rescue Dashboard Hero

    private var rescueDashboard: some View {
        VStack(spacing: PSSpacing.lg) {
            HStack(spacing: PSSpacing.lg) {
                // At-Risk Items Count
                dashboardCard(
                    icon: "exclamationmark.circle.fill",
                    iconColor: PSColors.expiredRed,
                    number: String(rescueService.atRiskItemsCount),
                    label: String(localized: "At Risk"),
                    appeared: appeared
                )

                // Rescue Score
                dashboardCard(
                    icon: "checkmark.circle.fill",
                    iconColor: PSColors.primaryGreen,
                    number: String(format: "%.0f%%", rescueService.rescueScore * 100),
                    label: String(localized: "Rescue Score"),
                    appeared: appeared
                )

                // Time Remaining
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: PSLayout.scaledFont(20)))
                            .foregroundStyle(PSColors.warningAmber)
                        Text(rescueService.mostUrgentTimeRemaining)
                            .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                            .foregroundStyle(PSColors.textPrimary)
                    }
                    Text(String(localized: "Most Urgent"))
                        .font(.system(size: PSLayout.scaledFont(12)))
                        .foregroundStyle(PSColors.textSecondary)
                }
                .padding(.vertical, PSSpacing.md)
                .padding(.horizontal, PSSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PSColors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                        .strokeBorder(PSColors.borderLight, lineWidth: 1)
                )
                .scaleEffect(appeared ? 1 : 0.95)
                .opacity(appeared ? 1 : 0)
            }
        }
        .adaptiveHPadding()
    }

    // MARK: - Urgency Filter Chips

    private var urgencyFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PSSpacing.md) {
                ForEach([UrgencyLevel.critical, .urgent, .moderate], id: \.self) { urgency in
                    Button {
                        PSHaptics.shared.selection()
                        withAnimation(PSMotion.springQuick) { activeFilter = urgency }
                    } label: {
                        HStack(spacing: PSSpacing.xs) {
                            Image(systemName: urgency.icon)
                                .font(.system(size: PSLayout.scaledFont(14)))
                            Text(urgency.displayName)
                                .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                                .tracking(-0.2)
                        }
                        .padding(.horizontal, PSSpacing.lg)
                        .padding(.vertical, PSLayout.scaled(10))
                        .foregroundStyle(activeFilter == urgency ? .white : PSColors.textSecondary)
                        .background(activeFilter == urgency ? PSColors.textPrimary : PSColors.backgroundSecondary)
                        .clipShape(Capsule())
                        .shadow(color: activeFilter == urgency ? .black.opacity(0.1) : .clear, radius: 8, y: 4)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
        }
    }

    // MARK: - Missions List

    private var missionsList: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            if filteredMissions.isEmpty {
                PSEmptyState(
                    icon: "sparkles",
                    title: String(localized: "No Missions"),
                    message: String(localized: "No rescue missions available for this urgency level."),
                    actionTitle: nil,
                    action: nil
                )
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                .padding(.top, 20)
            } else {
                Text(String(localized: "Usage Missions"))
                    .font(.system(size: PSLayout.scaledFont(20), weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(PSColors.textPrimary)
                    .adaptiveHPadding()

                LazyVStack(spacing: PSSpacing.lg) {
                    ForEach(Array(filteredMissions.enumerated()), id: \.element.id) { index, mission in
                        missionCard(mission: mission)
                            .staggeredAppearance(index: index)
                    }
                }
                .adaptiveHPadding()
            }
        }
    }

    // MARK: - Mission Card

    private func missionCard(mission: UsageMission) -> some View {
        Button { selectedMission = mission } label: {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                // Title with urgency badge
                HStack(spacing: PSSpacing.md) {
                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text(mission.title)
                            .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                            .foregroundStyle(PSColors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: PSSpacing.md) {
                            // Item emojis
                            Text(mission.itemEmojis)
                                .font(.system(size: PSLayout.scaledFont(14)))

                            // Item count
                            Text(String(localized: "\(mission.freshliItems.count) item\(mission.freshliItems.count > 1 ? "s" : "")"))
                                .font(.system(size: PSLayout.scaledFont(12)))
                                .foregroundStyle(PSColors.textSecondary)
                        }
                    }

                    Spacer()

                    // Urgency badge
                    PSBadge(
                        text: mission.urgencyLevel.displayName,
                        color: urgencyBadgeColor(mission.urgencyLevel),
                        style: .filled
                    )
                }

                Divider()

                // Metadata row
                HStack(spacing: PSSpacing.lg) {
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: "clock")
                            .font(.system(size: PSLayout.scaledFont(14)))
                        Text(String(localized: "\(mission.estimatedMinutes) min"))
                            .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    }
                    .foregroundStyle(PSColors.textSecondary)

                    Spacer()

                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: mission.difficulty.icon)
                            .font(.system(size: PSLayout.scaledFont(14)))
                        Text(mission.difficulty.displayName)
                            .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    }
                    .foregroundStyle(PSColors.textSecondary)

                    Spacer()

                    PSButton(
                        title: String(localized: "Start"),
                        style: .primary,
                        size: .small,
                        action: { selectedMission = mission }
                    )
                }
            }
            .padding(PSSpacing.cardPadding)
        }
        .buttonStyle(PlainButtonStyle())
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func dashboardCard(
        icon: String,
        iconColor: Color,
        number: String,
        label: String,
        appeared: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(20)))
                    .foregroundStyle(iconColor)
                Text(number)
                    .font(.system(size: PSLayout.scaledFont(24), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
            }
            Text(label)
                .font(.system(size: PSLayout.scaledFont(12)))
                .foregroundStyle(PSColors.textSecondary)
        }
        .padding(.vertical, PSSpacing.md)
        .padding(.horizontal, PSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
    }

    private func urgencyBadgeColor(_ urgency: UrgencyLevel) -> Color {
        switch urgency {
        case .critical: return PSColors.expiredRed
        case .urgent: return PSColors.warningAmber
        case .moderate: return PSColors.accentTeal
        }
    }

    @MainActor
    private func refreshMissions() async {
        isRefreshing = true
        rescueService.generateMissions(for: pantryItems)
        try? await Task.sleep(for: .milliseconds(500))
        isRefreshing = false
    }
}

// MARK: - Preview

#Preview {
    let previewContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: FreshliItem.self, configurations: config)

        // Add sample at-risk items
        let tomorrowDate = Calendar.current.date(byAdding: .hour, value: 12, to: Date())!
        let spinach = FreshliItem(
            name: "Fresh Spinach",
            category: .vegetables,
            storageLocation: .fridge,
            quantity: 1,
            unit: .pieces,
            expiryDate: tomorrowDate
        )

        let tomorrowPlus24 = Calendar.current.date(byAdding: .hour, value: 36, to: Date())!
        let carrots = FreshliItem(
            name: "Carrots",
            category: .vegetables,
            storageLocation: .pantry,
            quantity: 2,
            unit: .pieces,
            expiryDate: tomorrowPlus24
        )

        let milk = FreshliItem(
            name: "Milk",
            category: .dairy,
            storageLocation: .fridge,
            quantity: 1,
            unit: .liters,
            expiryDate: tomorrowDate
        )

        container.mainContext.insert(spinach)
        container.mainContext.insert(carrots)
        container.mainContext.insert(milk)

        return container
    }()

    NavigationStack {
        RescueChefView()
    }
    .modelContainer(previewContainer)
}

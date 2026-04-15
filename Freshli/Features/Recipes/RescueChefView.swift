import SwiftUI
import SwiftData

struct RescueChefView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var pantryItems: [FreshliItem]

    @State private var rescueService = RescueChefService.shared
    @State private var aiRescueService = AIRescueService.shared
    @State private var selectedMission: UsageMission?
    @State private var activeFilter: UrgencyLevel = .critical
    @State private var isRefreshing = false
    @State private var appeared = false

    /// True once the user has tapped "Ask Freshli" for this session. Before
    /// that we show a teaser card inviting them to try it; after, we show
    /// the generated missions (or the loading state while they stream in).
    @State private var hasTriggeredAI = false

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
                        if aiRescueService.isAvailable {
                            aiRescueSection
                        }
                        urgencyFilterChips
                        missionsList
                    }
                    .padding(.vertical, PSSpacing.lg)
                }
                .refreshable {
                    PSHaptics.shared.refreshSnap()
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
            .sheetTransition()
        }
        .onAppear {
            withAnimation(PSMotion.springGentle.delay(0.1)) { appeared = true }
            rescueService.generateMissions(for: pantryItems)
            AnalyticsService.shared.track(.rescueChefOpened, properties: .props([
                "at_risk_count": rescueService.atRiskItemsCount,
                "ai_available":  aiRescueService.isAvailable
            ]))
        }
        .onChange(of: pantryItems.count) { _, _ in
            rescueService.generateMissions(for: pantryItems)
        }
    }

    // MARK: - Header

    private var rescueHeader: some View {
        VStack(spacing: 0) {
            // Top bar with back button
            HStack(alignment: .center) {
                Button {
                    PSHaptics.shared.lightTap()
                    dismiss()
                } label: {
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                        Text(String(localized: "Back"))
                            .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                    }
                    .foregroundStyle(PSColors.primaryGreen)
                }

                Spacer()

                Text(String(localized: "Rescue Chef"))
                    .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)

                Spacer()

                // Balance the back button
                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                    Text(String(localized: "Back"))
                        .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                }
                .opacity(0)  // invisible spacer
            }
            .adaptiveHPadding()
            .padding(.top, PSSpacing.md)
            .padding(.bottom, PSSpacing.sm)

            if hasAtRiskItems {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: PSLayout.scaledFont(13)))
                        .foregroundStyle(PSColors.expiredRed)
                    Text(String(localized: "Use \(rescueService.atRiskItemsCount) item\(rescueService.atRiskItemsCount == 1 ? "" : "s") before they expire"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                .adaptiveHPadding()
                .padding(.bottom, PSSpacing.md)
            }
        }
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Text(String(localized: "Most Urgent"))
                        .font(.system(size: PSLayout.scaledFont(12)))
                        .foregroundStyle(PSColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.vertical, PSSpacing.md)
                .padding(.horizontal, PSSpacing.sm)
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

    // MARK: - Ask Freshli AI Section (iOS 26 FoundationModels)
    //
    // On-device Apple Intelligence generates bespoke rescue recipes for the
    // user's actual at-risk pantry items. Before the user taps "Ask Freshli",
    // we show a teaser card explaining what the button does. After the tap
    // we render the generated missions inline above the rule-based list,
    // with a loading state while the model streams its response.

    private var aiRescueSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PSColors.primaryGreen, PSColors.accentTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeat(.periodic(delay: 3.0)))

                Text(String(localized: "Ask Freshli"))
                    .font(.system(size: PSLayout.scaledFont(18), weight: .bold, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)

                Spacer()

                if hasTriggeredAI && !aiRescueService.missions.isEmpty {
                    Button {
                        PSHaptics.shared.lightTap()
                        Task { await generateAIMissions() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                            .foregroundStyle(PSColors.textSecondary)
                            .padding(8)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel(String(localized: "Regenerate AI rescue recipes"))
                }
            }
            .adaptiveHPadding()

            if !hasTriggeredAI {
                aiTeaserCard
            } else if aiRescueService.isGenerating {
                aiLoadingCard
            } else if let errorMessage = aiRescueService.lastError {
                aiErrorCard(errorMessage)
            } else if !aiRescueService.missions.isEmpty {
                aiMissionsList
            }
        }
    }

    private var aiTeaserCard: some View {
        Button {
            PSHaptics.shared.mediumTap()
            hasTriggeredAI = true
            Task { await generateAIMissions() }
        } label: {
            HStack(alignment: .center, spacing: PSSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Rescue Chef, powered by Apple Intelligence"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .bold, design: .rounded))
                        .foregroundStyle(PSColors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(String(localized: "Get 3 bespoke recipes for your exact pantry — on-device, private, no network needed."))
                        .font(.system(size: PSLayout.scaledFont(12)))
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: PSLayout.scaledFont(24), weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PSColors.primaryGreen, PSColors.accentTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(PSSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        PSColors.primaryGreen.opacity(0.08),
                        PSColors.accentTeal.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [PSColors.primaryGreen.opacity(0.4), PSColors.accentTeal.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
        .adaptiveHPadding()
        .accessibilityHint(String(localized: "Generates three rescue recipes using on-device Apple Intelligence"))
    }

    private var aiLoadingCard: some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: PSLayout.scaledFont(22)))
                .foregroundStyle(PSColors.primaryGreen)
                .symbolEffect(.variableColor.iterative, options: .repeating)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Cooking up ideas…"))
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text(String(localized: "Apple Intelligence is reviewing your pantry"))
                    .font(.system(size: PSLayout.scaledFont(12)))
                    .foregroundStyle(PSColors.textSecondary)
            }

            Spacer()
        }
        .padding(PSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
        .adaptiveHPadding()
    }

    private func aiErrorCard(_ message: String) -> some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: PSLayout.scaledFont(20)))
                .foregroundStyle(PSColors.warningAmber)

            Text(message)
                .font(.system(size: PSLayout.scaledFont(13)))
                .foregroundStyle(PSColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button {
                PSHaptics.shared.lightTap()
                Task { await generateAIMissions() }
            } label: {
                Text(String(localized: "Retry"))
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(PSColors.primaryGreen)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(PSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(PSColors.warningAmber.opacity(0.3), lineWidth: 1)
        )
        .adaptiveHPadding()
    }

    private var aiMissionsList: some View {
        LazyVStack(spacing: PSSpacing.md) {
            ForEach(Array(aiRescueService.missions.enumerated()), id: \.element.id) { index, mission in
                missionCard(mission: mission)
                    .overlay(alignment: .topTrailing) {
                        // Subtle sparkle marker so users know this recipe
                        // came from Apple Intelligence, not the rule engine.
                        Image(systemName: "sparkles")
                            .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [PSColors.primaryGreen, PSColors.accentTeal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(10)
                    }
                    .staggeredAppearance(index: index)
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
                            .minimumScaleFactor(0.85)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(label)
                .font(.system(size: PSLayout.scaledFont(12)))
                .foregroundStyle(PSColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, PSSpacing.md)
        .padding(.horizontal, PSSpacing.sm)
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
        // Refresh AI missions too if the user has already opted in.
        if hasTriggeredAI {
            await generateAIMissions()
        } else {
            try? await Task.sleep(for: .milliseconds(500))
        }
        isRefreshing = false
    }

    @MainActor
    private func generateAIMissions() async {
        // Filter to the at-risk subset — the rule-based service already
        // computes this but doesn't expose it, so we reproduce the
        // 48-hour window here to hand a clean list to the model.
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .hour, value: 48, to: Date()) ?? Date()
        let atRiskItems = pantryItems.filter { $0.expiryDate <= cutoff && !$0.isConsumed }
        await aiRescueService.generateMissions(for: atRiskItems)
    }
}

// MARK: - Preview

#Preview {
    let previewContainer: ModelContainer? = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: FreshliItem.self, configurations: config) else { return nil }

        // Add sample at-risk items
        let tomorrowDate = Calendar.current.date(byAdding: .hour, value: 12, to: Date()) ?? Date()
        let spinach = FreshliItem(
            name: "Fresh Spinach",
            category: .vegetables,
            storageLocation: .fridge,
            quantity: 1,
            unit: .pieces,
            expiryDate: tomorrowDate
        )

        let tomorrowPlus24 = Calendar.current.date(byAdding: .hour, value: 36, to: Date()) ?? Date()
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

    if let previewContainer {
        NavigationStack {
            RescueChefView()
        }
        .modelContainer(previewContainer)
    } else {
        Text("Preview unavailable")
    }
}

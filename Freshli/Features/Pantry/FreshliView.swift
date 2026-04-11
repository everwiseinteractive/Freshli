import SwiftUI
import SwiftData
import os

struct FreshliView: View {
    @Binding var showAddItem: Bool

    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var allItems: [FreshliItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncService.self) private var syncService
    @Environment(PSToastManager.self) private var toastManager
    @State private var searchText = ""
    @State private var selectedCategory: FoodCategory?
    @State private var selectedItem: FreshliItem?
    @State private var showFilterSheet = false
    @State private var showHarvestCelebration = false
    @State private var harvestIntensity: SparkleIntensity = .standard
    @State private var showFridgeScanner = false
    @State private var autoListTarget: FreshliItem?
    @State private var binLogTarget: FreshliItem?
    @AppStorage("autoListDismissedIds") private var autoListDismissedIdsRaw: String = ""

    private var autoListDismissedIds: Set<String> {
        Set(autoListDismissedIdsRaw.split(separator: ",").map(String.init))
    }

    /// Items expiring within 24 h that haven't been shared/consumed and aren't dismissed.
    private var itemsNeedingAutoPrompt: [FreshliItem] {
        let deadline = Date().addingTimeInterval(86_400)
        return allItems.filter {
            $0.expiryDate <= deadline &&
            !$0.isShared &&
            !autoListDismissedIds.contains($0.id.uuidString)
        }
    }

    private func dismissAutoPrompt(_ item: FreshliItem) {
        var ids = autoListDismissedIds
        ids.insert(item.id.uuidString)
        autoListDismissedIdsRaw = ids.joined(separator: ",")
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logger = Logger(subsystem: "com.freshli.app", category: "FreshliView")

    private var filteredItems: [FreshliItem] {
        var items = allItems
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if let selectedCategory {
            items = items.filter { $0.category == selectedCategory }
        }
        return items
    }

    // Status counts for the health strip
    private var expiredCount: Int   { allItems.filter { $0.expiryStatus == .expired }.count }
    private var urgentCount: Int    { allItems.filter { $0.expiryStatus == .expiringToday || $0.expiryStatus == .expiringSoon }.count }
    private var freshCount: Int     { allItems.filter { $0.expiryStatus == .fresh }.count }

    // MARK: - Actions

    private func consumeItem(_ item: FreshliItem) {
        HapticHarvestService.shared.harvestCelebration()
        harvestIntensity = .standard
        showHarvestCelebration = true
        let itemName = item.name

        // Mutate state and animate the removal — keep withAnimation lightweight.
        item.isConsumed = true
        withAnimation(FLMotion.adaptive(PSMotion.springDefault, reduceMotion: reduceMotion)) { }

        // Heavy I/O runs AFTER the animation pass in a deferred task.
        // WidgetDataService is intentionally omitted here — AppTabView already
        // calls it on willResignActive, avoiding redundant main-thread work.
        Task { @MainActor in
            do {
                try modelContext.save()
                // Record into the collective wave BEFORE showing the toast so
                // the rotating impact phrase picks up the fresh total count.
                CollectiveImpactService.shared.recordRescue(itemName: itemName)
                toastManager.show(.itemConsumed(itemName))
                let streakResult = RescueStreakService.shared.recordActivity()
                if let milestone = streakResult.hitMilestone {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(1800))
                        toastManager.show(.success(FreshliBrand.streakMilestone(days: milestone)))
                    }
                }
                celebrationManager.fireFoodSaved(modelContext: modelContext)
                RatingService.shared.recordJoyMoment()
                if let userId = authManager.currentUserId {
                    await syncService.pushFreshliItem(item, userId: userId)
                    await syncService.recordImpactEvent(userId: userId, eventType: "consumed", itemName: itemName, moneySaved: 3.50, co2Avoided: 2.5)
                }
            } catch {
                toastManager.show(.error("Something went wrong. Please try again."))
                PSHaptics.shared.warning()
            }
        }
    }

    private func deleteItem(_ item: FreshliItem) {
        PSHaptics.shared.heavyTap()
        // If the item is actively being wasted (still has expiry data) surface the bin log
        // reason picker before destroying it.
        if item.expiryStatus != .fresh && !item.isConsumed && !item.isShared && !item.isDonated {
            binLogTarget = item
            return
        }
        performDelete(item)
    }

    private func performDelete(_ item: FreshliItem) {
        let itemName = item.name
        let itemId = item.id
        // Delete the item object (lightweight — just marks it deleted in the context)
        modelContext.delete(item)
        withAnimation(FLMotion.adaptive(PSMotion.springDefault, reduceMotion: reduceMotion)) { }
        // Defer save and sync off the animation pass
        Task { @MainActor in
            do {
                try modelContext.save()
                toastManager.show(.itemDeleted(itemName))
                if authManager.currentUserId != nil {
                    await syncService.deleteFreshliItem(id: itemId)
                }
            } catch {
                toastManager.show(.error("Something went wrong. Please try again."))
                PSHaptics.shared.warning()
            }
        }
    }

    private func shareItem(_ item: FreshliItem) {
        let itemName = item.name
        item.isShared = true
        withAnimation(FLMotion.adaptive(PSMotion.springDefault, reduceMotion: reduceMotion)) { }
        Task { @MainActor in
            do {
                try modelContext.save()
                toastManager.show(.itemShared(itemName))
                celebrationManager.fireShareCompleted(itemName: itemName, modelContext: modelContext)
                // WidgetDataService deferred to willResignActive in AppTabView
                if let userId = authManager.currentUserId {
                    Task {
                        await syncService.pushFreshliItem(item, userId: userId)
                        await syncService.recordImpactEvent(userId: userId, eventType: "shared", itemName: itemName, co2Avoided: 2.5)
                    }
                }
            } catch {
                toastManager.show(.error("Something went wrong. Please try again."))
                PSHaptics.shared.warning()
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                stickyHeader
                itemList
            }
            .background(PSColors.backgroundSecondary)
            .harvestCelebration(isActive: $showHarvestCelebration, intensity: harvestIntensity)

            // FAB — padding is from the layout edge (which safeAreaInset already places
            // above the tab bar), so just a comfortable gap from that edge.
            Button { showAddItem = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: PSLayout.scaledFont(28), weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: PSLayout.fabSize, height: PSLayout.fabSize)
                    .background(
                        LinearGradient(
                            colors: [PSColors.primaryGreen, PSColors.primaryGreenDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                    .shadow(color: PSColors.primaryGreen.opacity(0.45), radius: 20, y: 8)
                    .shadow(color: PSColors.primaryGreen.opacity(0.2), radius: 40, y: 16)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(String(localized: "Add Item"))
            .accessibilityHint(String(localized: "Double tap to add a new item to your pantry"))
            .padding(.trailing, PSLayout.adaptiveHorizontalPadding)
            .padding(.bottom, PSSpacing.xl)   // gap above tab bar edge (safeAreaInset handles boundary)
        }
        .navigationBarHidden(true)
        .onAppear {
            logger.info("FreshliView appeared — \(allItems.count) items")
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                FreshliDetailView(item: item)
                    .sheetTransition()
            }
            .presentationDragIndicator(.visible)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showFilterSheet) {
            NavigationStack {
                FreshliFilterSheet(
                    selectedCategory: $selectedCategory,
                    sortByExpiry: .constant(true)
                )
                .sheetTransition()
            }
            .presentationDragIndicator(.visible)
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showFridgeScanner) {
            FoodScannerView()
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
        .sheet(item: $autoListTarget) { item in
            NavigationStack {
                CommunityCreateListingView(
                    onComplete: { success in
                        if success { dismissAutoPrompt(item) }
                        autoListTarget = nil
                    },
                    prefillItemName: item.name
                )
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $binLogTarget) { item in
            BinLogReasonSheet(item: item) { reason in
                if reason != nil {
                    toastManager.show(.success(String(localized: "Logged to Bin Log — we'll use this to stop the waste pattern.")))
                }
                performDelete(item)
                binLogTarget = nil
            }
        }
    }

    // MARK: - Header

    private var stickyHeader: some View {
        VStack(spacing: PSSpacing.lg) {
            // Title row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "My Pantry"))
                        .font(.system(size: PSLayout.scaledFont(30), weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(PSColors.textPrimary)
                    if !allItems.isEmpty {
                        Text(String(localized: "\(allItems.count) items"))
                            .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
                Spacer()
                HStack(spacing: PSSpacing.sm) {
                    NavigationLink(destination: DepletionInsightsView()) {
                        PSIconButton(icon: "chart.bar.fill", size: PSLayout.scaled(36), tint: PSColors.primaryGreen) {}
                    }
                    PSIconButton(icon: "line.3.horizontal.decrease", size: PSLayout.scaled(36), tint: selectedCategory != nil ? PSColors.primaryGreen : PSColors.textSecondary) {
                        showFilterSheet = true
                    }
                    .scaleEffect(selectedCategory != nil ? 1.08 : 1.0)
                }
            }

            // Pantry health strip — only visible when items exist
            if !allItems.isEmpty {
                pantryHealthStrip
            }

            // Quick actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.md) {
                    Button {
                        PSHaptics.shared.lightTap()
                        showFridgeScanner = true
                    } label: {
                        quickActionChip(label: "Scan Fridge", icon: "camera.fill", color: Color(hex: 0x8B5CF6))
                    }
                    NavigationLink(destination: SmartAddView()) {
                        quickActionChip(label: "Smart Add", icon: "camera.viewfinder", color: PSColors.primaryGreen)
                    }
                    NavigationLink(destination: ReceiptScannerView()) {
                        quickActionChip(label: "Receipt", icon: "doc.text.viewfinder", color: PSColors.accentTeal)
                    }
                    NavigationLink(destination: ReplenishView()) {
                        quickActionChip(label: "Replenish", icon: "cart.fill", color: PSColors.secondaryAmber)
                    }
                }
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            }
            .scrollClipDisabled()

            // Search bar
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(PSColors.textTertiary)
                    .padding(.leading, PSSpacing.lg)
                TextField(String(localized: "Search ingredients..."), text: $searchText)
                    .font(.system(size: PSLayout.scaledFont(16)))
                    .foregroundStyle(PSColors.textPrimary)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PSColors.textTertiary)
                            .padding(.trailing, PSSpacing.md)
                    }
                }
            }
            .frame(height: PSLayout.searchBarHeight)
            .background(PSColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))

            // Category chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.md) {
                    categoryChip(title: String(localized: "All"), icon: nil, isActive: selectedCategory == nil) {
                        PSHaptics.shared.selection()
                        withAnimation(FLMotion.adaptive(PSMotion.springQuick, reduceMotion: reduceMotion)) { selectedCategory = nil }
                    }
                    ForEach([FoodCategory.fruits, .vegetables, .dairy, .meat, .grains, .bakery], id: \.self) { cat in
                        categoryChip(title: cat.displayName, icon: cat.icon, isActive: selectedCategory == cat) {
                            PSHaptics.shared.selection()
                            withAnimation(FLMotion.adaptive(PSMotion.springQuick, reduceMotion: reduceMotion)) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                }
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            }
            .scrollClipDisabled()
        }
        .adaptiveHPadding()
        .padding(.top, PSSpacing.md)
        .padding(.bottom, PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    // Horizontal freshness bar showing expired/urgent/fresh breakdown
    private var pantryHealthStrip: some View {
        HStack(spacing: PSSpacing.md) {
            if expiredCount > 0 {
                healthPill(count: expiredCount, label: "Expired", color: PSColors.expiredRed)
            }
            if urgentCount > 0 {
                healthPill(count: urgentCount, label: "Soon", color: PSColors.secondaryAmber)
            }
            if freshCount > 0 {
                healthPill(count: freshCount, label: "Fresh", color: PSColors.primaryGreen)
            }
            Spacer()
            // Freshness bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if expiredCount > 0 {
                        Capsule().fill(PSColors.expiredRed)
                            .frame(width: geo.size.width * CGFloat(expiredCount) / CGFloat(allItems.count))
                    }
                    if urgentCount > 0 {
                        Capsule().fill(PSColors.secondaryAmber)
                            .frame(width: geo.size.width * CGFloat(urgentCount) / CGFloat(allItems.count))
                    }
                    if freshCount > 0 {
                        Capsule().fill(PSColors.primaryGreen)
                            .frame(width: geo.size.width * CGFloat(freshCount) / CGFloat(allItems.count))
                    }
                }
            }
            .frame(width: PSLayout.scaled(80), height: 6)
            .clipShape(Capsule())
        }
        .padding(.horizontal, PSSpacing.md)
        .padding(.vertical, PSSpacing.sm)
        .background(PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
    }

    private func healthPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private func quickActionChip(label: String, icon: String, color: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, PSSpacing.md)
            .padding(.vertical, PSSpacing.sm)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func categoryChip(title: String, icon: String?, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: PSSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: PSLayout.scaledFont(14), weight: isActive ? .semibold : .regular))
                }
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
            }
            .padding(.horizontal, PSSpacing.lg)
            .padding(.vertical, PSLayout.scaled(10))
            .foregroundStyle(isActive ? .white : PSColors.textSecondary)
            .background(isActive ? PSColors.headerGreen : PSColors.surfaceCard)
            .clipShape(Capsule())
            .overlay {
                if !isActive {
                    Capsule().strokeBorder(PSColors.border, lineWidth: 1)
                }
            }
            .shadow(color: isActive ? PSColors.headerGreen.opacity(0.25) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Item List

    private var itemList: some View {
        Group {
            if filteredItems.isEmpty {
                ScrollView {
                    PSEmptyState(
                        icon: searchText.isEmpty ? "refrigerator" : "magnifyingglass",
                        title: searchText.isEmpty ? String(localized: "Your pantry is empty") : String(localized: "No matching ingredients"),
                        message: searchText.isEmpty
                            ? String(localized: "Start adding ingredients to keep track of what you have and get recipe suggestions.")
                            : String(localized: "Try adjusting your search or category filter."),
                        actionTitle: searchText.isEmpty ? String(localized: "Add Ingredient") : nil,
                        action: searchText.isEmpty ? { showAddItem = true } : nil
                    )
                    .adaptiveCardPadding()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        // Auto-list prompts — shown for items expiring in < 24 h
                        ForEach(itemsNeedingAutoPrompt) { item in
                            autoSharePromptCard(item)
                                .transition(.asymmetric(
                                    insertion: .push(from: .top),
                                    removal: .push(from: .bottom)
                                ))
                        }

                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            freshliItemCard(item: item)
                                .staggeredAppearance(index: index)
                                .onTapGesture {
                                    PSHaptics.shared.lightTap()
                                    selectedItem = item
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { deleteItem(item) } label: {
                                        Label(String(localized: "Delete"), systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button { consumeItem(item) } label: {
                                        Label(String(localized: "Consume"), systemImage: "checkmark.circle")
                                    }
                                    .tint(PSColors.primaryGreen)
                                }
                                .contextMenu {
                                    Button(String(localized: "Mark as Consumed"), systemImage: "checkmark.circle") { consumeItem(item) }
                                    Button(String(localized: "Share"), systemImage: "hand.raised") { shareItem(item) }
                                    Divider()
                                    Button(String(localized: "Delete"), systemImage: "trash", role: .destructive) { deleteItem(item) }
                                }
                        }
                    }
                    .adaptiveHPadding()
                    .padding(.top, PSSpacing.lg)
                    .listChangeAnimation(filteredItems.map(\.id))
                }
                // Clears the FAB + floating tab bar in one go (~200pt total).
                .contentMargins(.bottom, PSLayout.fabSize + PSLayout.scaled(120), for: .scrollContent)
                .refreshable {
                    PSHaptics.shared.refreshSnap()
                    WidgetDataService.updateWidgetData(modelContext: modelContext)
                }
            }
        }
    }

    // MARK: - Auto-Share Prompt Card

    private func autoSharePromptCard(_ item: FreshliItem) -> some View {
        HStack(spacing: PSSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(PSColors.secondaryAmber.opacity(0.15))
                    .frame(width: PSLayout.scaled(44), height: PSLayout.scaled(44))
                Text(item.category.emoji)
                    .font(.system(size: PSLayout.scaledFont(22)))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("You likely won't eat this \(item.name)")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(1)
                Text("Tap to list it free for neighbours 🏘️")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.secondaryAmber)
            }

            Spacer()

            // Actions
            HStack(spacing: PSSpacing.xs) {
                Button {
                    PSHaptics.shared.lightTap()
                    withAnimation { dismissAutoPrompt(item) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(PSColors.textTertiary)
                        .frame(width: PSLayout.scaled(28), height: PSLayout.scaled(28))
                        .background(PSColors.backgroundSecondary)
                        .clipShape(Circle())
                }

                Button {
                    PSHaptics.shared.lightTap()
                    autoListTarget = item
                } label: {
                    Text("List")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, PSSpacing.md)
                        .padding(.vertical, PSSpacing.xs)
                        .background(PSColors.secondaryAmber)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, PSSpacing.lg)
        .padding(.vertical, PSSpacing.md)
        .background(PSColors.secondaryAmber.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(PSColors.secondaryAmber.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Item Card

    private func freshliItemCard(item: FreshliItem) -> some View {
        HStack(spacing: 0) {
            // Colored left accent strip — color encodes urgency at a glance
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(PSColors.expiryColor(for: item.expiryStatus))
                .frame(width: 3)
                .padding(.vertical, 10)
                .padding(.leading, 12)

            HStack(spacing: PSSpacing.lg) {
                // Real food photograph — matched by item name
                ZStack {
                    FoodItemImage(
                        name: item.name,
                        category: item.category,
                        size: PSLayout.categoryIconSize,
                        cornerRadius: PSSpacing.radiusLg
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                            .strokeBorder(PSColors.categoryColor(for: item.category).opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                    // Urgency dot
                    if item.expiryStatus != .fresh {
                        Circle()
                            .fill(PSColors.expiryColor(for: item.expiryStatus))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                            .offset(x: PSLayout.scaled(22), y: PSLayout.scaled(-22))
                    }
                }

                // Name (full width) + badges row below
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: PSSpacing.xs) {
                        Text(item.name)
                            .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                            .foregroundStyle(PSColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .layoutPriority(2)

                        Spacer(minLength: PSSpacing.sm)

                        Text(item.expiryDate.expiryDisplayText)
                            .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                            .foregroundStyle(PSColors.expiryColor(for: item.expiryStatus))
                            .lineLimit(1)
                            .fixedSize()
                    }

                    HStack(spacing: PSSpacing.xs) {
                        Text(item.quantityDisplay)
                            .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, PSSpacing.sm)
                            .padding(.vertical, 2)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        PSExpiryBadge(status: item.expiryStatus)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, PSSpacing.md)
            .padding(.horizontal, PSSpacing.lg)
        }
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(
                    item.expiryStatus == .fresh
                        ? PSColors.borderLight
                        : PSColors.expiryColor(for: item.expiryStatus).opacity(0.2),
                    lineWidth: 1
                )
        )
        .shadow(color: PSColors.textPrimary.opacity(0.04), radius: 4, y: 2)
        .drawingGroup(opaque: false, colorMode: .nonLinear)
    }
}

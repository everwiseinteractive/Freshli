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
        withAnimation(FLMotion.adaptive(PSMotion.springDefault, reduceMotion: reduceMotion)) {
            item.isConsumed = true
            do {
                try modelContext.save()
                toastManager.show(.itemConsumed(itemName))
                celebrationManager.fireFoodSaved(modelContext: modelContext)
                WidgetDataService.updateWidgetData(modelContext: modelContext)
                if let userId = authManager.currentUserId {
                    Task {
                        await syncService.pushFreshliItem(item, userId: userId)
                        await syncService.recordImpactEvent(userId: userId, eventType: "consumed", itemName: itemName, moneySaved: 3.50, co2Avoided: 2.5)
                    }
                }
            } catch {
                toastManager.show(.error("Something went wrong. Please try again."))
                PSHaptics.shared.warning()
            }
        }
    }

    private func deleteItem(_ item: FreshliItem) {
        PSHaptics.shared.heavyTap()
        let itemName = item.name
        let itemId = item.id
        withAnimation(FLMotion.adaptive(PSMotion.springDefault, reduceMotion: reduceMotion)) {
            modelContext.delete(item)
            do {
                try modelContext.save()
                toastManager.show(.itemDeleted(itemName))
                if authManager.currentUserId != nil {
                    Task { await syncService.deleteFreshliItem(id: itemId) }
                }
            } catch {
                toastManager.show(.error("Something went wrong. Please try again."))
                PSHaptics.shared.warning()
            }
        }
    }

    private func shareItem(_ item: FreshliItem) {
        let itemName = item.name
        withAnimation(FLMotion.adaptive(PSMotion.springDefault, reduceMotion: reduceMotion)) {
            item.isShared = true
            do {
                try modelContext.save()
                toastManager.show(.itemShared(itemName))
                celebrationManager.fireShareCompleted(itemName: itemName, modelContext: modelContext)
                WidgetDataService.updateWidgetData(modelContext: modelContext)
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
                    // Bottom padding clears the FAB (fabSize + gap + extra breathing room).
                    // safeAreaInset in AppTabView handles the tab bar boundary.
                    .padding(.bottom, PSLayout.fabSize + PSSpacing.xxxl)
                    .listChangeAnimation(filteredItems.map(\.id))
                }
                .refreshable {
                    PSHaptics.shared.refreshSnap()
                    WidgetDataService.updateWidgetData(modelContext: modelContext)
                }
            }
        }
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
                // Category icon container
                ZStack {
                    RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                        .fill(PSColors.categoryColor(for: item.category).opacity(0.12))
                        .frame(width: PSLayout.categoryIconSize, height: PSLayout.categoryIconSize)
                    Text(item.category.emoji)
                        .font(.system(size: PSLayout.scaledFont(28)))
                    // Urgency dot
                    if item.expiryStatus != .fresh {
                        Circle()
                            .fill(PSColors.expiryColor(for: item.expiryStatus))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                            .offset(x: PSLayout.scaled(22), y: PSLayout.scaled(-22))
                    }
                }

                // Name + badges
                VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                    Text(item.name)
                        .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: PSSpacing.sm) {
                        Text(item.quantityDisplay)
                            .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                            .foregroundStyle(PSColors.textSecondary)
                            .padding(.horizontal, PSSpacing.sm)
                            .padding(.vertical, 2)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        PSExpiryBadge(status: item.expiryStatus)
                    }
                }

                Spacer(minLength: 0)

                // Right-side: expiry date + chevron
                VStack(alignment: .trailing, spacing: 3) {
                    Text(item.expiryDate.expiryDisplayText)
                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                        .foregroundStyle(PSColors.expiryColor(for: item.expiryStatus))
                    Image(systemName: "chevron.right")
                        .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                }
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

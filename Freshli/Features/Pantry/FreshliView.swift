import SwiftUI
import SwiftData
import os

// Figma: Pantry — bg-neutral-50, sticky white header, search (bg-neutral-100 rounded-2xl)
// Category chips: active bg-green-600 text-white shadow-md, icons (Carrot, Milk, Wheat, Beef)
// Item cards: rounded-[1.25rem] with w-16 h-16 image, Badge, MoreVertical
// FAB: w-16 h-16 bg-green-500 rounded-[1.25rem] bottom-24 right-6

struct FreshliView: View {
    @Binding var showAddItem: Bool

    @Query(filter: #Predicate<FreshliItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\FreshliItem.expiryDate)])
    private var allItems: [FreshliItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?
    @Environment(AuthManager.self) private var authManager: AuthManager?
    @Environment(SyncService.self) private var syncService: SyncService?
    @Environment(PSToastManager.self) private var toastManager: PSToastManager?
    @State private var searchText = ""
    @State private var selectedCategory: FoodCategory?
    @State private var selectedItem: FreshliItem?
    @State private var showFilterSheet = false
    @State private var showHarvestCelebration = false
    @State private var harvestIntensity: SparkleIntensity = .standard
    @State private var showSmartAdd = false
    @State private var showReplenish = false
    @State private var showDepletionInsights = false
    @State private var showReceiptScanner = false
    @State private var showDepletion = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pantryHeroNS

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

    // MARK: - Action Handlers (deduplicated swipe + context menu actions)

    private func consumeItem(_ item: FreshliItem) {
        // Trigger haptic harvest and sparkle celebration
        HapticHarvestService.shared.harvestCelebration()
        harvestIntensity = .standard
        showHarvestCelebration = true

        let itemName = item.name
        withAnimation(FLMotion.adaptive(PSMotion.springDefault, reduceMotion: reduceMotion)) {
            item.isConsumed = true
            do {
                try modelContext.save()
                toastManager?.show(.itemConsumed(itemName))
                celebrationManager?.fireFoodSaved(modelContext: modelContext)
                WidgetDataService.updateWidgetData(modelContext: modelContext)
                if let userId = authManager?.currentUserId {
                    Task {
                        await syncService?.pushFreshliItem(item, userId: userId)
                        await syncService?.recordImpactEvent(
                            userId: userId,
                            eventType: "consumed",
                            itemName: itemName,
                            moneySaved: 3.50,
                            co2Avoided: 2.5
                        )
                    }
                }
            } catch {
                toastManager?.show(.error("Something went wrong. Please try again."))
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
                toastManager?.show(.itemDeleted(itemName))
                if authManager?.currentUserId != nil {
                    Task { await syncService?.deleteFreshliItem(id: itemId) }
                }
            } catch {
                toastManager?.show(.error("Something went wrong. Please try again."))
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
                toastManager?.show(.itemShared(itemName))
                celebrationManager?.fireShareCompleted(itemName: itemName, modelContext: modelContext)
                WidgetDataService.updateWidgetData(modelContext: modelContext)
                if let userId = authManager?.currentUserId {
                    Task {
                        await syncService?.pushFreshliItem(item, userId: userId)
                        await syncService?.recordImpactEvent(
                            userId: userId,
                            eventType: "shared",
                            itemName: itemName,
                            co2Avoided: 2.5
                        )
                    }
                }
            } catch {
                toastManager?.show(.error("Something went wrong. Please try again."))
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

            // Figma: FAB w-16 h-16 bg-green-500 rounded-[1.25rem]
            Button { showAddItem = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: PSLayout.scaledFont(28), weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: PSLayout.fabSize, height: PSLayout.fabSize)
                    .background(PSColors.primaryGreen)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                    .shadow(color: PSColors.primaryGreen.opacity(0.4), radius: 16, y: 8)
                    .shadow(color: PSColors.primaryGreen.opacity(0.15), radius: 24, y: 12)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(String(localized: "Add Item"))
            .accessibilityHint(String(localized: "Double tap to add a new item to your pantry"))
            .padding(.trailing, PSLayout.adaptiveHorizontalPadding)
            // Ensure FAB clears tab bar + safe area
            .padding(.bottom, max(PSLayout.adaptiveHorizontalPadding + PSLayout.tabBarContentPadding, PSLayout.scaled(80)))
        }
        .navigationBarHidden(true)
        .onAppear {
            logger.info("FreshliView (Pantry) appeared — \(allItems.count) items, category: \(String(describing: selectedCategory))")
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

    // MARK: - Figma: Sticky Header

    private var stickyHeader: some View {
        VStack(spacing: PSSpacing.lg) {
            // Figma: text-3xl font-bold custom inline title
            HStack {
                Text(String(localized: "My Pantry"))
                    .font(.system(size: PSLayout.scaledFont(30), weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(PSColors.textPrimary)
                    .psAccessibleHeader(String(localized: "My Pantry, \(filteredItems.count) items"))
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
                .accessibilityLabel(String(localized: "Filter and sort"))
                .accessibilityHint(selectedCategory != nil ? String(localized: "Filter active: \(selectedCategory?.displayName ?? "Unknown")") : String(localized: "No filters applied"))
            }

            // Quick action buttons for Smart Add, Replenish, Receipt Scanner
            HStack(spacing: PSSpacing.md) {
                NavigationLink(destination: SmartAddView()) {
                    Label(String(localized: "Smart Add"), systemImage: "camera.viewfinder")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                        .padding(.horizontal, PSSpacing.md)
                        .padding(.vertical, PSSpacing.sm)
                        .background(PSColors.primaryGreen.opacity(0.1))
                        .clipShape(Capsule())
                }
                NavigationLink(destination: ReceiptScannerView()) {
                    Label(String(localized: "Receipt"), systemImage: "doc.text.viewfinder")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(PSColors.accentTeal)
                        .padding(.horizontal, PSSpacing.md)
                        .padding(.vertical, PSSpacing.sm)
                        .background(PSColors.accentTeal.opacity(0.1))
                        .clipShape(Capsule())
                }
                NavigationLink(destination: ReplenishView()) {
                    Label(String(localized: "Replenish"), systemImage: "cart.fill")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(PSColors.secondaryAmber)
                        .padding(.horizontal, PSSpacing.md)
                        .padding(.vertical, PSSpacing.sm)
                        .background(PSColors.secondaryAmber.opacity(0.1))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.top, PSSpacing.sm)

            // Figma: search input — bg-neutral-100 rounded-2xl py-3.5
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(PSColors.textTertiary)
                    .padding(.leading, PSSpacing.lg)

                TextField(String(localized: "Search ingredients..."), text: $searchText)
                    .font(.system(size: PSLayout.scaledFont(16)))
                    .foregroundStyle(PSColors.textPrimary)
            }
            .frame(height: PSLayout.searchBarHeight)
            .background(PSColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))

            // Figma: category chips — horizontal scroll
            // Safe area handling with scroll clip disabled
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.md) {
                    // "All Items" chip
                    categoryChip(title: String(localized: "All Items"), icon: nil, isActive: selectedCategory == nil) {
                        PSHaptics.shared.selection()
                        withAnimation(FLMotion.adaptive(PSMotion.springQuick, reduceMotion: reduceMotion)) {
                            selectedCategory = nil
                        }
                    }

                    // Category chips with icons
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
        // Figma: border-b border-neutral-100 shadow-sm
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    // Figma: category chip — active: bg-green-600 text-white shadow-md, inactive: bg-white border
    private func categoryChip(title: String, icon: String?, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: PSSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: PSLayout.scaledFont(16), weight: isActive ? .semibold : .regular))
                }
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .tracking(-0.2)
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
            .shadow(color: isActive ? PSColors.headerGreen.opacity(0.2) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Figma: Item List

    private var itemList: some View {
        Group {
            if filteredItems.isEmpty {
                ScrollView {
                    PSEmptyState(
                        icon: searchText.isEmpty ? "refrigerator" : "magnifyingglass",
                        title: searchText.isEmpty
                            ? String(localized: "Your pantry is empty")
                            : String(localized: "No matching ingredients"),
                        message: searchText.isEmpty
                            ? String(localized: "Start adding ingredients to keep track of what you have and get recipe suggestions.")
                            : String(localized: "Try adjusting your search or category filter to find what you're looking for."),
                        actionTitle: searchText.isEmpty ? String(localized: "Add Ingredient") : nil,
                        action: searchText.isEmpty ? { showAddItem = true } : nil
                    )
                    .adaptiveCardPadding()
                    .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            freshliItemCard(item: item)
                                .staggeredAppearance(index: index)
                                .bounceButtonModifier(pressedScale: 0.97, haptic: false)
                                .onTapGesture {
                                    PSHaptics.shared.lightTap()
                                    selectedItem = item
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteItem(item)
                                    } label: {
                                        Label(String(localized: "Delete"), systemImage: "trash")
                                    }
                                    .tint(PSColors.expiredRed)
                                    .accessibilityLabel(String(localized: "Delete \(item.name)"))
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        consumeItem(item)
                                    } label: {
                                        Label(String(localized: "Consume"), systemImage: "checkmark.circle")
                                    }
                                    .tint(PSColors.primaryGreen)
                                    .accessibilityLabel(String(localized: "Mark \(item.name) as consumed"))
                                }
                                .contextMenu {
                                    Button(String(localized: "Mark as Consumed"), systemImage: "checkmark.circle") {
                                        consumeItem(item)
                                    }
                                    Button(String(localized: "Share"), systemImage: "hand.raised") {
                                        shareItem(item)
                                    }
                                    Divider()
                                    Button(String(localized: "Delete"), systemImage: "trash", role: .destructive) {
                                        deleteItem(item)
                                    }
                                }
                        }
                    }
                    .adaptiveHPadding()
                    .padding(.vertical, PSLayout.cardPadding)
                    .padding(.bottom, PSLayout.tabBarContentPadding)
                    .listChangeAnimation(filteredItems.map(\.id))
                }
                .refreshable {
                    PSHaptics.shared.refreshSnap()
                    WidgetDataService.updateWidgetData(modelContext: modelContext)
                }
            }
        }
    }

    // Figma: item card — rounded-[1.25rem] p-3 with w-16 h-16 image, badge, more button
    private func freshliItemCard(item: FreshliItem) -> some View {
        HStack(spacing: PSSpacing.lg) {
            // Figma: w-16 h-16 rounded-[1rem] = 64x64 16px radius
            ZStack {
                RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                    .fill(PSColors.categoryColor(for: item.category).opacity(0.12))
                    .frame(width: PSLayout.categoryIconSize, height: PSLayout.categoryIconSize)

                Text(item.category.emoji)
                    .font(.system(size: PSLayout.scaledFont(28)))

                // Figma: expiry dot indicator — w-3 h-3 bg-amber-500 border-2 border-white
                if item.expiryStatus == .expiringSoon || item.expiryStatus == .expiringToday {
                    Circle()
                        .fill(PSColors.secondaryAmber)
                        .frame(width: PSLayout.scaled(12), height: PSLayout.scaled(12))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .offset(x: PSLayout.scaled(24), y: PSLayout.scaled(-24))
                }
            }

            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                Text(item.name)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: PSSpacing.md) {
                    Text(item.quantityDisplay)
                        .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                        .padding(.horizontal, PSSpacing.sm)
                        .padding(.vertical, PSSpacing.xxxs)
                        .background(PSColors.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.xs, style: .continuous))

                    PSExpiryBadge(status: item.expiryStatus)
                }
            }

            Spacer()

            Image(systemName: "ellipsis")
                .font(.system(size: PSLayout.scaledFont(20)))
                .foregroundStyle(PSColors.textTertiary)
                .padding(PSSpacing.md)
        }
        .padding(PSSpacing.md) // Figma: p-3
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        // Figma: shadow-sm border border-neutral-100
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
        .shadow(color: PSColors.textPrimary.opacity(0.04), radius: 2, y: 1)
        // GPU-offload complex cell rendering to eliminate jitter in LazyVStack
        .drawingGroup(opaque: false, colorMode: .nonLinear)
    }
}

#Preview("FreshliView - iPhone SE") {
    FreshliView(showAddItem: .constant(false))
}

#Preview("FreshliView - iPhone 16 Pro Max") {
    FreshliView(showAddItem: .constant(false))
}

import SwiftUI
import SwiftData

// Figma: Pantry — bg-neutral-50, sticky white header, search (bg-neutral-100 rounded-2xl)
// Category chips: active bg-green-600 text-white shadow-md, icons (Carrot, Milk, Wheat, Beef)
// Item cards: rounded-[1.25rem] with w-16 h-16 image, Badge, MoreVertical
// FAB: w-16 h-16 bg-green-500 rounded-[1.25rem] bottom-24 right-6

struct PantryView: View {
    @Binding var showAddItem: Bool

    @Query(filter: #Predicate<PantryItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated },
           sort: [SortDescriptor(\PantryItem.expiryDate)])
    private var allItems: [PantryItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(CelebrationManager.self) private var celebrationManager: CelebrationManager?
    @Environment(AuthManager.self) private var authManager: AuthManager?
    @Environment(SyncService.self) private var syncService: SyncService?
    @Environment(PSToastManager.self) private var toastManager: PSToastManager?
    @State private var searchText = ""
    @State private var selectedCategory: FoodCategory?
    @State private var selectedItem: PantryItem?
    @State private var showFilterSheet = false
    @State private var sortByExpiry = true

    private var filteredItems: [PantryItem] {
        var items = allItems
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if let selectedCategory {
            items = items.filter { $0.category == selectedCategory }
        }
        return items
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                stickyHeader
                itemList
            }
            .background(PSColors.backgroundSecondary)

            // Figma: FAB w-16 h-16 bg-green-500 rounded-[1.25rem]
            Button { showAddItem = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: PSLayout.scaledFont(28), weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: PSLayout.fabSize, height: PSLayout.fabSize)
                    .background(PSColors.primaryGreen)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                    .shadow(color: PSColors.primaryGreen.opacity(0.3), radius: 16, y: 8)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.trailing, PSLayout.adaptiveHorizontalPadding)
            .padding(.bottom, PSLayout.adaptiveHorizontalPadding)
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                PantryDetailView(item: item)
            }
            .presentationDragIndicator(.visible)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showFilterSheet) {
            NavigationStack {
                PantryFilterSheet(
                    selectedCategory: $selectedCategory,
                    sortByExpiry: $sortByExpiry
                )
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
                Spacer()
                PSIconButton(icon: "line.3.horizontal.decrease", size: PSLayout.scaled(36), tint: PSColors.textSecondary) {
                    showFilterSheet = true
                }
            }

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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.md) {
                    // "All Items" chip
                    categoryChip(title: String(localized: "All Items"), icon: nil, isActive: selectedCategory == nil) {
                        PSHaptics.shared.selection()
                        withAnimation(PSMotion.springQuick) { selectedCategory = nil }
                    }

                    // Category chips with icons
                    ForEach([FoodCategory.fruits, .vegetables, .dairy, .meat, .grains, .bakery], id: \.self) { cat in
                        categoryChip(title: cat.displayName, icon: cat.icon, isActive: selectedCategory == cat) {
                            PSHaptics.shared.selection()
                            withAnimation(PSMotion.springQuick) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                }
            }
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
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            pantryItemCard(item: item)
                                .staggeredAppearance(index: index)
                                .onTapGesture {
                                    PSHaptics.shared.lightTap()
                                    selectedItem = item
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        PSHaptics.shared.heavyTap()
                                        let itemName = item.name
                                        let itemId = item.id
                                        withAnimation(PSMotion.springDefault) {
                                            modelContext.delete(item)
                                            try? modelContext.save()
                                        }
                                        toastManager?.show(.itemDeleted(itemName))
                                        if authManager?.currentUserId != nil {
                                            Task { await syncService?.deletePantryItem(id: itemId) }
                                        }
                                    } label: {
                                        Label(String(localized: "Delete"), systemImage: "trash")
                                    }
                                    .tint(PSColors.expiredRed)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        PSHaptics.shared.success()
                                        let itemName = item.name
                                        withAnimation(PSMotion.springDefault) {
                                            item.isConsumed = true
                                            try? modelContext.save()
                                        }
                                        toastManager?.show(.itemConsumed(itemName))
                                        celebrationManager?.onFoodSaved(modelContext: modelContext)
                                        WidgetDataService.updateWidgetData(modelContext: modelContext)
                                        if let userId = authManager?.currentUserId {
                                            Task {
                                                await syncService?.pushPantryItem(item, userId: userId)
                                                await syncService?.recordImpactEvent(
                                                    userId: userId,
                                                    eventType: "consumed",
                                                    itemName: itemName,
                                                    moneySaved: 3.50,
                                                    co2Avoided: 2.5
                                                )
                                            }
                                        }
                                    } label: {
                                        Label(String(localized: "Consume"), systemImage: "checkmark.circle")
                                    }
                                    .tint(PSColors.primaryGreen)
                                }
                                .contextMenu {
                                    Button(String(localized: "Mark as Consumed"), systemImage: "checkmark.circle") {
                                        PSHaptics.shared.success()
                                        let itemName = item.name
                                        withAnimation(PSMotion.springDefault) {
                                            item.isConsumed = true
                                            try? modelContext.save()
                                        }
                                        toastManager?.show(.itemConsumed(itemName))
                                        celebrationManager?.onFoodSaved(modelContext: modelContext)
                                        WidgetDataService.updateWidgetData(modelContext: modelContext)
                                        if let userId = authManager?.currentUserId {
                                            Task {
                                                await syncService?.pushPantryItem(item, userId: userId)
                                                await syncService?.recordImpactEvent(
                                                    userId: userId,
                                                    eventType: "consumed",
                                                    itemName: itemName,
                                                    moneySaved: 3.50,
                                                    co2Avoided: 2.5
                                                )
                                            }
                                        }
                                    }
                                    Button(String(localized: "Share"), systemImage: "hand.raised") {
                                        let itemName = item.name
                                        withAnimation(PSMotion.springDefault) {
                                            item.isShared = true
                                            try? modelContext.save()
                                        }
                                        toastManager?.show(.itemShared(itemName))
                                        celebrationManager?.onShareCompleted(itemName: itemName, modelContext: modelContext)
                                        WidgetDataService.updateWidgetData(modelContext: modelContext)
                                        if let userId = authManager?.currentUserId {
                                            Task {
                                                await syncService?.pushPantryItem(item, userId: userId)
                                                await syncService?.recordImpactEvent(
                                                    userId: userId,
                                                    eventType: "shared",
                                                    itemName: itemName,
                                                    co2Avoided: 2.5
                                                )
                                            }
                                        }
                                    }
                                    Divider()
                                    Button(String(localized: "Delete"), systemImage: "trash", role: .destructive) {
                                        PSHaptics.shared.heavyTap()
                                        let itemName = item.name
                                        let itemId = item.id
                                        withAnimation(PSMotion.springDefault) {
                                            modelContext.delete(item)
                                            try? modelContext.save()
                                        }
                                        toastManager?.show(.itemDeleted(itemName))
                                        if authManager?.currentUserId != nil {
                                            Task { await syncService?.deletePantryItem(id: itemId) }
                                        }
                                    }
                                }
                        }
                    }
                    .adaptiveHPadding()
                    .padding(.vertical, PSLayout.cardPadding)
                    .padding(.bottom, PSLayout.tabBarContentPadding)
                }
                .refreshable {
                    PSHaptics.shared.refreshSnap()
                    WidgetDataService.updateWidgetData(modelContext: modelContext)
                }
            }
        }
    }

    // Figma: item card — rounded-[1.25rem] p-3 with w-16 h-16 image, badge, more button
    private func pantryItemCard(item: PantryItem) -> some View {
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
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

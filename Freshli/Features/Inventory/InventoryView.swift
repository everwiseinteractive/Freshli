import SwiftUI
import os

// MARK: - Inventory View

/// The main Freshli inventory screen with a Canvas-based gradient background
/// that shifts based on overall pantry freshness, glassmorphism item cells,
/// and matchedGeometryEffect transitions to the detail view.
struct InventoryView: View {
    @State private var viewModel = InventoryViewModel()
    @Namespace private var inventoryNamespace

    @State private var showSortMenu = false
    @State private var showAddItem = false

    private let logger = Logger(subsystem: "com.freshli.app", category: "InventoryView")

    // Auth — in production this comes from AuthManager environment
    private let userId = UUID()

    var body: some View {
        ZStack {
            // MARK: - Canvas Gradient Background
            freshnessGradientBackground
                .ignoresSafeArea()

            // MARK: - Main Content
            VStack(spacing: 0) {
                // Header
                inventoryHeader

                // Category chips
                categoryFilterBar

                // Item list
                if viewModel.isLoading {
                    loadingState
                } else if viewModel.filteredItems.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }

            // MARK: - Confetti Overlay
            ConfettiView(isActive: viewModel.showConfetti)
                .ignoresSafeArea()

            // MARK: - FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addButton
                }
            }
            .padding(PSSpacing.screenHorizontal)
            .padding(.bottom, PSSpacing.lg)

            // MARK: - Detail Overlay
            if viewModel.showDetail, let selectedId = viewModel.selectedItemId,
               let item = viewModel.items.first(where: { $0.id == selectedId }) {
                InventoryDetailOverlay(
                    item: item,
                    namespace: inventoryNamespace,
                    onDismiss: { viewModel.dismissDetail() }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .task {
            logger.info("InventoryView appeared — loading items")
            await viewModel.loadItems(userId: userId)
        }
        .sheet(isPresented: $showAddItem) {
            Text("Add Item")
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Canvas Gradient Background

    /// Renders a smooth gradient that shifts from green (fresh pantry)
    /// through amber (expiring) depending on the average freshness score.
    private var freshnessGradientBackground: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let freshness = viewModel.averageFreshness
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Gentle wave motion
                let wave = sin(time * 0.3) * 0.03

                // Color interpolation: green → amber → red
                let topColor: Color
                let midColor: Color
                let bottomColor: Color

                if freshness > 0.6 {
                    // Healthy pantry: lush greens
                    topColor = Color(hue: 0.35 + wave, saturation: 0.15, brightness: 0.97)
                    midColor = Color(hue: 0.32 + wave, saturation: 0.08, brightness: 0.99)
                    bottomColor = Color(hue: 0.30, saturation: 0.03, brightness: 1.0)
                } else if freshness > 0.3 {
                    // Warning zone: amber tones
                    let t = (freshness - 0.3) / 0.3
                    topColor = Color(hue: 0.12 + 0.23 * t + wave, saturation: 0.12, brightness: 0.97)
                    midColor = Color(hue: 0.10 + 0.22 * t + wave, saturation: 0.06, brightness: 0.99)
                    bottomColor = Color(hue: 0.08, saturation: 0.02, brightness: 1.0)
                } else {
                    // Critical: warm reds
                    topColor = Color(hue: 0.02 + wave, saturation: 0.15, brightness: 0.97)
                    midColor = Color(hue: 0.04 + wave, saturation: 0.08, brightness: 0.98)
                    bottomColor = Color(hue: 0.06, saturation: 0.03, brightness: 1.0)
                }

                // Draw gradient
                let gradient = Gradient(stops: [
                    .init(color: topColor, location: 0),
                    .init(color: midColor, location: 0.45),
                    .init(color: bottomColor, location: 1.0)
                ])

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: size.width * 0.3, y: 0),
                        endPoint: CGPoint(x: size.width * 0.7, y: size.height)
                    )
                )

                // Subtle organic blob shapes for depth
                drawAmbientBlob(
                    context: &context, size: size, time: time,
                    centerX: 0.25, centerY: 0.15,
                    radius: size.width * 0.35,
                    color: topColor.opacity(0.08)
                )

                drawAmbientBlob(
                    context: &context, size: size, time: time * 0.7,
                    centerX: 0.75, centerY: 0.6,
                    radius: size.width * 0.28,
                    color: midColor.opacity(0.06)
                )
            }
        }
    }

    private func drawAmbientBlob(
        context: inout GraphicsContext, size: CGSize, time: Double,
        centerX: Double, centerY: Double, radius: CGFloat, color: Color
    ) {
        let cx = size.width * centerX + CGFloat(sin(time * 0.2)) * 15
        let cy = size.height * centerY + CGFloat(cos(time * 0.15)) * 10

        let rect = CGRect(
            x: cx - radius, y: cy - radius,
            width: radius * 2, height: radius * 2
        )

        context.fill(
            Path(ellipseIn: rect),
            with: .color(color)
        )
    }

    // MARK: - Header

    private var inventoryHeader: some View {
        VStack(spacing: PSSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text(String(localized: "My Pantry"))
                        .font(.system(size: PSLayout.scaledFont(28), weight: .bold, design: .rounded))
                        .foregroundStyle(PSColors.textPrimary)

                    Text(itemCountLabel)
                        .font(.system(size: PSLayout.scaledFont(14), weight: .medium, design: .rounded))
                        .foregroundStyle(PSColors.textSecondary)
                }

                Spacer()

                // Sort button
                Menu {
                    ForEach(InventoryViewModel.SortOrder.allCases) { order in
                        Button {
                            viewModel.setSort(order)
                        } label: {
                            HStack {
                                Text(order.rawValue)
                                if viewModel.sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.system(size: PSLayout.scaledFont(22), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                // Freshness score pill
                freshnessPill
            }

            // Search bar
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: PSLayout.scaledFont(15)))
                    .foregroundStyle(PSColors.textTertiary)

                TextField(String(localized: "Search items..."), text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.setSearch($0) }
                ))
                .font(.system(size: PSLayout.scaledFont(15), design: .rounded))
                .foregroundStyle(PSColors.textPrimary)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.setSearch("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: PSLayout.scaledFont(15)))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, PSSpacing.md)
            .padding(.vertical, PSSpacing.sm)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
        .padding(.top, PSSpacing.lg)
        .padding(.bottom, PSSpacing.md)
    }

    // MARK: - Freshness Pill

    private var freshnessPill: some View {
        let pct = Int(viewModel.averageFreshness * 100)
        let color: Color = viewModel.averageFreshness > 0.6
            ? PSColors.primaryGreen
            : viewModel.averageFreshness > 0.3
                ? PSColors.warningAmber
                : PSColors.expiredRed

        return HStack(spacing: PSSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text("\(pct)%")
                .font(.system(size: PSLayout.scaledFont(13), weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, PSSpacing.sm)
        .padding(.vertical, PSSpacing.xs)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PSSpacing.sm) {
                // "All" chip
                categoryChip(title: String(localized: "All"), isSelected: viewModel.selectedCategory == nil) {
                    viewModel.setCategory(nil)
                }

                ForEach(FoodCategory.allCases, id: \.self) { category in
                    categoryChip(
                        title: category.displayName,
                        emoji: category.emoji,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.setCategory(category)
                    }
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
        .padding(.bottom, PSSpacing.md)
    }

    private func categoryChip(title: String, emoji: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: PSSpacing.xs) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: PSLayout.scaledFont(14)))
                }
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(13), weight: isSelected ? .semibold : .medium, design: .rounded))
            }
            .padding(.horizontal, PSSpacing.md)
            .padding(.vertical, PSSpacing.sm)
            .background(isSelected ? PSColors.primaryGreen.opacity(0.15) : Color.white.opacity(0.001))
            .background(.ultraThinMaterial)
            .foregroundStyle(isSelected ? PSColors.primaryGreen : PSColors.textSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? PSColors.primaryGreen.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Item List

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: PSSpacing.sm) {
                ForEach(viewModel.filteredItems) { item in
                    if viewModel.selectedItemId != item.id || !viewModel.showDetail {
                        FreshliItemCell(
                            item: item,
                            namespace: inventoryNamespace,
                            onConsumed: {
                                Task { await viewModel.markConsumed(item) }
                            },
                            onShare: {
                                Task { await viewModel.markShared(item) }
                            },
                            onTap: {
                                viewModel.selectItem(item)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .move(edge: .trailing))
                        ))
                    }
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.bottom, 100) // Room for FAB
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: PSSpacing.xl) {
            Spacer()

            Image(systemName: "refrigerator.fill")
                .font(.system(size: PSLayout.scaledFont(48)))
                .foregroundStyle(PSColors.textTertiary)

            VStack(spacing: PSSpacing.sm) {
                Text(String(localized: "Your pantry is empty"))
                    .font(.system(size: PSLayout.scaledFont(20), weight: .semibold, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)

                Text(String(localized: "Add items to start tracking freshness"))
                    .font(.system(size: PSLayout.scaledFont(15), weight: .medium, design: .rounded))
                    .foregroundStyle(PSColors.textSecondary)
            }

            PSButton(
                title: String(localized: "Add First Item"),
                style: .primary,
                size: .medium,
                action: { showAddItem = true }
            )

            Spacer()
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(PSColors.primaryGreen)
                .scaleEffect(1.2)
            Spacer()
        }
    }

    // MARK: - Add Button (FAB)

    private var addButton: some View {
        Button {
            PSHaptics.shared.mediumTap()
            showAddItem = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: PSLayout.scaledFont(22), weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: PSLayout.fabSize, height: PSLayout.fabSize)
                .background(
                    Circle()
                        .fill(PSColors.primaryGreen.gradient)
                        .shadow(color: PSColors.primaryGreen.opacity(0.35), radius: 12, y: 4)
                )
        }
    }

    // MARK: - Helpers

    private var itemCountLabel: String {
        let count = viewModel.filteredItems.count
        let total = viewModel.items.filter { !$0.isConsumed && !$0.isShared && !$0.isDonated }.count
        if viewModel.selectedCategory != nil || !viewModel.searchText.isEmpty {
            return "\(count) of \(total) items"
        }
        return "\(total) items"
    }
}

// MARK: - Inventory Detail Overlay

/// Full-screen detail view that animates in using matchedGeometryEffect.
struct InventoryDetailOverlay: View {
    let item: SupabaseFreshliItem
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    private var category: FoodCategory {
        FoodCategory(rawValue: item.category.lowercased()) ?? .other
    }

    private var expiryStatus: ExpiryStatus {
        ExpiryStatus.from(expiryDate: item.expiryDate)
    }

    var body: some View {
        ZStack {
            // Scrim
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            ScrollView {
                VStack(spacing: PSSpacing.xl) {
                    // Hero section
                    heroSection

                    // Details grid
                    detailsGrid

                    // Notes
                    if let notes = item.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    // Actions
                    actionButtons

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.top, PSSpacing.xxl)
            }
            .background(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)
            )
            .matchedGeometryEffect(id: "card_\(item.id)", in: namespace)
            .overlay(alignment: .topTrailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(28)))
                        .foregroundStyle(PSColors.textTertiary)
                }
                .padding(PSSpacing.lg)
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: PSSpacing.lg) {
            // Emoji circle
            Text(category.emoji)
                .font(.system(size: PSLayout.scaledFont(56)))
                .frame(width: PSLayout.scaled(96), height: PSLayout.scaled(96))
                .background(
                    Circle()
                        .fill(PSColors.categoryColor(for: category).opacity(0.15))
                )
                .matchedGeometryEffect(id: "emoji_\(item.id)", in: namespace)

            // Name
            Text(item.name)
                .font(.system(size: PSLayout.scaledFont(24), weight: .bold, design: .rounded))
                .foregroundStyle(PSColors.textPrimary)
                .matchedGeometryEffect(id: "name_\(item.id)", in: namespace)

            // Expiry badge
            PSExpiryBadge(status: expiryStatus)
                .matchedGeometryEffect(id: "gauge_\(item.id)", in: namespace)
        }
    }

    // MARK: - Details Grid

    private var detailsGrid: some View {
        PSGlassCard {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PSSpacing.lg) {
                detailCell(
                    icon: "number",
                    label: String(localized: "Quantity"),
                    value: "\(String(format: "%.0f", item.quantity)) \(MeasurementUnit(rawValue: item.unit)?.displayName ?? item.unit)"
                )

                detailCell(
                    icon: "tray.fill",
                    label: String(localized: "Storage"),
                    value: StorageLocation(rawValue: item.storageLocation)?.displayName ?? item.storageLocation
                )

                detailCell(
                    icon: "calendar",
                    label: String(localized: "Added"),
                    value: item.dateAdded.formatted(.dateTime.month(.abbreviated).day())
                )

                detailCell(
                    icon: "clock.badge.exclamationmark",
                    label: String(localized: "Expires"),
                    value: item.expiryDate.formatted(.dateTime.month(.abbreviated).day())
                )
            }
        }
    }

    private func detailCell(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.xs) {
            HStack(spacing: PSSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(13)))
                    .foregroundStyle(PSColors.textTertiary)

                Text(label)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium, design: .rounded))
                    .foregroundStyle(PSColors.textTertiary)
            }

            Text(value)
                .font(.system(size: PSLayout.scaledFont(16), weight: .semibold, design: .rounded))
                .foregroundStyle(PSColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        PSGlassCard {
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: "note.text")
                        .font(.system(size: PSLayout.scaledFont(14)))
                        .foregroundStyle(PSColors.textTertiary)

                    Text(String(localized: "Notes"))
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold, design: .rounded))
                        .foregroundStyle(PSColors.textSecondary)
                }

                Text(notes)
                    .font(.system(size: PSLayout.scaledFont(15), design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: PSSpacing.md) {
            PSButton(
                title: String(localized: "Mark Consumed"),
                style: .primary,
                isFullWidth: true,
                action: { onDismiss() }
            )

            PSButton(
                title: String(localized: "Share with Neighbor"),
                style: .secondary,
                isFullWidth: true,
                action: { onDismiss() }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    InventoryView()
}

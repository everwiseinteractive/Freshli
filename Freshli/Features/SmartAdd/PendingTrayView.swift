import SwiftUI

/// A bottom tray that shows items "discovered" by the scanner.
/// Items float up into the tray with fluid spring animations.
struct PendingTrayView: View {
    @Bindable var viewModel: SmartAddViewModel
    let onSaveAll: () -> Void

    @State private var appearedItemIDs: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle + header
            trayHeader

            if viewModel.isTrayExpanded {
                trayContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .elevation(.z3)
    }

    // MARK: - Header

    private var trayHeader: some View {
        Button {
            withAnimation(PSMotion.springDefault) {
                viewModel.isTrayExpanded.toggle()
            }
            PSHaptics.shared.selection()
        } label: {
            VStack(spacing: PSSpacing.sm) {
                // Pill handle
                Capsule()
                    .fill(.white.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, PSSpacing.sm)

                HStack(spacing: PSSpacing.md) {
                    // Item count badge
                    Text("\(viewModel.pendingItems.count)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(PSColors.primaryGreen)
                        .clipShape(Circle())

                    Text("Pending Items")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PSColors.textPrimary)

                    Spacer()

                    Image(systemName: viewModel.isTrayExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                        .rotationEffect(.degrees(viewModel.isTrayExpanded ? 0 : 180))
                        .animation(PSMotion.springQuick, value: viewModel.isTrayExpanded)
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.bottom, viewModel.isTrayExpanded ? PSSpacing.sm : PSSpacing.md)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pending Items")
        .accessibilityValue("\(viewModel.pendingItems.count) items")
        .accessibilityHint(viewModel.isTrayExpanded ? "Double tap to collapse" : "Double tap to expand")
    }

    // MARK: - Content

    private var trayContent: some View {
        VStack(spacing: PSSpacing.md) {
            // Item list
            ScrollView {
                LazyVStack(spacing: PSSpacing.sm) {
                    ForEach(Array(viewModel.pendingItems.enumerated()), id: \.element.id) { index, item in
                        pendingItemRow(item: item, index: index)
                    }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
            }
            .frame(maxHeight: 220)

            // Save all button
            if !viewModel.pendingItems.isEmpty {
                PSButton(
                    title: "Add \(viewModel.pendingItems.count) to Pantry",
                    icon: "checkmark.circle.fill",
                    style: .primary,
                    size: .medium,
                    isFullWidth: true,
                    action: onSaveAll
                )
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.bottom, PSSpacing.lg)
            }
        }
    }

    // MARK: - Item Row

    private func pendingItemRow(item: ParsedFoodItem, index: Int) -> some View {
        let hasAppeared = appearedItemIDs.contains(item.id)

        return HStack(spacing: PSSpacing.md) {
            // Category emoji
            Text(item.category.emoji)
                .font(.system(size: 22))
                .frame(width: 36, height: 36)
                .background(PSColors.categoryColor(for: item.category).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: PSSpacing.sm) {
                    Text(item.category.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)

                    Text("\u{2022}")
                        .font(.system(size: 8))
                        .foregroundStyle(PSColors.textTertiary)

                    Text("~\(item.estimatedExpiryDays)d")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PSColors.warningAmber)
                }
            }

            Spacer()

            // Remove button
            Button {
                viewModel.removeItem(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(PSColors.textTertiary)
            }
            .accessibilityLabel("Remove \(item.name)")
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        // Float-up entrance animation
        .offset(y: hasAppeared ? 0 : 40)
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.85)
        .onAppear {
            guard !hasAppeared else { return }
            _ = withAnimation(
                PSMotion.springBouncy.delay(PSMotion.staggerDelay(index: index, base: 0.06))
            ) {
                appearedItemIDs.insert(item.id)
            }
        }
    }
}

import SwiftUI

// MARK: - Pantry Filter Sheet
// Filter & sort options for the pantry list.

struct PantryFilterSheet: View {
    @Binding var selectedCategory: FoodCategory?
    @Binding var sortByExpiry: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Sort Section
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                Text(String(localized: "Sort By"))
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                HStack(spacing: 12) {
                    sortChip(title: String(localized: "Expiry Date"), icon: "clock", isActive: sortByExpiry) {
                        withAnimation(PSMotion.springQuick) { sortByExpiry = true }
                    }
                    sortChip(title: String(localized: "Name"), icon: "textformat", isActive: !sortByExpiry) {
                        withAnimation(PSMotion.springQuick) { sortByExpiry = false }
                    }
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.top, PSSpacing.xl)
            .padding(.bottom, PSSpacing.xxl)

            Divider().padding(.horizontal, PSSpacing.screenHorizontal)

            // MARK: - Category Filter
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                Text(String(localized: "Category"))
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                    categoryFilterChip(title: String(localized: "All"), category: nil)

                    ForEach(FoodCategory.allCases) { cat in
                        categoryFilterChip(title: cat.displayName, category: cat)
                    }
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.top, PSSpacing.xxl)

            Spacer()

            // MARK: - Clear Filters
            Button {
                withAnimation(PSMotion.springQuick) {
                    selectedCategory = nil
                    sortByExpiry = true
                }
                dismiss()
            } label: {
                Text(String(localized: "Clear Filters"))
                    .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                    .foregroundStyle(PSColors.primaryGreen)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(PSColors.emeraldSurface)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.bottom, PSSpacing.xl)
        }
        .navigationTitle(String(localized: "Filter & Sort"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Done")) { dismiss() }
                    .fontWeight(.semibold)
                    .foregroundStyle(PSColors.primaryGreen)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(PSMotion.springDefault.delay(0.05)) { appeared = true }
        }
    }

    // MARK: - Chip Helpers

    private func sortChip(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .tracking(-0.2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(isActive ? .white : PSColors.textSecondary)
            .background(isActive ? PSColors.headerGreen : PSColors.surfaceCard)
            .clipShape(Capsule())
            .overlay {
                if !isActive { Capsule().strokeBorder(PSColors.border, lineWidth: 1) }
            }
            .shadow(color: isActive ? PSColors.headerGreen.opacity(0.2) : .clear, radius: 6, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func categoryFilterChip(title: String, category: FoodCategory?) -> some View {
        let isActive = selectedCategory == category
        return Button {
            withAnimation(PSMotion.springQuick) { selectedCategory = category }
        } label: {
            Text(title)
                .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .foregroundStyle(isActive ? .white : PSColors.textSecondary)
                .background(isActive ? PSColors.primaryGreen : PSColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

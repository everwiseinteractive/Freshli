import SwiftUI

/// A glassmorphic search bar for manual food entry with SF Symbol suggestions.
struct SmartAddSearchBar: View {
    @Bindable var viewModel: SmartAddViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Glassmorphic search field
            HStack(spacing: PSSpacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PSColors.primaryGreen)

                TextField("Search to add manually...", text: $viewModel.searchQuery)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PSColors.textPrimary)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onChange(of: viewModel.searchQuery) { _, _ in
                        viewModel.updateSearchSuggestions()
                    }

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                        viewModel.searchSuggestions = []
                        isFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, PSSpacing.lg)
            .padding(.vertical, PSSpacing.md)
            // Liquid Glass (iOS 26) — search field feels anchored but translucent.
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                    .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

            // Suggestions dropdown
            if !viewModel.searchSuggestions.isEmpty && isFocused {
                suggestionsDropdown
                    .transition(PSMotion.fadeSlide)
            }
        }
        .animation(PSMotion.springQuick, value: viewModel.searchSuggestions.isEmpty)
    }

    // MARK: - Suggestions

    private var suggestionsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.searchSuggestions.prefix(5).enumerated()), id: \.element.id) { index, suggestion in
                if index > 0 {
                    Divider()
                        .foregroundStyle(PSColors.divider)
                        .padding(.leading, 52)
                }

                Button {
                    viewModel.addFromSuggestion(suggestion)
                    isFocused = false
                } label: {
                    HStack(spacing: PSSpacing.md) {
                        // SF Symbol icon
                        Image(systemName: suggestion.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(PSColors.categoryColor(for: suggestion.category))
                            .frame(width: 32, height: 32)
                            .background(PSColors.categoryColor(for: suggestion.category).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PSColors.textPrimary)

                            Text(suggestion.category.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PSColors.textSecondary)
                        }

                        Spacer()

                        // Expiry hint
                        Text("~\(suggestion.expiryDays)d")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(PSColors.warningAmber)
                            .padding(.horizontal, PSSpacing.sm)
                            .padding(.vertical, PSSpacing.xxs)
                            .background(PSColors.warningAmber.opacity(0.1))
                            .clipShape(Capsule())

                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(PSColors.primaryGreen)
                    }
                    .padding(.horizontal, PSSpacing.lg)
                    .padding(.vertical, PSSpacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(suggestion.name)")
                .accessibilityHint("\(suggestion.category.displayName), expires in about \(suggestion.expiryDays) days")
            }
        }
        // Liquid Glass (iOS 26) — suggestions float above the content.
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.top, PSSpacing.sm)
    }
}

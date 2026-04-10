import SwiftUI

// MARK: - Create Circle View
// Form for creating a new Freshli Circle. All circles are private by default.

struct CreateCircleView: View {
    @Bindable var viewModel: CirclesViewModel
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    private let emojiOptions = ["🏠", "👨‍👩‍👧‍👦", "🏘️", "🤝", "🌿", "🍎", "🥗", "❤️", "🌻", "🫂"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xxl) {
                    emojiPicker
                    nameField
                    descriptionField

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.expiredRed)
                    }

                    privacyNote
                    createButton
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.screenVertical)
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle("New Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Emoji Picker

    private var emojiPicker: some View {
        VStack(spacing: PSSpacing.sm) {
            Text(viewModel.newCircleEmoji)
                .font(.system(size: 64))
                .frame(width: 96, height: 96)
                .background(PSColors.emeraldLight)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.sm) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button {
                            withAnimation(PSMotion.springQuick) {
                                viewModel.newCircleEmoji = emoji
                            }
                            PSHaptics.shared.selection()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(width: 44, height: 44)
                                .background(
                                    viewModel.newCircleEmoji == emoji
                                        ? PSColors.primaryGreen.opacity(0.15)
                                        : PSColors.backgroundSecondary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: PSSpacing.xs) {
            Text("Circle Name")
                .font(PSTypography.subheadlineMedium)
                .foregroundStyle(PSColors.textSecondary)

            TextField("e.g. The Johnsons, Building 4A", text: $viewModel.newCircleName)
                .font(PSTypography.body)
                .padding(PSSpacing.md)
                .background(PSColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: PSSpacing.xs) {
            Text("Description (optional)")
                .font(PSTypography.subheadlineMedium)
                .foregroundStyle(PSColors.textSecondary)

            TextField("What's this circle about?", text: $viewModel.newCircleDescription, axis: .vertical)
                .font(PSTypography.body)
                .lineLimit(2...4)
                .padding(PSSpacing.md)
                .background(PSColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
        }
    }

    // MARK: - Privacy Note

    private var privacyNote: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(PSColors.primaryGreen)

            Text("Everything shared in your circle stays private. Items are only visible to members unless you choose \"Global Share.\"")
                .font(PSTypography.caption1)
                .foregroundStyle(PSColors.textSecondary)
        }
        .padding(PSSpacing.md)
        .background(PSColors.emeraldLight.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
    }

    // MARK: - Create Button

    private var createButton: some View {
        PSButton(title: "Create Circle", icon: "plus.circle.fill", isLoading: viewModel.isLoading) {
            guard let userId = authManager.currentUserId else { return }
            Task {
                if await viewModel.createCircle(userId: userId) {
                    dismiss()
                }
            }
        }
    }
}

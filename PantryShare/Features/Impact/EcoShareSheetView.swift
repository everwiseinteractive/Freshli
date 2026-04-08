import SwiftUI
import SwiftData

/// The sharing flow view for "Eco-Status" shareable cards
/// Allows users to customize and share their sustainability impact
struct EcoShareSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedStyle: EcoShareCard.CardStyle = .weeklyRecap
    @State private var showUsername = false
    @State private var showExactNumbers = true
    @State private var isRendering = false

    @Query private var profiles: [UserProfile]

    let stats: ImpactService.ImpactStats

    private var userName: String? {
        showUsername ? profiles.first?.displayName : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center, spacing: PSSpacing.xxl) {
                    // MARK: - Card Preview
                    cardPreviewSection

                    Divider()
                        .padding(.vertical, PSSpacing.lg)

                    // MARK: - Style Picker
                    stylePickerSection

                    // MARK: - Customize Section
                    customizeSection

                    // MARK: - Share Button
                    shareButtonSection

                    Spacer()
                        .frame(height: PSSpacing.lg)
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.screenVertical)
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle(String(localized: "Share Your Impact"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(PSColors.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Card Preview Section

    private var cardPreviewSection: some View {
        VStack(alignment: .center, spacing: PSSpacing.md) {
            Text(String(localized: "Preview"))
                .font(PSTypography.headline)
                .foregroundColor(PSColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Card preview at reduced scale
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PSColors.surfaceCard)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

                EcoShareCard(
                    stats: stats,
                    style: selectedStyle,
                    userName: userName,
                    showExactNumbers: showExactNumbers
                )
                .scaleEffect(0.5)
                .frame(height: 320)
            }
            .frame(height: 380)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Style Picker Section

    private var stylePickerSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text(String(localized: "Card Style"))
                .font(PSTypography.headline)
                .foregroundColor(PSColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.md) {
                    stylePickerButton(
                        title: String(localized: "Weekly Recap"),
                        icon: "calendar.badge.clock",
                        style: .weeklyRecap
                    )

                    stylePickerButton(
                        title: String(localized: "Milestone"),
                        icon: "star.fill",
                        style: .milestone
                    )

                    stylePickerButton(
                        title: String(localized: "Streak"),
                        icon: "flame.fill",
                        style: .streak
                    )
                }
                .padding(.vertical, PSSpacing.xs)
            }
        }
    }

    private func stylePickerButton(
        title: String,
        icon: String,
        style: EcoShareCard.CardStyle
    ) -> some View {
        VStack(alignment: .center, spacing: PSSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(
                    selectedStyle == style ? PSColors.textOnPrimary : PSColors.textSecondary
                )

            Text(title)
                .font(PSTypography.caption1Medium)
                .foregroundColor(
                    selectedStyle == style ? PSColors.textOnPrimary : PSColors.textSecondary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minWidth: 100, maxWidth: .infinity)
        .padding(PSSpacing.md)
        .background(
            selectedStyle == style
                ? PSColors.primaryGreen
                : PSColors.backgroundSecondary
        )
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        .onTapGesture {
            withAnimation(PSMotion.springQuick) {
                selectedStyle = style
            }
        }
    }

    // MARK: - Customize Section

    private var customizeSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text(String(localized: "Customize"))
                .font(PSTypography.headline)
                .foregroundColor(PSColors.textPrimary)

            VStack(alignment: .leading, spacing: PSSpacing.lg) {
                // Toggle: Show Username
                customizeToggleRow(
                    title: String(localized: "Show Username"),
                    subtitle: String(localized: "Display your name on the card"),
                    isOn: $showUsername
                )

                Divider()
                    .foregroundColor(PSColors.divider)

                // Toggle: Exact Numbers vs Rounded
                customizeToggleRow(
                    title: String(localized: "Show Exact Numbers"),
                    subtitle: String(localized: "~50 items vs 47 items"),
                    isOn: $showExactNumbers
                )
            }
            .padding(PSSpacing.lg)
            .background(PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    private func customizeToggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: PSSpacing.md) {
            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                Text(title)
                    .font(PSTypography.bodyMedium)
                    .foregroundColor(PSColors.textPrimary)

                Text(subtitle)
                    .font(PSTypography.caption1)
                    .foregroundColor(PSColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(PSColors.primaryGreen)
        }
    }

    // MARK: - Share Button Section

    private var shareButtonSection: some View {
        VStack(spacing: PSSpacing.md) {
            Button(action: renderAndShare) {
                if isRendering {
                    ProgressView()
                        .tint(PSColors.textOnPrimary)
                } else {
                    HStack(spacing: PSSpacing.sm) {
                        Image(systemName: "square.and.arrow.up")
                        Text(String(localized: "Share Story"))
                    }
                    .font(PSTypography.headline)
                    .foregroundColor(PSColors.textOnPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(PSColors.primaryGreen)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            .shadow(color: PSColors.primaryGreen.opacity(0.3), radius: 10, x: 0, y: 4)
            .disabled(isRendering)

            Button(action: { dismiss() }) {
                Text(String(localized: "Done"))
                    .font(PSTypography.headline)
                    .foregroundColor(PSColors.primaryGreen)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(PSColors.primaryGreen.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        }
    }

    // MARK: - Image Rendering

    private func renderAndShare() {
        isRendering = true

        // Create the card view for rendering at full resolution
        let cardView = EcoShareCard(
            stats: stats,
            style: selectedStyle,
            userName: userName,
            showExactNumbers: showExactNumbers
        )
        .frame(width: 360, height: 640) // 9:16 at 1/3 scale

        // Render to image at 3x scale for crisp quality
        if let image = renderViewToImage(cardView, scale: 3.0) {
            shareImage(image)
        }

        isRendering = false
    }

    @MainActor
    private func renderViewToImage(_ view: some View, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.uiImage
    }

    private func shareImage(_ image: UIImage) {
        let items: [Any] = [image]
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // Exclude certain activity types
        activity.excludedActivityTypes = [
            .print,
            .saveToCameraRoll
        ]

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController
        {
            rootViewController.present(activity, animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    let stats = ImpactService.ImpactStats(
        itemsSaved: 42,
        itemsShared: 8,
        itemsDonated: 5,
        mealsCreated: 12
    )

    EcoShareSheetView(stats: stats)
        .modelContainer(for: [UserProfile.self], inMemory: true)
}

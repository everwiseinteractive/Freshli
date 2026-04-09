import SwiftUI

/// High-resolution shareable card for Instagram Stories (9:16 aspect ratio)
/// Rendered via ImageRenderer at 3x scale for crisp output
struct WeeklyWrapShareCard: View {
    let viewModel: WeeklyWrapViewModel

    private var data: ImpactWrapDataService.WeeklyWrapData { viewModel.wrapData }

    var body: some View {
        ZStack {
            // Gradient background
            backgroundGradient

            // Subtle grain texture
            grainOverlay

            // Content stack
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 40)
                    .padding(.horizontal, 24)

                Spacer()

                heroStatSection
                    .padding(.horizontal, 24)

                Spacer()

                impactRow
                    .padding(.horizontal, 24)

                Spacer()

                treeIllustration
                    .frame(height: 120)

                Spacer()

                footerSection
                    .padding(.bottom, 32)
                    .padding(.horizontal, 24)
            }
        }
        .frame(width: 360, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                categoryAccentColor.opacity(0.9),
                PSColors.primaryGreenDark,
                Color(hex: 0x0A0A0A)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var grainOverlay: some View {
        Canvas { context, size in
            for y in stride(from: 0.0, through: size.height, by: 4) {
                for x in stride(from: 0.0, through: size.width, by: 4) {
                    let randomOpacity = Double.random(in: 0.01...0.03)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                        with: .color(.white.opacity(randomOpacity))
                    )
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Freshli Weekly Wrap")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.9))

            Text(data.weekDisplayRange)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero Stat

    private var heroStatSection: some View {
        VStack(spacing: 8) {
            Text("\(data.totalItemsImpacted)")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            Text("Items Saved This Week")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: - Impact Row

    private var impactRow: some View {
        HStack(spacing: 12) {
            ShareStatPill(
                icon: "heart.fill",
                value: "\(data.itemsShared + data.itemsDonated)",
                label: "Meals Shared"
            )
            ShareStatPill(
                icon: "cloud.fill",
                value: data.co2AvoidedDisplay + "kg",
                label: "CO\u{2082} Saved"
            )
            ShareStatPill(
                icon: "dollarsign.circle.fill",
                value: data.moneySavedDisplay,
                label: "Saved"
            )
        }
    }

    // MARK: - Tree Illustration (static for share card)

    private var treeIllustration: some View {
        ZStack {
            // Simple trunk
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x8B6914), Color(hex: 0x5D4408)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 12, height: 40)
                .offset(y: 30)

            // Canopy layers
            ForEach(0..<3, id: \.self) { i in
                Ellipse()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                [Color(hex: 0x4ADE80), Color(hex: 0x22C55E), Color(hex: 0x16A34A)][i],
                                [Color(hex: 0x22C55E), Color(hex: 0x16A34A), Color(hex: 0x15803D)][i].opacity(0.7)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: CGFloat(40 - i * 8)
                        )
                    )
                    .frame(
                        width: CGFloat(70 - i * 12),
                        height: CGFloat(55 - i * 10)
                    )
                    .offset(y: CGFloat(-10 - i * 22))
            }

            // Scattered leaves
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10))
                    .foregroundColor(PSColors.primaryGreen.opacity(0.5))
                    .offset(
                        x: [-35, 30, -20, 40][i],
                        y: [-30, -45, 10, -15][i]
                    )
                    .rotationEffect(.degrees([15, -25, 40, -10][i]))
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Divider()
                .overlay(Color.white.opacity(0.15))

            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Freshli")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)

            Text("Join the fight against food waste")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Accent Color

    private var categoryAccentColor: Color {
        switch data.topCategorySaved {
        case .vegetables, .condiments:
            return PSColors.primaryGreen
        case .fruits, .bakery, .snacks:
            return Color(hex: 0xFBBF24)
        case .meat:
            return Color(hex: 0xEF5350)
        case .seafood:
            return PSColors.accentTeal
        case .dairy, .beverages:
            return Color(hex: 0x42A5F5)
        default:
            return PSColors.primaryGreen
        }
    }
}

// MARK: - Stat Pill Subcomponent

private struct ShareStatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    WeeklyWrapShareCard(viewModel: .preview)
        .padding()
        .background(Color.gray)
}

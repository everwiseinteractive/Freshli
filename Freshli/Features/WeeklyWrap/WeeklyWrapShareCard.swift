import SwiftUI

/// High-resolution shareable card for Instagram Stories (9:16 aspect ratio).
/// Rendered via ImageRenderer at 3× scale for crisp output.
///
/// Visual revamp: multi-blob gradient background, streak badge, week-over-
/// week indicator, category breakdown row, finer grain, accent-colored
/// stat pill borders. Uses only RadialGradient + LinearGradient (no
/// MeshGradient) since ImageRenderer doesn't always capture MeshGradient.
struct WeeklyWrapShareCard: View {
    let viewModel: WeeklyWrapViewModel

    private var data: ImpactWrapDataService.WeeklyWrapData { viewModel.wrapData }

    var body: some View {
        ZStack {
            backgroundGradient
            grainOverlay

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

                // Category highlight row
                if !data.categoryBreakdown.isEmpty {
                    categoryHighlight
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }

                Spacer()

                treeIllustration
                    .frame(height: 110)

                Spacer()

                footerSection
                    .padding(.bottom, 28)
                    .padding(.horizontal, 24)
            }
        }
        .frame(width: 360, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }

    // MARK: - Background (multi-blob, no MeshGradient for ImageRenderer safety)

    private var backgroundGradient: some View {
        ZStack {
            // Base: dark canvas
            Color(hex: 0x0A0A0A)

            // Top-left category accent blob
            RadialGradient(
                gradient: Gradient(colors: [
                    categoryAccentColor.opacity(0.6),
                    categoryAccentColor.opacity(0.0)
                ]),
                center: UnitPoint(x: 0.15, y: 0.1),
                startRadius: 0,
                endRadius: 200
            )

            // Center-right green glow
            RadialGradient(
                gradient: Gradient(colors: [
                    PSColors.primaryGreen.opacity(0.25),
                    PSColors.primaryGreen.opacity(0.0)
                ]),
                center: UnitPoint(x: 0.8, y: 0.45),
                startRadius: 0,
                endRadius: 180
            )

            // Bottom teal accent
            RadialGradient(
                gradient: Gradient(colors: [
                    PSColors.accentTeal.opacity(0.2),
                    PSColors.accentTeal.opacity(0.0)
                ]),
                center: UnitPoint(x: 0.3, y: 0.9),
                startRadius: 0,
                endRadius: 150
            )
        }
    }

    // MARK: - Grain (finer 3pt stride + vignette)

    private var grainOverlay: some View {
        ZStack {
            Canvas { context, size in
                for y in stride(from: 0.0, through: size.height, by: 3) {
                    for x in stride(from: 0.0, through: size.width, by: 3) {
                        let randomOpacity = Double.random(in: 0.005...0.025)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                            with: .color(.white.opacity(randomOpacity))
                        )
                    }
                }
            }

            // Vignette
            RadialGradient(
                gradient: Gradient(colors: [.clear, Color.black.opacity(0.3)]),
                center: .center,
                startRadius: 120,
                endRadius: 360
            )
        }
    }

    // MARK: - Header (with streak badge)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Freshli Weekly Wrap")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.9))

            HStack(spacing: 8) {
                Text(data.weekDisplayRange)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                if data.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(PSColors.secondaryAmber)
                        Text("\(data.currentStreak)-day streak")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(PSColors.secondaryAmber.opacity(0.8))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero Stat (with WoW comparison)

    private var heroStatSection: some View {
        VStack(spacing: 8) {
            Text("\(data.totalItemsImpacted)")
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            Text("Items Saved This Week")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            if data.weekOverWeekChange != 0 {
                HStack(spacing: 4) {
                    Image(systemName: data.weekOverWeekChange > 0
                          ? "arrow.up.right"
                          : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(data.weekOverWeekLabel)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundColor(data.weekOverWeekChange > 0
                                 ? PSColors.primaryGreen
                                 : PSColors.expiredRed.opacity(0.8))
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Impact Row (with accent-colored pill borders)

    private var impactRow: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            HStack(spacing: 12) {
                ShareStatPill(
                    icon: "heart.fill",
                    value: "\(data.itemsShared + data.itemsDonated)",
                    label: "Meals Shared",
                    accentColor: PSColors.expiredRed.opacity(0.7)
                )
                ShareStatPill(
                    icon: "cloud.fill",
                    value: data.co2AvoidedDisplay + "kg",
                    label: "CO\u{2082} Saved",
                    accentColor: PSColors.accentTeal
                )
                ShareStatPill(
                    icon: "dollarsign.circle.fill",
                    value: data.moneySavedDisplay,
                    label: "Saved",
                    accentColor: PSColors.secondaryAmber
                )
            }
        }
    }

    // MARK: - Category Highlight Row

    private var categoryHighlight: some View {
        HStack(spacing: 8) {
            ForEach(Array(data.categoryBreakdown.prefix(3).enumerated()), id: \.offset) { _, item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(PSColors.categoryColor(for: item.0))
                        .frame(width: 6, height: 6)
                    Text("\(item.0.displayName) (\(item.1))")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Tree Illustration (static)

    private var treeIllustration: some View {
        ZStack {
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
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Freshli")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)

            Text("Track your food. Reduce waste. Save the planet.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Accent Color

    private var categoryAccentColor: Color {
        switch data.topCategorySaved {
        case .vegetables, .condiments: return PSColors.primaryGreen
        case .fruits, .bakery, .snacks: return Color(hex: 0xFBBF24)
        case .meat: return Color(hex: 0xEF5350)
        case .seafood: return PSColors.accentTeal
        case .dairy, .beverages: return Color(hex: 0x42A5F5)
        default: return PSColors.primaryGreen
        }
    }
}

// MARK: - Stat Pill (with accent border)

private struct ShareStatPill: View {
    let icon: String
    let value: String
    let label: String
    var accentColor: Color = .white

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)

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
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous)
                .stroke(accentColor.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    WeeklyWrapShareCard(viewModel: .preview)
        .padding()
        .background(Color.gray)
}

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

    // MARK: - Tree Illustration (static Canvas — matches the animated in-app tree)

    private var treeIllustration: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let ground = size.height * 0.88
            let g: CGFloat = 1.0 // fully grown for the static share card

            // Ground shadow
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 50, y: ground - 4, width: 100, height: 12)),
                with: .color(.white.opacity(0.06))
            )

            // Grass tufts
            let grassColors: [Color] = [Color(hex: 0x22C55E), Color(hex: 0x16A34A), Color(hex: 0x4ADE80)]
            let grassXs: [CGFloat] = [-35, -20, -8, 5, 18, 30]
            for (i, xOff) in grassXs.enumerated() {
                let h: CGFloat = [10, 14, 9, 12, 11, 13][i]
                var blade = Path()
                blade.move(to: CGPoint(x: cx + xOff - 1, y: ground))
                blade.addQuadCurve(
                    to: CGPoint(x: cx + xOff + 1, y: ground - h),
                    control: CGPoint(x: cx + xOff + 2, y: ground - h * 0.6)
                )
                blade.addLine(to: CGPoint(x: cx + xOff + 1, y: ground))
                ctx.fill(blade, with: .color(grassColors[i % 3].opacity(0.5)))
            }

            // Trunk (tapered bezier)
            let trunkBase = CGPoint(x: cx, y: ground)
            let trunkTop = CGPoint(x: cx, y: ground - 60)
            var trunk = Path()
            trunk.move(to: CGPoint(x: trunkBase.x - 6, y: trunkBase.y))
            trunk.addQuadCurve(
                to: CGPoint(x: trunkTop.x - 3, y: trunkTop.y),
                control: CGPoint(x: cx - 5, y: (trunkBase.y + trunkTop.y) / 2)
            )
            trunk.addLine(to: CGPoint(x: trunkTop.x + 3, y: trunkTop.y))
            trunk.addQuadCurve(
                to: CGPoint(x: trunkBase.x + 6, y: trunkBase.y),
                control: CGPoint(x: cx + 5, y: (trunkBase.y + trunkTop.y) / 2)
            )
            trunk.closeSubpath()
            ctx.fill(trunk, with: .linearGradient(
                Gradient(colors: [Color(hex: 0x5D4408), Color(hex: 0x8B6914), Color(hex: 0x6B5210)]),
                startPoint: CGPoint(x: cx - 8, y: ground),
                endPoint: CGPoint(x: cx + 8, y: ground)
            ))

            // Branches
            let branches: [(dx: CGFloat, dy: CGFloat)] = [(-18, -12), (14, -16), (-10, -26)]
            for (i, b) in branches.enumerated() {
                let start = CGPoint(x: cx + b.dx * 0.3, y: trunkTop.y + 10 - CGFloat(i) * 6)
                let end = CGPoint(x: cx + b.dx, y: trunkTop.y + b.dy)
                var bp = Path()
                bp.move(to: start)
                bp.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 3))
                ctx.stroke(bp, with: .color(Color(hex: 0x6B5210).opacity(0.7)), lineWidth: 2.0 - CGFloat(i) * 0.3)
            }

            // Canopy (organic multi-blob — static version of the animated canopy)
            let blobs: [(dx: CGFloat, dy: CGFloat, r: CGFloat, color: Color)] = [
                (-3, -32, 36, Color(hex: 0x15803D)),
                (14, -28, 30, Color(hex: 0x166534)),
                (-14, -36, 28, Color(hex: 0x14532D)),
                ( 0, -46, 34, Color(hex: 0x16A34A)),
                (16, -42, 26, Color(hex: 0x22C55E)),
                (-16, -44, 24, Color(hex: 0x15803D)),
                ( 5, -54, 24, Color(hex: 0x4ADE80)),
                (-8, -50, 20, Color(hex: 0x22C55E)),
                ( 0, -60, 18, Color(hex: 0x86EFAC).opacity(0.7)),
            ]
            for blob in blobs {
                let x = cx + blob.dx * g
                let y = trunkTop.y + blob.dy * g
                let r = blob.r * g
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 1.7)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [blob.color, blob.color.opacity(0.3)]),
                        center: CGPoint(x: x - r * 0.15, y: y - r * 0.2),
                        startRadius: 0,
                        endRadius: r
                    )
                )
            }

            // Scattered static leaves
            let leafPositions: [(dx: CGFloat, dy: CGFloat, rot: CGFloat, sz: CGFloat)] = [
                (-30, -35, 0.4, 5), (25, -50, -0.6, 4), (-15, -10, 0.8, 4.5), (32, -20, -0.3, 5)
            ]
            let leafColors: [Color] = [Color(hex: 0x4ADE80), Color(hex: 0x86EFAC), Color(hex: 0xFBBF24), PSColors.primaryGreen]
            for (i, lp) in leafPositions.enumerated() {
                ctx.drawLayer { inner in
                    inner.translateBy(x: cx + lp.dx, y: trunkTop.y + lp.dy)
                    inner.rotate(by: .radians(lp.rot))
                    inner.fill(
                        Path(ellipseIn: CGRect(x: -lp.sz / 2, y: -lp.sz / 4, width: lp.sz, height: lp.sz / 2)),
                        with: .color(leafColors[i].opacity(0.45))
                    )
                }
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

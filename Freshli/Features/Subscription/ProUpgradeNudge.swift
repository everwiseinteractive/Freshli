import SwiftUI

// MARK: - Pro Upgrade Nudge Card
// Contextual home-screen conversion card shown only to free users.
// Rotates through 3 value propositions on each dismissal.
// Dismissable for 7 days — respects user attention without abandoning conversion.

struct ProUpgradeNudge: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var showProSheet = false
    @AppStorage("proNudgeDismissedAt") private var dismissedAt: Double = 0
    @AppStorage("proNudgeVariant") private var variantRaw: Int = 0
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isDismissed: Bool {
        dismissedAt > 0 && Date().timeIntervalSince1970 - dismissedAt < 7 * 86_400
    }

    private var currentVariant: NudgeVariant {
        NudgeVariant.allCases[variantRaw % NudgeVariant.allCases.count]
    }

    var body: some View {
        if !subscriptionService.isProUser && !isDismissed {
            nudgeCard
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.97, anchor: .top)
                .onAppear {
                    let anim: Animation = reduceMotion
                        ? .easeOut(duration: 0.2)
                        : .spring(duration: 0.5, bounce: 0.25).delay(0.15)
                    withAnimation(anim) { appeared = true }
                }
                .sheet(isPresented: $showProSheet) {
                    FreshliProView()
                }
        }
    }

    // MARK: - Card Body

    private var nudgeCard: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            headerRow
            currentVariant.previewView
            ctaButton
        }
        .padding(PSSpacing.xl)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(PSColors.secondaryAmber.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: PSColors.secondaryAmber.opacity(0.1), radius: 20, y: 8)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
            removal:   .scale(scale: 0.94, anchor: .top).combined(with: .opacity)
        ))
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: PSSpacing.sm) {
            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                // Badge
                HStack(spacing: PSSpacing.xxs) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: PSLayout.scaledFont(10), weight: .black))
                    Text("FRESHLI+")
                        .font(.system(size: PSLayout.scaledFont(10), weight: .black))
                        .tracking(0.8)
                }
                .foregroundStyle(PSColors.secondaryAmber)

                // Headline
                Text(currentVariant.headline)
                    .font(.system(size: PSLayout.scaledFont(19), weight: .black))
                    .tracking(-0.4)
                    .foregroundStyle(PSColors.textPrimary)

                // Subheadline
                Text(currentVariant.subheadline)
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Dismiss button
            Button {
                PSHaptics.shared.selection()
                withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                    dismissedAt = Date().timeIntervalSince1970
                    variantRaw += 1
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PSColors.textTertiary)
                    .frame(width: 26, height: 26)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(Circle())
            }
        }
    }

    private var ctaButton: some View {
        Button {
            PSHaptics.shared.selection()
            showProSheet = true
        } label: {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "crown.fill")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                Text(currentVariant.ctaLabel)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .black))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, PSSpacing.xl)
            .padding(.vertical, PSSpacing.lg)
            .background(
                LinearGradient(
                    colors: [PSColors.primaryGreen, Color(hex: 0x059652)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            .shadow(color: PSColors.primaryGreen.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Nudge Variants

private enum NudgeVariant: CaseIterable {
    case aiChef, analytics, family

    var headline: String {
        switch self {
        case .aiChef:    return "Never waste food again"
        case .analytics: return "See your real impact"
        case .family:    return "Cook together, waste less"
        }
    }

    var subheadline: String {
        switch self {
        case .aiChef:
            return "AI Rescue Chef turns expiring items into delicious meals — instantly."
        case .analytics:
            return "Track savings, CO₂ avoided & waste trends with Advanced Analytics."
        case .family:
            return "Share your pantry with up to 6 family members. One household, zero waste."
        }
    }

    var ctaLabel: String {
        switch self {
        case .aiChef:    return "Try AI Rescue Chef Free"
        case .analytics: return "Unlock Full Analytics"
        case .family:    return "Start Family Sharing"
        }
    }

    @ViewBuilder
    var previewView: some View {
        switch self {
        case .aiChef:    AIChefPreview()
        case .analytics: AnalyticsPreview()
        case .family:    FamilyPreview()
        }
    }
}

// MARK: - Shared Lock Overlay

private struct LockOverlay: View {
    var body: some View {
        ZStack {
            Color.clear
            Image(systemName: "lock.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(PSSpacing.md)
                .background(.regularMaterial)
                .clipShape(Circle())
        }
    }
}

// MARK: - AI Chef Preview

private struct AIChefPreview: View {
    private let mockRecipes: [(name: String, emoji: String, time: String, color: Color)] = [
        ("Creamy Avocado Pasta",    "🥑", "12 min", Color(hex: 0x22C55E)),
        ("Lemon Chicken Stir-Fry",  "🍋", "18 min", Color(hex: 0xF59E0B)),
        ("Berry Smoothie Bowl",     "🫐",  "5 min", Color(hex: 0x8B5CF6)),
    ]

    var body: some View {
        VStack(spacing: PSSpacing.sm) {
            HStack(spacing: PSSpacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0x8B5CF6))
                Text("3 recipes for your expiring items")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)
                Spacer()
            }

            ForEach(Array(mockRecipes.enumerated()), id: \.offset) { _, recipe in
                HStack(spacing: PSSpacing.md) {
                    Text(recipe.emoji)
                        .font(.system(size: 22))
                        .frame(width: 38, height: 38)
                        .background(recipe.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipe.name)
                            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                            .foregroundStyle(PSColors.textPrimary)
                        Text(recipe.time)
                            .font(.system(size: PSLayout.scaledFont(11)))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                    Spacer()
                }
                .padding(PSSpacing.md)
                .background(PSColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            }
        }
        .blur(radius: 3.5)
        .overlay(LockOverlay())
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
    }
}

// MARK: - Analytics Preview

private struct AnalyticsPreview: View {
    private let bars: [(String, CGFloat)] = [
        ("Jan", 0.45), ("Feb", 0.62), ("Mar", 0.38),
        ("Apr", 0.78), ("May", 0.55), ("Jun", 0.88),
    ]

    var body: some View {
        VStack(spacing: PSSpacing.md) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("$127")
                        .font(.system(size: PSLayout.scaledFont(28), weight: .black))
                        .foregroundStyle(PSColors.textPrimary)
                    Text("saved this month")
                        .font(.system(size: PSLayout.scaledFont(12)))
                        .foregroundStyle(PSColors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                        Text("23%")
                            .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    }
                    .foregroundStyle(PSColors.primaryGreen)
                    Text("vs last month")
                        .font(.system(size: PSLayout.scaledFont(11)))
                        .foregroundStyle(PSColors.textTertiary)
                }
            }

            HStack(alignment: .bottom, spacing: PSSpacing.xs) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                    VStack(spacing: PSSpacing.xxs) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(PSColors.primaryGreen.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .frame(height: 64 * bar.1)
                        Text(bar.0)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
            .frame(height: 76)
        }
        .padding(PSSpacing.lg)
        .background(PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .blur(radius: 4)
        .overlay(LockOverlay())
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
    }
}

// MARK: - Family Preview

private struct FamilyPreview: View {
    private let members: [(String, Color)] = [
        ("J", Color(hex: 0x22C55E)),
        ("S", Color(hex: 0x3B82F6)),
        ("M", Color(hex: 0xF59E0B)),
        ("L", Color(hex: 0x8B5CF6)),
    ]

    var body: some View {
        HStack(spacing: PSSpacing.lg) {
            // Stacked avatars
            HStack(spacing: -12) {
                ForEach(Array(members.enumerated()), id: \.offset) { _, member in
                    Circle()
                        .fill(member.1)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(member.0)
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.white)
                        )
                        .overlay(Circle().strokeBorder(PSColors.surfaceCard, lineWidth: 2.5))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("4 members sharing")
                    .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text("31 items rescued together this month")
                    .font(.system(size: PSLayout.scaledFont(12)))
                    .foregroundStyle(PSColors.textSecondary)
            }
            Spacer()
        }
        .padding(PSSpacing.lg)
        .background(PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .blur(radius: 4)
        .overlay(LockOverlay())
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
    }
}

import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - Skeleton Dashboard View
// A glass-morphic skeleton placeholder that bridges the splash screen
// and the real Home dashboard. Uses the same refractive glass shader
// aesthetic so the transition feels like the splash screen "melts"
// into the dashboard structure.
//
// Architecture:
//   1. Skeleton shapes mimic HomeView's layout (header + cards)
//   2. Each shape uses metalLiquidGlassSurface for continuity with splash
//   3. gpuShimmer sweeps across to indicate loading
//   4. When real content is ready, shapes crossfade → real views
//
// Performance:
//   - drawingGroup() flattens the skeleton into a single GPU pass
//   - Shader quality adapts via ShaderQualityTier environment
//   - Reduces from 120Hz (splash) to 30Hz (skeleton) immediately
// ══════════════════════════════════════════════════════════════════

struct SkeletonDashboardView: View {
    /// Progress from 0→1 as the real dashboard loads.
    let loadProgress: CGFloat

    /// When true, the skeleton dissolves to reveal the real content beneath.
    let isRevealing: Bool

    @State private var shimmerPhase: CGFloat = -0.3
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.shaderQuality) private var quality

    var body: some View {
        VStack(spacing: PSSpacing.lg) {
            // Hero header skeleton — matches HomeView header proportions
            skeletonRect(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))

            // Quick stats row — 3 small cards
            HStack(spacing: PSSpacing.md) {
                skeletonRect(height: 80)
                skeletonRect(height: 80)
                skeletonRect(height: 80)
            }

            // Predictive surface card skeleton
            skeletonRect(height: 72)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))

            // Smart alert card skeleton
            skeletonRect(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))

            // Section header
            HStack {
                skeletonRect(width: 140, height: 16)
                Spacer()
                skeletonRect(width: 60, height: 16)
            }

            // Item cells — 3 pantry items
            ForEach(0..<3, id: \.self) { index in
                skeletonRect(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(
                        reduceMotion ? .none : FLMotion.springDefault.delay(Double(index) * 0.06),
                        value: appeared
                    )
            }

            Spacer()
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
        .padding(.top, PSSpacing.xl)
        .drawingGroup()
        .opacity(isRevealing ? 0 : 1)
        .scaleEffect(isRevealing ? 1.02 : 1.0)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.35), value: isRevealing)
        .onAppear {
            appeared = true
            if !reduceMotion {
                startShimmer()
            }
        }
    }

    // MARK: - Skeleton Rect

    private func skeletonRect(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
            .fill(PSColors.surfaceCard.opacity(0.6))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                    .fill(.white.opacity(0.04))
            )
            .metalShimmer(duration: 1.8, pause: 0.4)
    }

    // MARK: - Shimmer Loop

    private func startShimmer() {
        Task { @MainActor in
            while !Task.isCancelled {
                shimmerPhase = -0.3
                withAnimation(.easeInOut(duration: 1.6)) {
                    shimmerPhase = 1.3
                }
                try? await Task.sleep(for: .seconds(2.2))
            }
        }
    }
}

// Note: SplashTransitionModifier + .splashTransition() lives in FreshliSplashView.swift

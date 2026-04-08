import SwiftUI

// MARK: - Shimmer Loading Effect
// Premium shimmer placeholder for loading states.

struct PSShimmerView: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var phase: CGFloat = -1

    init(width: CGFloat? = nil, height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(PSColors.backgroundSecondary)
            .frame(maxWidth: width ?? .infinity)
            .frame(height: height)
            .overlay {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    LinearGradient(
                        colors: [
                            .clear,
                            PSColors.surfaceCard.opacity(0.7),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: w * 0.6)
                    .offset(x: phase * w * 1.6 - w * 0.3)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Pre-built Shimmer Layouts

/// Shimmer placeholder matching a pantry item card
struct PSShimmerItemCard: View {
    var body: some View {
        HStack(spacing: PSSpacing.lg) {
            PSShimmerView(width: PSLayout.categoryIconSize, height: PSLayout.categoryIconSize, cornerRadius: PSSpacing.radiusLg)

            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                PSShimmerView(height: 16, cornerRadius: 4)
                    .frame(maxWidth: 160)
                PSShimmerView(width: 100, height: 12, cornerRadius: 4)
            }

            Spacer()
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
    }
}

/// Shimmer placeholder matching an expiring-item pill
struct PSShimmerPill: View {
    var body: some View {
        VStack(spacing: PSSpacing.md) {
            PSShimmerView(width: PSLayout.emojiCircleSize, height: PSLayout.emojiCircleSize, cornerRadius: PSLayout.emojiCircleSize / 2)
            VStack(spacing: 4) {
                PSShimmerView(width: 80, height: 14, cornerRadius: 4)
                PSShimmerView(width: 50, height: 12, cornerRadius: 4)
            }
        }
        .padding(PSSpacing.lg)
        .frame(width: PSLayout.pillWidth)
        .background(PSColors.backgroundSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
    }
}

/// A stack of shimmer item cards
struct PSShimmerList: View {
    let count: Int

    init(count: Int = 4) {
        self.count = count
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                PSShimmerItemCard()
            }
        }
    }
}

/// Shimmer placeholder for a stat tile
struct PSShimmerStat: View {
    var body: some View {
        VStack(spacing: PSSpacing.sm) {
            PSShimmerView(width: 32, height: 32, cornerRadius: 8)
            PSShimmerView(width: 48, height: 28, cornerRadius: 4)
            PSShimmerView(width: 64, height: 12, cornerRadius: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }
}

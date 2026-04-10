import SwiftUI

// MARK: - Freshli Item Cell

/// A glassmorphism-styled pantry item cell with swipe-to-action gestures.
/// Uses SF Rounded typography, thin material backgrounds, and freshness-driven tinting.
struct FreshliItemCell: View {
    let item: SupabaseFreshliItem
    let namespace: Namespace.ID
    let onConsumed: () -> Void
    let onShare: () -> Void
    let onTap: () -> Void

    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipingRight = false
    @State private var isSwipingLeft = false
    @State private var showSwipeHint = false

    private let swipeThreshold: CGFloat = 100
    private let maxSwipe: CGFloat = 160

    private var expiryStatus: ExpiryStatus {
        ExpiryStatus.from(expiryDate: item.expiryDate)
    }

    private var category: FoodCategory {
        FoodCategory(rawValue: item.category.lowercased()) ?? .other
    }

    private var freshnessRatio: Double {
        let totalLife = item.expiryDate.timeIntervalSince(item.dateAdded)
        guard totalLife > 0 else { return 0 }
        let remaining = item.expiryDate.timeIntervalSince(Date())
        return max(0, min(1, remaining / totalLife))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Swipe background layers
            swipeBackgroundLayer

            // Main cell content
            cellContent
                .offset(x: swipeOffset)
                .gesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        // GPU-offload complex cell rendering to eliminate jitter in LazyVStack/List
        .drawingGroup(opaque: false, colorMode: .nonLinear)
    }

    // MARK: - Swipe Background

    private var swipeBackgroundLayer: some View {
        HStack(spacing: 0) {
            // Left background (Share) — revealed when swiping left
            HStack {
                Spacer()
                VStack(spacing: PSSpacing.xs) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: PSLayout.scaledFont(22), weight: .semibold))
                    Text("Share")
                        .font(.system(size: PSLayout.scaledFont(11), weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.trailing, PSSpacing.xl)
                .opacity(swipeOffset < -swipeThreshold * 0.5 ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PSColors.accentTeal.gradient)

            // Right background (Consumed) — revealed when swiping right
            HStack {
                VStack(spacing: PSSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(22), weight: .semibold))
                    Text("Consumed")
                        .font(.system(size: PSLayout.scaledFont(11), weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.leading, PSSpacing.xl)
                .opacity(swipeOffset > swipeThreshold * 0.5 ? 1 : 0)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PSColors.primaryGreen.gradient)
        }
    }

    // MARK: - Cell Content

    private var cellContent: some View {
        Button(action: onTap) {
            HStack(spacing: PSSpacing.md) {
                // Category emoji circle
                categoryIcon
                    .matchedGeometryEffect(id: "emoji_\(item.id)", in: namespace)

                // Item info
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text(item.name)
                        .font(.system(size: PSLayout.scaledFont(16), weight: .semibold, design: .rounded))
                        .foregroundStyle(PSColors.textPrimary)
                        .lineLimit(1)
                        .matchedGeometryEffect(id: "name_\(item.id)", in: namespace)

                    HStack(spacing: PSSpacing.sm) {
                        Text("\(String(format: "%.0f", item.quantity)) \(MeasurementUnit(rawValue: item.unit)?.displayName ?? item.unit)")
                            .font(.system(size: PSLayout.scaledFont(13), weight: .medium, design: .rounded))
                            .foregroundStyle(PSColors.textSecondary)

                        Text("·")
                            .foregroundStyle(PSColors.textTertiary)

                        Text(StorageLocation(rawValue: item.storageLocation)?.displayName ?? item.storageLocation)
                            .font(.system(size: PSLayout.scaledFont(13), weight: .medium, design: .rounded))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }

                Spacer()

                // Expiry indicator
                VStack(alignment: .trailing, spacing: PSSpacing.xs) {
                    freshnessGauge
                        .matchedGeometryEffect(id: "gauge_\(item.id)", in: namespace)

                    Text(expiryLabel)
                        .font(.system(size: PSLayout.scaledFont(11), weight: .semibold, design: .rounded))
                        .foregroundStyle(PSColors.expiryColor(for: expiryStatus))
                }
            }
            .padding(.horizontal, PSSpacing.lg)
            .padding(.vertical, PSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(glassMaterial)
            .matchedGeometryEffect(id: "card_\(item.id)", in: namespace)
        }
        .buttonStyle(GlassCellButtonStyle())
    }

    // MARK: - Category Icon

    private var categoryIcon: some View {
        Text(category.emoji)
            .font(.system(size: PSLayout.scaledFont(26)))
            .frame(width: PSLayout.scaled(48), height: PSLayout.scaled(48))
            .background(
                Circle()
                    .fill(PSColors.categoryColor(for: category).opacity(0.15))
            )
    }

    // MARK: - Freshness Gauge

    private var freshnessGauge: some View {
        ZStack {
            Circle()
                .stroke(PSColors.textTertiary.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: freshnessRatio)
                .stroke(
                    PSColors.expiryColor(for: expiryStatus),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 32, height: 32)
    }

    // MARK: - Expiry Label

    private var expiryLabel: String {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: now, to: item.expiryDate).day ?? 0

        if days < 0 {
            return "\(abs(days))d ago"
        } else if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Tomorrow"
        } else if days <= 7 {
            return "\(days)d left"
        } else {
            return item.expiryDate.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    // MARK: - Glass Material

    private var glassMaterial: some View {
        RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: PSColors.textPrimary.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let translation = value.translation.width

                withAnimation(.interactiveSpring()) {
                    // Apply rubber-band damping past threshold
                    if abs(translation) > maxSwipe {
                        let excess = abs(translation) - maxSwipe
                        let damped = maxSwipe + excess * 0.3
                        swipeOffset = translation > 0 ? damped : -damped
                    } else {
                        swipeOffset = translation
                    }
                }

                isSwipingRight = translation > swipeThreshold
                isSwipingLeft = translation < -swipeThreshold
            }
            .onEnded { value in
                let translation = value.translation.width

                if translation > swipeThreshold {
                    // Swipe right → Consumed — use Freshli Curve for satisfying completion
                    withAnimation(FLMotion.freshliCurve) {
                        swipeOffset = ScreenMetrics.bounds.width
                    }
                    PSHaptics.shared.mediumTap()
                    onConsumed()
                } else if translation < -swipeThreshold {
                    // Swipe left → Share — use Freshli Curve
                    withAnimation(FLMotion.freshliCurve) {
                        swipeOffset = -ScreenMetrics.bounds.width
                    }
                    PSHaptics.shared.lightTap()
                    onShare()
                } else {
                    // Spring back — use snappy spring for crisp rubber-band return
                    withAnimation(FLMotion.springSnappy) {
                        swipeOffset = 0
                    }
                }

                isSwipingRight = false
                isSwipingLeft = false
            }
    }
}

// MARK: - Glass Cell Button Style

struct GlassCellButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(reduceMotion ? .none : FLMotion.springQuick, value: configuration.isPressed)
    }
}

// MARK: - Confetti Particle View

/// Canvas-based confetti effect triggered on item consumption.
struct ConfettiView: View {
    let isActive: Bool

    @State private var particles: [InventoryConfettiParticle] = []
    @State private var animationProgress: Double = 0

    private let colors: [Color] = [
        PSColors.primaryGreen,
        PSColors.freshGreen,
        PSColors.warningAmber,
        PSColors.accentTeal,
        PSColors.infoBlue,
        .orange,
        .pink
    ]

    var body: some View {
        Canvas { context, size in
            for particle in particles {
                let progress = animationProgress
                let x = particle.startX + particle.velocityX * progress
                let y = particle.startY + particle.velocityY * progress + 300 * progress * progress
                let opacity = max(0, 1.0 - progress * 0.8)
                let rotation = Angle.degrees(particle.rotation * progress)
                let scale = max(0.3, 1.0 - progress * 0.5)

                guard x >= 0, x <= size.width, y <= size.height + 50 else { continue }

                context.opacity = opacity
                context.translateBy(x: x, y: y)
                context.rotate(by: rotation)
                context.scaleBy(x: scale, y: scale)

                let rect = CGRect(x: -particle.size / 2, y: -particle.size / 2,
                                  width: particle.size, height: particle.size)

                if particle.isCircle {
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(particle.color)
                    )
                } else {
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(particle.color)
                    )
                }

                // Reset transforms
                context.scaleBy(x: 1 / scale, y: 1 / scale)
                context.rotate(by: -rotation)
                context.translateBy(x: -x, y: -y)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if active {
                spawnParticles()
                withAnimation(.easeOut(duration: 2.0)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 0
                particles = []
            }
        }
    }

    private func spawnParticles() {
        animationProgress = 0
        let screenWidth = ScreenMetrics.bounds.width
        particles = (0..<30).map { _ in
            InventoryConfettiParticle(
                startX: screenWidth / 2 + CGFloat.random(in: -40...40),
                startY: CGFloat.random(in: -20...20),
                velocityX: CGFloat.random(in: -180...180),
                velocityY: CGFloat.random(in: -350 ... -100),
                rotation: Double.random(in: 180...720),
                size: CGFloat.random(in: 5...12),
                color: colors.randomElement() ?? PSColors.primaryGreen,
                isCircle: Bool.random()
            )
        }
    }
}

struct InventoryConfettiParticle {
    let startX: CGFloat
    let startY: CGFloat
    let velocityX: CGFloat
    let velocityY: CGFloat
    let rotation: Double
    let size: CGFloat
    let color: Color
    let isCircle: Bool
}

// MARK: - Preview

#Preview {
    @Previewable @Namespace var ns

    let mockItem = SupabaseFreshliItem(
        id: UUID(),
        userId: UUID(),
        name: "Organic Avocados",
        quantity: 3,
        unit: "pieces",
        category: "fruits",
        storageLocation: "fridge",
        expiryDate: Date().addingTimeInterval(86400 * 3),
        barcode: nil,
        notes: nil,
        isConsumed: false,
        isShared: false,
        isDonated: false,
        dateAdded: Date().addingTimeInterval(-86400 * 4),
        updatedAt: nil,
        isOpened: false,
        imagePath: nil,
        status: nil,
        purchaseDate: nil
    )

    FreshliItemCell(
        item: mockItem,
        namespace: ns,
        onConsumed: {},
        onShare: {},
        onTap: {}
    )
    .padding()
    .background(PSColors.backgroundPrimary)
}

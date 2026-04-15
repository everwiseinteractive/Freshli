import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - FLGlassCard (Organism)
// The universal card surface for the entire app. Every card — from
// pantry items to impact stats to community listings — uses this
// single organism. Ensures visual unity across all screens.
//
// Usage:
//   FLGlassCard { ... }                          // default card
//   FLGlassCard(.hero, tint: .green) { ... }     // hero card
//   FLGlassCard(.subtle) { ... }                 // inline card
// ══════════════════════════════════════════════════════════════════

struct FLGlassCard<Content: View>: View {
    let intensity: FLGlassIntensity
    let tint: FLGlassTint
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        _ intensity: FLGlassIntensity = .card,
        tint: FLGlassTint = .none,
        padding: CGFloat = PSSpacing.lg,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.intensity = intensity
        self.tint = tint
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .flGlass(intensity, tint: tint)
    }
}

// MARK: - FLGradientCard (Organism)
// Full-bleed gradient card for mission-critical surfaces (streak strip,
// collective wave, impact hero). Uses a gradient background instead of
// glass for maximum visual impact.

struct FLGradientCard<Content: View>: View {
    let colors: [Color]
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        colors: [Color],
        cornerRadius: CGFloat = PSSpacing.radiusXxl,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: colors.first?.opacity(0.3) ?? .clear, radius: 16, y: 8)
    }
}

// MARK: - FLNavigableCard
// A glass card that navigates to a destination when tapped.

struct FLNavigableCard<Destination: View, Content: View>: View {
    let destination: Destination
    let intensity: FLGlassIntensity
    let tint: FLGlassTint
    @ViewBuilder let content: () -> Content

    init(
        destination: Destination,
        intensity: FLGlassIntensity = .card,
        tint: FLGlassTint = .none,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.destination = destination
        self.intensity = intensity
        self.tint = tint
        self.content = content
    }

    var body: some View {
        NavigationLink(destination: destination) {
            content()
                .padding(PSSpacing.lg)
                .flGlass(intensity, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

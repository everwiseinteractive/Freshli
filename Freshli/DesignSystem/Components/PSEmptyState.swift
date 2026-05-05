import SwiftUI

// Figma: EmptyState — rounded-3xl bg-neutral-50/50 border border-neutral-200/50
// w-24 h-24 bg-white rounded-full icon circle, text-xl font-bold title

struct PSEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        VStack(spacing: PSSpacing.xl) {
            // Figma: w-24 h-24 bg-white rounded-full shadow-sm
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(PSColors.textTertiary)
                .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.5), isActive: appeared)
                .frame(width: 96, height: 96)
                .background(PSColors.surfaceCard)
                .clipShape(Circle())
                .elevation(.z1)
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: PSSpacing.sm) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260)
                    .lineSpacing(4)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            if let actionTitle, let action {
                PSButton(
                    title: actionTitle,
                    style: .secondary,
                    size: .medium,
                    isFullWidth: false,
                    action: action
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }
        }
        .padding(PSSpacing.xxxl)
        .frame(maxWidth: .infinity)
        .background(PSColors.backgroundSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(PSColors.border.opacity(0.5), lineWidth: 1)
        )
        .onAppear {
            withAnimation(PSMotion.springBouncy.delay(0.1)) {
                appeared = true
            }
            PSHaptics.shared.softBounce()
        }
    }
}

#Preview("Single action") {
    PSEmptyState(
        icon: "magnifyingglass",
        title: "Your Pantry is Empty",
        message: "Start adding ingredients to keep track of what you have and get recipe suggestions.",
        actionTitle: "Add Ingredient",
        action: {}
    )
    .padding()
}

// MARK: - PSEmptyStateRich
//
// A richer empty state for surfaces (Pantry, Shopping, Inventory) where
// the user has multiple distinct ways to populate content. Renders the
// same hero icon + title + message as `PSEmptyState`, then a stacked
// set of 2–3 labelled action rows with their own icons, descriptions,
// and tap targets.
//
// Use this whenever the on-screen instructions need to teach the user
// *how* to add their first item — a generic "Add Ingredient" button on
// an empty pantry doesn't tell the user that they can scan a barcode,
// scan a receipt, or use Smart Add. The richer empty state surfaces all
// three with one-line explanations of what each does.

struct PSEmptyStateAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void
}

struct PSEmptyStateRich: View {
    let icon: String
    let title: String
    let message: String
    let actions: [PSEmptyStateAction]

    @State private var appeared = false

    var body: some View {
        VStack(spacing: PSSpacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(PSColors.textTertiary)
                .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.5), isActive: appeared)
                .frame(width: 96, height: 96)
                .background(PSColors.surfaceCard)
                .clipShape(Circle())
                .elevation(.z1)
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: PSSpacing.sm) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)
                    .lineSpacing(4)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            VStack(spacing: PSSpacing.sm) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    Button(action: action.action) {
                        HStack(alignment: .center, spacing: PSSpacing.md) {
                            Image(systemName: action.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(action.tint)
                                .frame(width: 44, height: 44)
                                .background(action.tint.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(PSColors.textPrimary)
                                Text(action.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(PSColors.textSecondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PSColors.textTertiary)
                        }
                        .padding(.horizontal, PSSpacing.md)
                        .padding(.vertical, PSSpacing.sm)
                        .background(PSColors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                                .strokeBorder(PSColors.border.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(action.title). \(action.subtitle)")
                    .accessibilityHint(String(localized: "Opens the \(action.title) flow"))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                    .animation(
                        PSMotion.springBouncy.delay(0.15 + Double(index) * 0.08),
                        value: appeared
                    )
                }
            }
            .frame(maxWidth: 420)
        }
        .padding(PSSpacing.xxxl)
        .frame(maxWidth: .infinity)
        .background(PSColors.backgroundSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(PSColors.border.opacity(0.5), lineWidth: 1)
        )
        .onAppear {
            withAnimation(PSMotion.springBouncy.delay(0.1)) {
                appeared = true
            }
            PSHaptics.shared.softBounce()
        }
    }
}

#Preview("Multi-action — Pantry empty state") {
    PSEmptyStateRich(
        icon: "refrigerator",
        title: "Your pantry is empty",
        message: "Add items the way that's easiest for you. Freshli will track expiry dates and suggest recipes for what you have.",
        actions: [
            .init(icon: "barcode.viewfinder", title: "Scan a barcode", subtitle: "Point your camera at any product barcode — we'll fill in the details.", tint: .green, action: {}),
            .init(icon: "doc.text.viewfinder", title: "Scan a receipt", subtitle: "Take a photo of your shopping receipt to add multiple items at once.", tint: .blue, action: {}),
            .init(icon: "keyboard", title: "Type manually", subtitle: "Search our food database or enter your own item from scratch.", tint: .orange, action: {}),
        ]
    )
    .padding()
}

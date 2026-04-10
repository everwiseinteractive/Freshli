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
                .frame(width: 96, height: 96)
                .background(PSColors.surfaceCard)
                .clipShape(Circle())
                .shadow(color: PSColors.textPrimary.opacity(0.04), radius: 8, x: 0, y: 4)
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
        }
    }
}

#Preview {
    PSEmptyState(
        icon: "magnifyingglass",
        title: "Your Pantry is Empty",
        message: "Start adding ingredients to keep track of what you have and get recipe suggestions.",
        actionTitle: "Add Ingredient",
        action: {}
    )
    .padding()
}

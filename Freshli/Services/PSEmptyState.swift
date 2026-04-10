import SwiftUI

// MARK: - PSEmptyState
/// Reusable empty state component

struct PSEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: PSSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(PSColors.textTertiary.opacity(0.5))
            
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(PSColors.textPrimary)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PSSpacing.xl)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, PSSpacing.xl)
                        .padding(.vertical, PSSpacing.md)
                        .background(PSColors.primaryGreen)
                        .clipShape(Capsule())
                }
                .padding(.top, PSSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.hero)
    }
}

#Preview {
    PSEmptyState(
        icon: "tray",
        title: "No Items Yet",
        message: "Add your first item to get started tracking your pantry",
        actionTitle: "Add Item",
        action: { print("Add item tapped") }
    )
}

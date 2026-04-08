import SwiftUI

struct PSSectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                Text(title)
                    .font(PSTypography.title3)
                    .foregroundStyle(PSColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                }
            }

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(PSTypography.subheadlineMedium)
                        .foregroundStyle(PSColors.primaryGreen)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        PSSectionHeader(title: "Expiring Soon")
        PSSectionHeader(title: "Your Pantry", subtitle: "12 items", actionTitle: "See All", action: {})
    }
    .padding()
}

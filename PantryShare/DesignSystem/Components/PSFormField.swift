import SwiftUI

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text(label)
                .font(PSTypography.caption1Medium)
                .foregroundStyle(PSColors.textSecondary)
            content()
        }
    }
}

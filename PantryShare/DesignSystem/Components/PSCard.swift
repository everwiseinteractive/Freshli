import SwiftUI

struct PSCard<Content: View>: View {
    var padding: CGFloat = PSSpacing.cardPadding
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.cardSpacing) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct PSCompactCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: PSSpacing.md) {
            content()
        }
        .padding(PSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct PSActionCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    var iconColor: Color = PSColors.primaryGreen
    var showChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PSSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))

                VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                    Text(title)
                        .font(PSTypography.calloutMedium)
                        .foregroundStyle(PSColors.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PSColors.textTertiary)
                }
            }
            .padding(PSSpacing.cardPadding)
            .cardStyle()
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        PSCard {
            Text("Card Title").font(PSTypography.headline)
            Text("Card content goes here").font(PSTypography.body)
        }

        PSActionCard(
            icon: "barcode.viewfinder",
            title: "Scan Barcode",
            subtitle: "Add items quickly",
            action: {}
        )
    }
    .padding()
}

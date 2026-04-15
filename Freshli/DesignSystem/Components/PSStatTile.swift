import SwiftUI

struct PSStatTile: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = PSColors.primaryGreen
    var animateValue: Bool = true

    @State private var appeared = false

    var body: some View {
        VStack(spacing: PSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
                .scaleEffect(appeared ? 1 : 0.5)
                .symbolEffect(.bounce, value: appeared)

            Text(value)
                .font(PSTypography.statMedium)
                .foregroundStyle(PSColors.textPrimary)
                .opacity(appeared ? 1 : 0)

            Text(label)
                .font(PSTypography.caption1)
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.lg)
        .cardStyle()
        .onAppear {
            guard animateValue else {
                appeared = true
                return
            }
            withAnimation(PSMotion.springBouncy.delay(0.1)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct PSStatTileRow: View {
    let stats: [(icon: String, value: String, label: String, tint: Color)]

    var body: some View {
        HStack(spacing: PSSpacing.md) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                PSStatTile(
                    icon: stat.icon,
                    value: stat.value,
                    label: stat.label,
                    tint: stat.tint
                )
                .staggeredAppearance(index: index)
            }
        }
    }
}

#Preview {
    PSStatTileRow(stats: [
        (icon: "leaf.fill", value: "24", label: "Items Saved", tint: PSColors.freshGreen),
        (icon: "dollarsign.circle.fill", value: "$84", label: "Money Saved", tint: PSColors.secondaryAmber),
        (icon: "cloud.fill", value: "60kg", label: "CO₂ Avoided", tint: PSColors.accentTeal),
    ])
    .padding()
}

import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - FLStatRow (Molecule)
// Horizontal stat display: icon + big value + label.
// Used inside wave cards, impact dashboards, stat grids.
//
// Usage:
//   FLStatRow(icon: "cloud.fill", value: "2.4kg", label: "CO₂ avoided")
// ══════════════════════════════════════════════════════════════════

struct FLStatRow: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: FLTextColor
    let valueColor: FLTextColor

    init(
        icon: String,
        value: String,
        label: String,
        iconColor: FLTextColor = .onDark,
        valueColor: FLTextColor = .onDark
    ) {
        self.icon = icon
        self.value = value
        self.label = label
        self.iconColor = iconColor
        self.valueColor = valueColor
    }

    var body: some View {
        VStack(spacing: PSSpacing.xxs) {
            FLIcon(icon, .medium, color: iconColor)
            FLText(value, .callout, color: valueColor)
            FLText(label, .footnote, color: .custom(.white.opacity(0.7)))
        }
    }
}

// MARK: - FLStatPill (Molecule)
// Compact pill showing a count or label, used for badges and counters.

struct FLStatPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: PSLayout.scaledFont(12), weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, PSSpacing.sm)
            .padding(.vertical, PSSpacing.xxs)
            .background(color)
            .clipShape(Capsule())
    }
}

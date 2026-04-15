import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - FLSectionHeader (Molecule)
// Consistent section header used across all dashboard screens.
// Icon + overline + title. No background boxes on the icon.
//
// Generic trailing slot — no AnyView type erasure (Swift 6 clean).
//
// Usage:
//   FLSectionHeader("Expiring Soon", overline: "ALERTS", icon: "exclamationmark.triangle.fill", color: .amber)
//   FLSectionHeader("Stats", icon: "chart.bar") { Button("See All") { } }
// ══════════════════════════════════════════════════════════════════

struct FLSectionHeader<Trailing: View>: View {
    let title: String
    let overline: String?
    let icon: String?
    let iconColor: FLTextColor
    let trailing: Trailing

    init(
        _ title: String,
        overline: String? = nil,
        icon: String? = nil,
        iconColor: FLTextColor = .green,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.overline = overline
        self.icon = icon
        self.iconColor = iconColor
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: PSSpacing.sm) {
            if let icon {
                FLIcon(icon, .large, color: iconColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                if let overline {
                    FLText(overline, .sectionLabel, color: .secondary)
                }
                FLText(title, .headline)
            }

            Spacer(minLength: 0)

            trailing
        }
    }
}

// MARK: - Convenience (no trailing)

extension FLSectionHeader where Trailing == EmptyView {
    init(
        _ title: String,
        overline: String? = nil,
        icon: String? = nil,
        iconColor: FLTextColor = .green
    ) {
        self.init(title, overline: overline, icon: icon, iconColor: iconColor) {
            EmptyView()
        }
    }
}

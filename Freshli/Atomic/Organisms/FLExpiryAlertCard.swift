import SwiftUI
import SwiftData

// ══════════════════════════════════════════════════════════════════
// MARK: - FLExpiryAlertCard (Organism)
// Compact expiry alert card for the home dashboard. Shows items
// expiring today/tomorrow with a warm amber gradient.
// ══════════════════════════════════════════════════════════════════

struct FLExpiryAlertCard: View {
    let expiringCount: Int
    let expiredCount: Int

    private var totalUrgent: Int { expiringCount + expiredCount }

    var body: some View {
        if totalUrgent > 0 {
            NavigationLink(destination: ExpiryAlertsView()) {
                FLGradientCard(
                    colors: expiredCount > 0
                        ? [Color(hex: 0x991B1B), Color(hex: 0xB91C1C)]
                        : [Color(hex: 0x92400E), Color(hex: 0xB45309)]
                ) {
                    HStack(spacing: PSSpacing.lg) {
                        // Warning icon — no background box
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: PSLayout.scaledFont(26), weight: .bold))
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse)

                        VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                            FLText(
                                String(localized: "\(totalUrgent) item\(totalUrgent == 1 ? "" : "s") need attention"),
                                .headline,
                                color: .onDark
                            )
                            FLText(
                                String(localized: "Rescue them before they go to waste"),
                                .subheadline,
                                color: .custom(.white.opacity(0.8))
                            )
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, PSSpacing.xl)
                    .padding(.vertical, PSSpacing.lg)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

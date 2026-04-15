import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - FLWaveCard (Organism)
// The collective rescue wave card — the emotional heart of the home
// dashboard. Shows live global rescue data. Uses gradient background,
// no background boxes on any icon.
// ══════════════════════════════════════════════════════════════════

struct FLWaveCard: View {
    @State private var service = CollectiveImpactService.shared

    var body: some View {
        NavigationLink(destination: CollectiveWaveView()) {
            FLGradientCard(
                colors: [
                    FreshliBrand.missionAccentLight,
                    FreshliBrand.missionAccent,
                    FreshliBrand.planetBlue.opacity(0.9)
                ]
            ) {
                VStack(alignment: .leading, spacing: PSSpacing.lg) {
                    header
                    heroNumber
                    miniStats
                }
                .padding(PSSpacing.xl)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: PSSpacing.sm) {
            // Globe icon — NO background circle
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: PSLayout.scaledFont(20)))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeat(.periodic(delay: 3.5)))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: PSSpacing.xs) {
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                        .opacity(0.9)
                    FLText("LIVE WAVE", .sectionLabel, color: .custom(.white.opacity(0.85)))
                }
                FLText(
                    String(localized: "Right now, worldwide"),
                    .footnote,
                    color: .custom(.white.opacity(0.7))
                )
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Hero Number

    private var heroNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: PSSpacing.sm) {
            Text(service.rescueCountDisplay)
                .font(.system(size: PSLayout.scaledFont(48), weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            FLText(
                String(localized: "people rescued food in the last hour"),
                .subheadline,
                color: .custom(.white.opacity(0.85))
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Mini Stats

    private var miniStats: some View {
        HStack(spacing: PSSpacing.lg) {
            FLStatRow(
                icon: "cloud.fill",
                value: service.hourlyCO2Display,
                label: String(localized: "CO₂ avoided")
            )

            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(width: 1, height: PSLayout.scaled(36))

            FLStatRow(
                icon: "fork.knife",
                value: "\(service.hourlyMealsFed)",
                label: String(localized: "meals fed")
            )
        }
    }
}

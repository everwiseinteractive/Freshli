import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - FLStreakStrip (Organism)
// The earned-moment streak display. Warm gradient card with flame
// icon, day dots, and motivational copy. No background boxes on icons.
// ══════════════════════════════════════════════════════════════════

struct FLStreakStrip: View {
    let streak: Int

    private var hasStreak: Bool { streak > 0 }

    var body: some View {
        FLGradientCard(
            colors: hasStreak
                ? [Color(hex: 0x14532D), Color(hex: 0x166534), Color(hex: 0x15803D)]
                : [Color(hex: 0x1C1C1E), Color(hex: 0x2C2C2E)]
        ) {
            HStack(spacing: PSSpacing.md) {
                // Flame icon — no background box, just the symbol
                Image(systemName: "flame.fill")
                    .font(.system(size: PSLayout.scaledFont(22), weight: .bold))
                    .foregroundStyle(
                        hasStreak
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Color(hex: 0xFBBF24), Color(hex: 0xF97316)],
                                    startPoint: .top, endPoint: .bottom
                                )
                              )
                            : AnyShapeStyle(Color.white.opacity(0.4))
                    )
                    .symbolEffect(.pulse, options: .repeat(.periodic(delay: 3.0)), isActive: hasStreak)

                VStack(alignment: .leading, spacing: 2) {
                    FLText(
                        hasStreak
                            ? String(localized: "\(streak)-day rescue streak")
                            : String(localized: "Begin your rescue journey"),
                        .callout,
                        color: .onDark
                    )
                    FLText(
                        hasStreak
                            ? String(localized: "Every rescue counts toward a better planet")
                            : String(localized: "One item saved today starts a lasting habit"),
                        .footnote,
                        color: .custom(.white.opacity(0.7))
                    )
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 7-day ring of dots
                dayDots
            }
            .padding(.horizontal, PSSpacing.lg)
            .padding(.vertical, PSSpacing.md)
        }
    }

    // MARK: - Day Dots

    private var dayDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { day in
                Circle()
                    .fill(
                        day < streak
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Color(hex: 0xFBBF24), Color(hex: 0xF97316)],
                                    startPoint: .top, endPoint: .bottom
                                )
                              )
                            : AnyShapeStyle(Color.white.opacity(0.22))
                    )
                    .frame(width: 7, height: 7)
                    .shadow(color: day < streak ? Color.orange.opacity(0.5) : .clear, radius: 3)
            }
        }
    }
}

import SwiftUI

// MARK: - Collective Wave View
// Full-screen view of the live global rescue wave. Shows every rescue
// as it happens worldwide, turning Freshli's mission into something
// felt in real time.

struct CollectiveWaveView: View {
    @State private var service = CollectiveImpactService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                heroHeader
                statsGrid
                liveFeedSection
                missionFooter
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.xl)
        }
        .contentMargins(.bottom, PSLayout.scaled(120), for: .scrollContent)
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Live Rescue Wave"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(spacing: PSSpacing.lg) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [FreshliBrand.missionAccentLight.opacity(0.2), FreshliBrand.planetBlue.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: PSLayout.scaled(100), height: PSLayout.scaled(100))
                    .blur(radius: 8)
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: PSLayout.scaledFont(52)))
                    .foregroundStyle(FreshliBrand.missionAccent)
                    .symbolEffect(.pulse, options: .repeat(.periodic(delay: 3.0)))
            }

            VStack(spacing: PSSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: PSSpacing.sm) {
                    Text(service.rescueCountDisplay)
                        .font(.system(size: PSLayout.scaledFont(64), weight: .black, design: .rounded))
                        .foregroundStyle(FreshliBrand.missionAccent)
                        .contentTransition(.numericText())
                }
                Text(String(localized: "people rescued food in the last hour"))
                    .font(.system(size: PSLayout.scaledFont(15), weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Text(FreshliBrand.tagline)
                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal, PSSpacing.xl)
        }
        .padding(.top, PSSpacing.md)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: PSSpacing.md) {
            statTile(
                icon: "cloud.fill",
                color: FreshliBrand.planetBlue,
                value: service.hourlyCO2Display,
                label: String(localized: "CO₂ avoided\nthis hour")
            )
            statTile(
                icon: "fork.knife",
                color: FreshliBrand.peoplePink,
                value: "\(service.hourlyMealsFed)",
                label: String(localized: "meals fed\nthis hour")
            )
            statTile(
                icon: "leaf.fill",
                color: FreshliBrand.missionAccent,
                value: totalItemsDisplay,
                label: String(localized: "total rescues\nsince launch")
            )
        }
    }

    private var totalItemsDisplay: String {
        let total = service.totalItemsRescued
        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000)
        }
        if total >= 1_000 {
            return String(format: "%.1fk", Double(total) / 1_000)
        }
        return "\(total)"
    }

    private func statTile(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: PSSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(20)))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: PSLayout.scaledFont(20), weight: .black, design: .rounded))
                .foregroundStyle(PSColors.textPrimary)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: PSLayout.scaledFont(10), weight: .semibold))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.lg)
        .padding(.horizontal, PSSpacing.sm)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Live Feed

    private var liveFeedSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.xs) {
                Circle()
                    .fill(FreshliBrand.missionAccent)
                    .frame(width: 8, height: 8)
                    .opacity(0.8)
                Text(String(localized: "LIVE FEED"))
                    .font(.system(size: PSLayout.scaledFont(11), weight: .black))
                    .foregroundStyle(PSColors.textSecondary)
                    .tracking(0.8)
                Spacer()
                Text(String(localized: "updates every 20s"))
                    .font(.system(size: PSLayout.scaledFont(10), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
            }

            VStack(spacing: PSSpacing.sm) {
                ForEach(service.recentFeed) { event in
                    feedRow(event)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
    }

    private func feedRow(_ event: CollectiveRescueEvent) -> some View {
        HStack(spacing: PSSpacing.md) {
            // Tiny photo avatar deterministically hashed
            let avatarIdx = (abs(event.displayName.hashValue) % 5) + 1
            Image("avatar_\(avatarIdx)")
                .resizable()
                .scaledToFill()
                .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(FreshliBrand.missionAccent.opacity(0.3), lineWidth: 1.5)
                )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: PSSpacing.xxs) {
                    Text(event.displayName)
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text("·")
                        .foregroundStyle(PSColors.textTertiary)
                    Text(event.cityName)
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                Text(String(localized: "rescued \(event.itemName)"))
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
            }
            Spacer()
            Text(event.timeLabel)
                .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                .foregroundStyle(PSColors.textTertiary)
        }
        .padding(.horizontal, PSSpacing.md)
        .padding(.vertical, PSSpacing.sm)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Mission Footer

    private var missionFooter: some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: "heart.fill")
                .font(.system(size: PSLayout.scaledFont(16)))
                .foregroundStyle(FreshliBrand.peoplePink)
            Text(FreshliBrand.mission)
                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(PSSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(FreshliBrand.missionAccent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }
}

#Preview {
    NavigationStack { CollectiveWaveView() }
}

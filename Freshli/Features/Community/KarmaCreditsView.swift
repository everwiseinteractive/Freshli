import SwiftUI

// MARK: - Karma Credits View
// Balance + earn/spend history for the Food-as-Currency system.

struct KarmaCreditsView: View {
    @State private var service = KarmaCreditService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                balanceCard
                statsRow
                howItWorksCard
                transactionHistory
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle("Karma Credits")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Balance Hero

    private var balanceCard: some View {
        VStack(spacing: PSSpacing.lg) {
            Text("YOUR BALANCE")
                .font(.system(size: PSLayout.scaledFont(11), weight: .black))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(1.5)

            HStack(alignment: .firstTextBaseline, spacing: PSSpacing.xs) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: PSLayout.scaledFont(44)))
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(service.balance)")
                    .font(.system(size: PSLayout.scaledFont(64), weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .compositingGroup()
            }

            Text("credits available to request ingredients")
                .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.xxl)
        .background(LinearGradient(
            colors: [Color(hex: 0x8B5CF6), Color(hex: 0xEC4899).opacity(0.9)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .shadow(color: Color(hex: 0x8B5CF6).opacity(0.35), radius: 20, y: 8)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: PSSpacing.md) {
            statCard(icon: "arrow.up.circle.fill", color: PSColors.primaryGreen,
                     value: "\(service.itemsShared)", label: "Given")
            statCard(icon: "arrow.down.circle.fill", color: Color(hex: 0x3B82F6),
                     value: "\(service.itemsReceived)", label: "Received")
            statCard(icon: "equal.circle.fill", color: PSColors.secondaryAmber,
                     value: "\(service.totalGiven - service.totalReceived)", label: "Net")
        }
    }

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: PSSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(22)))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: PSLayout.scaledFont(20), weight: .black, design: .rounded))
                .foregroundStyle(PSColors.textPrimary)
            Text(label)
                .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                .foregroundStyle(PSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .strokeBorder(PSColors.borderLight, lineWidth: 1))
    }

    // MARK: - How It Works

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text("How It Works")
                .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                .foregroundStyle(PSColors.textSecondary)
                .textCase(.uppercase).tracking(0.5)

            howItWorksRow(number: "1", title: "Give food", subtitle: "Earn 5 credits per shared item", color: PSColors.primaryGreen)
            howItWorksRow(number: "2", title: "Build balance", subtitle: "Bank credits for when you need them", color: Color(hex: 0x8B5CF6))
            howItWorksRow(number: "3", title: "Request ingredients", subtitle: "Ping neighbours — no guilt, no waste", color: Color(hex: 0x3B82F6))
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
            .strokeBorder(PSColors.borderLight, lineWidth: 1))
    }

    private func howItWorksRow(number: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: PSSpacing.md) {
            Text(number)
                .font(.system(size: PSLayout.scaledFont(16), weight: .black, design: .rounded))
                .foregroundStyle(color)
                .frame(width: PSLayout.scaled(32), height: PSLayout.scaled(32))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Transaction History

    private var transactionHistory: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text("Recent Activity")
                .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                .foregroundStyle(PSColors.textSecondary)
                .textCase(.uppercase).tracking(0.5)

            if service.transactions.isEmpty {
                Text("No activity yet. Share your first item to start earning credits.")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
                    .padding(PSSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(PSColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            } else {
                ForEach(service.transactions.prefix(12)) { tx in
                    transactionRow(tx)
                }
            }
        }
    }

    private func transactionRow(_ tx: KarmaTransaction) -> some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: tx.type.icon)
                .font(.system(size: PSLayout.scaledFont(20)))
                .foregroundStyle(tx.type.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(tx.itemName)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                HStack(spacing: PSSpacing.xxs) {
                    Text(tx.type.rawValue)
                        .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                        .foregroundStyle(tx.type.color)
                    if let other = tx.otherParty {
                        Text("• \(other)")
                            .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
            Spacer()
            Text(tx.amount > 0 ? "+\(tx.amount)" : "\(tx.amount)")
                .font(.system(size: PSLayout.scaledFont(16), weight: .black, design: .rounded))
                .foregroundStyle(tx.amount > 0 ? PSColors.primaryGreen : PSColors.expiredRed)
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .strokeBorder(PSColors.borderLight, lineWidth: 1))
    }
}

#Preview {
    NavigationStack { KarmaCreditsView() }
}

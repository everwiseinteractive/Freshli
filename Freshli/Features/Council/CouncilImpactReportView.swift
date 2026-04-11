import SwiftUI
import SwiftData

// MARK: - Council Impact Report View
// Anonymised postcode-level waste data for local councils. Shown to users
// so they can see their footprint and opt in to data sharing.

struct CouncilImpactReportView: View {
    @Query private var items: [FreshliItem]
    @State private var binLogService = BinLogService.shared
    @State private var report: CouncilReport?
    @State private var postcode = "SW1A 1AA"

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                hero
                if let report = report {
                    headlineCard(report)
                    comparisonCard(report)
                    topCategoriesCard(report)
                    reasonsCard(report)
                    shareDataCard
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle("Council Impact")
        .navigationBarTitleDisplayMode(.inline)
        .task { generate() }
    }

    private var hero: some View {
        VStack(spacing: PSSpacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x3B82F6).opacity(0.15), Color(hex: 0x06B6D4).opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: PSLayout.scaled(80), height: PSLayout.scaled(80))
                Image(systemName: "building.columns.fill")
                    .font(.system(size: PSLayout.scaledFont(34)))
                    .foregroundStyle(Color(hex: 0x3B82F6))
            }
            VStack(spacing: PSSpacing.xs) {
                Text("Council Impact Report")
                    .font(.system(size: PSLayout.scaledFont(20), weight: .black, design: .rounded))
                Text("Anonymised waste data helps your council plan better collections and reduction campaigns.")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }

    private func headlineCard(_ report: CouncilReport) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                    Text("POSTCODE \(report.postcode)")
                        .font(.system(size: PSLayout.scaledFont(11), weight: .black))
                        .foregroundStyle(.white.opacity(0.7)).tracking(1.2)
                    Text(report.reportPeriod)
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: PSLayout.scaledFont(32)))
                    .foregroundStyle(.white.opacity(0.25))
            }

            HStack(alignment: .firstTextBaseline, spacing: PSSpacing.xs) {
                Text("\(report.totalWastedItems)")
                    .font(.system(size: PSLayout.scaledFont(56), weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 0) {
                    Text("items")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    Text("wasted")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: PSSpacing.lg) {
                headlineStat(value: String(format: "%.1fkg", report.totalWastedKg), label: "By weight")
                Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: PSLayout.scaled(32))
                headlineStat(value: "£\(String(format: "%.0f", report.totalFinancialImpact))", label: "Financial")
                Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: PSLayout.scaled(32))
                headlineStat(value: String(format: "%.0fkg", report.estimatedCO2Impact), label: "CO₂")
            }
        }
        .padding(PSSpacing.xl)
        .background(LinearGradient(
            colors: [Color(hex: 0x3B82F6), Color(hex: 0x06B6D4).opacity(0.9)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .shadow(color: Color(hex: 0x3B82F6).opacity(0.3), radius: 20, y: 8)
    }

    private func headlineStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: PSLayout.scaledFont(16), weight: .black))
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: PSLayout.scaledFont(10), weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func comparisonCard(_ report: CouncilReport) -> some View {
        guard let comparison = report.comparison else {
            return AnyView(EmptyView())
        }
        return AnyView(VStack(alignment: .leading, spacing: PSSpacing.md) {
            sectionHeader("vs. Average", icon: "chart.xyaxis.line", color: PSColors.accentTeal)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Rank")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(comparison.rank)")
                            .font(.system(size: PSLayout.scaledFont(32), weight: .black, design: .rounded))
                            .foregroundStyle(PSColors.primaryGreen)
                        Text("th percentile")
                            .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("National avg")
                        .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                    Text("\(comparison.nationalAverage) items/month")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text("Regional avg")
                        .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                        .padding(.top, 2)
                    Text("\(comparison.regionalAverage) items/month")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                }
            }
            Text("You're doing better than \(comparison.rank)% of households in your area. Every item saved shrinks the council's collection costs.")
                .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .lineSpacing(2)
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
            .strokeBorder(PSColors.borderLight, lineWidth: 1)))
    }

    private func topCategoriesCard(_ report: CouncilReport) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            sectionHeader("Top Wasted Categories", icon: "chart.pie.fill", color: PSColors.secondaryAmber)
            if report.topWastedCategories.isEmpty {
                Text("No category breakdown yet.")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
            } else {
                let total = report.topWastedCategories.reduce(0) { $0 + $1.count }
                VStack(spacing: PSSpacing.sm) {
                    ForEach(report.topWastedCategories, id: \.category) { cat, count in
                        categoryBar(category: cat, count: count, total: total)
                    }
                }
            }
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
            .strokeBorder(PSColors.borderLight, lineWidth: 1))
    }

    private func categoryBar(category: String, count: Int, total: Int) -> some View {
        let pct = total > 0 ? Double(count) / Double(total) : 0
        return VStack(spacing: 4) {
            HStack {
                Text(category)
                    .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(PSColors.secondaryAmber)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PSColors.borderLight).frame(height: PSLayout.scaled(6))
                    Capsule()
                        .fill(LinearGradient(colors: [PSColors.secondaryAmber, Color(hex: 0xF97316)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * pct, height: PSLayout.scaled(6))
                }
            }
            .frame(height: PSLayout.scaled(6))
        }
    }

    private func reasonsCard(_ report: CouncilReport) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            sectionHeader("Why Food Is Wasted Locally", icon: "questionmark.circle.fill", color: Color(hex: 0xA855F7))
            if report.topReasons.isEmpty {
                Text("No reason data yet — log items in the bin to unlock insights.")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
            } else {
                VStack(spacing: PSSpacing.sm) {
                    ForEach(report.topReasons, id: \.reason) { reason, count in
                        HStack {
                            Text("•")
                                .foregroundStyle(Color(hex: 0xA855F7))
                            Text(reason)
                                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                                .foregroundStyle(PSColors.textPrimary)
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                                .foregroundStyle(Color(hex: 0xA855F7))
                        }
                    }
                }
            }
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
            .strokeBorder(PSColors.borderLight, lineWidth: 1))
    }

    private var shareDataCard: some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: PSLayout.scaledFont(22)))
                .foregroundStyle(Color(hex: 0x3B82F6))
            VStack(alignment: .leading, spacing: 2) {
                Text("Share Anonymous Data")
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text("Help your council reduce local waste — no personal info is ever shared.")
                    .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: .constant(true))
                .labelsHidden()
                .tint(Color(hex: 0x3B82F6))
        }
        .padding(PSSpacing.lg)
        .background(Color(hex: 0x3B82F6).opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
            .strokeBorder(Color(hex: 0x3B82F6).opacity(0.2), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: PSLayout.scaledFont(40)))
                .foregroundStyle(PSColors.textTertiary)
            Text("No data yet")
                .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
            Text("Add and track items to generate your council impact report.")
                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(PSSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: icon).font(.system(size: PSLayout.scaledFont(13))).foregroundStyle(color)
            Text(title)
                .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                .foregroundStyle(PSColors.textSecondary)
                .textCase(.uppercase).tracking(0.5)
        }
    }

    private func generate() {
        report = CouncilDataService.shared.generateReport(
            items: items,
            binEntries: binLogService.entries,
            postcode: postcode
        )
    }
}

#Preview {
    NavigationStack { CouncilImpactReportView() }
        .modelContainer(for: FreshliItem.self, inMemory: true)
}

import SwiftUI
import SwiftData

// MARK: - Barcode Analytics View
// EPR (Extended Producer Responsibility) cost insights per product.

struct BarcodeAnalyticsView: View {
    @Query private var allItems: [FreshliItem]
    @State private var insights: [BarcodeInsight] = []

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                hero
                if insights.isEmpty {
                    emptyState
                } else {
                    summaryCard
                    insightsList
                }
                footer
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle("Packaging Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .task { refresh() }
        .onChange(of: allItems.count) { _, _ in refresh() }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: PSSpacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0xEF4444).opacity(0.15), Color(hex: 0xF97316).opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: PSLayout.scaled(80), height: PSLayout.scaled(80))
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: PSLayout.scaledFont(34)))
                    .foregroundStyle(Color(hex: 0xEF4444))
            }
            VStack(spacing: PSSpacing.xs) {
                Text("Barcode Analytics")
                    .font(.system(size: PSLayout.scaledFont(20), weight: .black, design: .rounded))
                Text("EPR (Extended Producer Responsibility) cost of your packaging waste, tracked per barcode.")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let totalEpr = insights.reduce(0) { $0 + $1.totalEprImpact }
        let totalWasted = insights.reduce(0) { $0 + $1.timesWasted }
        let worstBarcode = insights.first

        return VStack(alignment: .leading, spacing: PSSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text("30-Day EPR Impact")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(alignment: .firstTextBaseline, spacing: PSSpacing.xs) {
                        Text("£\(String(format: "%.2f", totalEpr))")
                            .font(.system(size: PSLayout.scaledFont(42), weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("wasted")
                            .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                Image(systemName: "cube.box.fill")
                    .font(.system(size: PSLayout.scaledFont(44)))
                    .foregroundStyle(.white.opacity(0.5))
            }
            HStack(spacing: PSSpacing.lg) {
                summaryStat(value: "\(insights.count)", label: "Products tracked")
                Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: PSLayout.scaled(36))
                summaryStat(value: "\(totalWasted)", label: "Units wasted")
                if let worst = worstBarcode {
                    Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: PSLayout.scaled(36))
                    summaryStat(value: worst.packagingType.rawValue, label: "Worst offender")
                }
            }
        }
        .padding(PSSpacing.xl)
        .background(LinearGradient(
            colors: [Color(hex: 0xEF4444), Color(hex: 0xF97316).opacity(0.9)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .shadow(color: Color(hex: 0xEF4444).opacity(0.3), radius: 20, y: 8)
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: PSLayout.scaledFont(17), weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: PSLayout.scaledFont(10), weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Insights List

    private var insightsList: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            sectionHeader("Top Waste Offenders", icon: "chart.bar.fill", color: Color(hex: 0xEF4444))
            ForEach(insights) { insight in
                insightCard(insight)
            }
        }
    }

    private func insightCard(_ insight: BarcodeInsight) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(insight.packagingType.color.opacity(0.12))
                        .frame(width: PSLayout.scaled(44), height: PSLayout.scaled(44))
                    Image(systemName: insight.packagingType.icon)
                        .font(.system(size: PSLayout.scaledFont(18)))
                        .foregroundStyle(insight.packagingType.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.productName)
                        .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    HStack(spacing: PSSpacing.xs) {
                        Text(insight.packagingType.rawValue)
                            .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                            .foregroundStyle(insight.packagingType.color)
                        Text("•")
                            .foregroundStyle(PSColors.textTertiary)
                        Text("Barcode \(String(insight.barcode.prefix(8)))…")
                            .font(.system(size: PSLayout.scaledFont(11), weight: .medium, design: .monospaced))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
                Spacer()
                Text("£\(String(format: "%.2f", insight.totalEprImpact))")
                    .font(.system(size: PSLayout.scaledFont(15), weight: .black, design: .rounded))
                    .foregroundStyle(PSColors.expiredRed)
            }
            // Waste bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PSColors.borderLight).frame(height: PSLayout.scaled(6))
                    Capsule()
                        .fill(LinearGradient(colors: [insight.packagingType.color, insight.packagingType.color.opacity(0.6)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * insight.wasteRate, height: PSLayout.scaled(6))
                }
            }
            .frame(height: PSLayout.scaled(6))
            HStack {
                Text("\(Int(insight.wasteRate * 100))% waste rate")
                    .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)
                Spacer()
                Text("\(insight.timesWasted) of \(insight.timesPurchased) wasted")
                    .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
            }
            Text(insight.recommendation)
                .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .lineSpacing(2)
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .strokeBorder(insight.packagingType.color.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Helpers

    private var emptyState: some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: "barcode")
                .font(.system(size: PSLayout.scaledFont(50)))
                .foregroundStyle(PSColors.textTertiary)
            Text("No barcode data yet")
                .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                .foregroundStyle(PSColors.textPrimary)
            Text("Scan barcodes when you add items to unlock EPR cost tracking and packaging waste insights.")
                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(PSSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: PSLayout.scaledFont(12)))
                .foregroundStyle(PSColors.textTertiary)
            Text("EPR costs estimate the packaging levy producers pay. High scores mean switching brands saves money and waste.")
                .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
                .lineSpacing(2)
        }
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

    private func refresh() {
        insights = BarcodeAnalyticsService.shared.analyze(items: allItems)
    }
}

#Preview {
    NavigationStack { BarcodeAnalyticsView() }
        .modelContainer(for: FreshliItem.self, inMemory: true)
}

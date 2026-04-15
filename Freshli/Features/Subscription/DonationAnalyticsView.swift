import SwiftUI

struct DonationAnalyticsView: View {
    @Environment(DonationAnalyticsService.self) var donationService
    @Environment(SubscriptionService.self) var subscriptionService
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showExportSheet = false

    private let availableYears: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 2)...currentYear).reversed()
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xl) {
                    // MARK: - Summary Cards
                    summarySection

                    // MARK: - Monthly Chart
                    if !donationService.records.isEmpty {
                        monthlyChartSection
                    }

                    // MARK: - Category Breakdown
                    if !donationService.categoryBreakdown.isEmpty {
                        categoryBreakdownSection
                    }

                    // MARK: - Tax Report Section
                    if subscriptionService.isProUser {
                        taxReportSection
                    }

                    // MARK: - Recent Donations
                    if !donationService.recentDonations.isEmpty {
                        recentDonationsSection
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.screenVertical)
            }
            .navigationTitle("Donation Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .background(PSColors.backgroundPrimary)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.md) {
                PSStatTile(
                    icon: "heart.fill",
                    value: String(donationService.totalDonations),
                    label: "Total Donations",
                    tint: PSColors.expiredRed
                )

                PSStatTile(
                    icon: "dollarsign.circle.fill",
                    value: String(format: "$%.2f", donationService.totalEstimatedValue),
                    label: "Estimated Value",
                    tint: PSColors.freshGreen
                )
            }

            PSStatTile(
                icon: "doc.fill",
                value: String(donationService.records.reduce(0) { $0 + $1.items.count }),
                label: "Items Donated",
                tint: PSColors.infoBlue
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Monthly Chart Section

    private var monthlyChartSection: some View {
        VStack(spacing: PSSpacing.md) {
            Text("Monthly Breakdown")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            PSCard {
                monthlyBarChart
            }
        }
    }

    private var monthlyBarChart: some View {
        let monthlyData = donationService.monthlyBreakdown.sorted { $0.key < $1.key }
        let maxValue = monthlyData.map { $0.value }.max() ?? 1.0

        return VStack(spacing: PSSpacing.md) {
            ForEach(Array(monthlyData.suffix(6)), id: \.key) { month, value in
                HStack(spacing: PSSpacing.md) {
                    Text(monthLabel(month))
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                        .frame(width: 50, alignment: .leading)

                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous)
                            .fill(PSColors.primaryGreen)
                            .frame(maxWidth: (value / maxValue) * 200)
                            .frame(height: 24)

                        Spacer()
                    }

                    Text(String(format: "$%.2f", value))
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textPrimary)
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
    }

    private func monthLabel(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        if let date = formatter.date(from: dateString) {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            return monthFormatter.string(from: date)
        }
        return dateString
    }

    // MARK: - Category Breakdown Section

    private var categoryBreakdownSection: some View {
        VStack(spacing: PSSpacing.md) {
            Text("By Category")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: PSSpacing.sm) {
                ForEach(
                    donationService.categoryBreakdown
                        .sorted { $0.value > $1.value },
                    id: \.key
                ) { category, value in
                    categoryBreakdownRow(category, value: value)
                }
            }
        }
    }

    private func categoryBreakdownRow(
        _ category: DonationRecord.DonationCategory,
        value: Double
    ) -> some View {
        let total = donationService.totalEstimatedValue
        let percentage = total > 0 ? (value / total) * 100 : 0

        return PSCard {
            HStack(spacing: PSSpacing.md) {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text(category.displayName)
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textPrimary)

                    HStack(spacing: PSSpacing.md) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous)
                                    .fill(PSColors.backgroundSecondary)

                                RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous)
                                    .fill(PSColors.accentTeal)
                                    .frame(width: geometry.size.width * CGFloat(percentage / 100))
                            }
                        }
                        .frame(height: 8)

                        Text(String(format: "%.0f%%", percentage))
                            .font(PSTypography.caption2)
                            .foregroundStyle(PSColors.textSecondary)
                            .frame(width: 35, alignment: .trailing)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: PSSpacing.xxxs) {
                    Text(String(format: "$%.2f", value))
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textPrimary)
                    Text("Donated")
                        .font(PSTypography.caption2)
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Tax Report Section

    private var taxReportSection: some View {
        VStack(spacing: PSSpacing.md) {
            Text("Tax Report")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            PSCard {
                VStack(alignment: .leading, spacing: PSSpacing.md) {
                    Picker("Year", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.segmented)

                    Divider()

                    let taxReport = donationService.generateTaxReport(year: selectedYear)

                    VStack(alignment: .leading, spacing: PSSpacing.md) {
                        taxReportRow(
                            label: "Total Donations",
                            value: String(format: "$%.2f", taxReport.totalValue),
                            highlight: true
                        )

                        taxReportRow(
                            label: "Items Donated",
                            value: String(taxReport.itemCount)
                        )

                        if !taxReport.categoryBreakdown.isEmpty {
                            Divider()
                                .padding(.vertical, PSSpacing.sm)

                            Text("Category Breakdown")
                                .font(PSTypography.caption1)
                                .foregroundStyle(PSColors.textSecondary)

                            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                                ForEach(
                                    taxReport.categoryBreakdown
                                        .sorted { $0.value > $1.value },
                                    id: \.key
                                ) { category, value in
                                    HStack {
                                        Text(category.displayName)
                                            .font(PSTypography.caption1)
                                            .foregroundStyle(PSColors.textSecondary)
                                        Spacer()
                                        Text(String(format: "$%.2f", value))
                                            .font(PSTypography.caption1)
                                            .foregroundStyle(PSColors.textPrimary)
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    PSButton(
                        title: "Export Tax Report",
                        style: .secondary,
                        size: .medium,
                        isFullWidth: true,
                        action: {
                            showExportSheet = true
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            let exportText = donationService.exportTaxReport(year: selectedYear)

            ShareSheet(text: exportText, filename: "Freshli-Tax-Report-\(selectedYear).txt")
                .presentationDragIndicator(.visible)
                .sheetTransition()
        }
    }

    private func taxReportRow(label: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(highlight ? PSTypography.callout : PSTypography.caption1)
                .foregroundStyle(highlight ? PSColors.textPrimary : PSColors.textSecondary)

            Spacer()

            Text(value)
                .font(highlight ? PSTypography.headline : PSTypography.caption1)
                .foregroundStyle(PSColors.textPrimary)
        }
    }

    // MARK: - Recent Donations Section

    private var recentDonationsSection: some View {
        VStack(spacing: PSSpacing.md) {
            Text("Recent Donations")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: PSSpacing.sm) {
                ForEach(donationService.recentDonations) { record in
                    donationCard(record)
                }
            }
        }
    }

    private func donationCard(_ record: DonationRecord) -> some View {
        PSCard {
            VStack(alignment: .leading, spacing: PSSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text(record.category.displayName)
                            .font(PSTypography.callout)
                            .foregroundStyle(PSColors.textPrimary)

                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: PSSpacing.xs) {
                        Text(String(format: "$%.2f", record.estimatedValue))
                            .font(PSTypography.headline)
                            .foregroundStyle(PSColors.primaryGreen)

                        if record.taxDeductible {
                            PSBadge(text: "Tax Deductible", variant: .fresh, style: .subtle)
                        }
                    }
                }

                if !record.items.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        ForEach(record.items.prefix(3), id: \.self) { item in
                            HStack(spacing: PSSpacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PSColors.primaryGreen)

                                Text(item)
                                    .font(PSTypography.caption1)
                                    .foregroundStyle(PSColors.textSecondary)

                                Spacer()
                            }
                        }

                        if record.items.count > 3 {
                            Text("+\(record.items.count - 3) more")
                                .font(PSTypography.caption2)
                                .foregroundStyle(PSColors.textTertiary)
                                .padding(.leading, PSSpacing.md)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        PSEmptyState(
            icon: "heart.circle",
            title: "No Donations Yet",
            message: "Track your donations to see analytics and generate tax reports.",
            actionTitle: "Log Donation",
            action: {}
        )
    }
}

// MARK: - ShareSheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? text.write(to: tempURL, atomically: true, encoding: .utf8)

        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    @Previewable @State var donationService = DonationAnalyticsService()
    @Previewable @State var subscriptionService = SubscriptionService()

    DonationAnalyticsView()
        .environment(donationService)
        .environment(subscriptionService)
        .onAppear {
            // Add sample data
            donationService.recordDonation(
                items: ["Apples", "Oranges"],
                estimatedValue: 25.50,
                category: .foodBank
            )
            donationService.recordDonation(
                items: ["Bread", "Milk"],
                estimatedValue: 15.00,
                category: .neighbor
            )
            donationService.recordDonation(
                items: ["Canned beans", "Rice"],
                estimatedValue: 12.75,
                category: .community
            )

            subscriptionService.currentTier = .pro
        }
}

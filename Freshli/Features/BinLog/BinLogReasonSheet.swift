import SwiftUI
import SwiftData

// MARK: - Bin Log Reason Sheet
// Presented when a user marks an item as "Thrown Away" to capture WHY.
// Also contains a dashboard for stop-buying analytics.

struct BinLogReasonSheet: View {
    let item: FreshliItem
    let onDismiss: (BinReason?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: BinReason?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xxl) {
                    header
                    reasonsGrid
                    submitButton
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.lg)
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle("Why did it go bad?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        onDismiss(nil)
                        dismiss()
                    }
                    .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: PSLayout.scaledFont(48)))
                .foregroundStyle(PSColors.expiredRed)
            VStack(spacing: PSSpacing.xs) {
                Text(item.name)
                    .font(.system(size: PSLayout.scaledFont(20), weight: .black))
                    .foregroundStyle(PSColors.textPrimary)
                Text("Help us stop this from happening again. Your answer builds your Bin Log — no judgement.")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }

    private var reasonsGrid: some View {
        VStack(spacing: PSSpacing.sm) {
            ForEach(BinReason.allCases) { reason in
                reasonButton(reason)
            }
        }
    }

    private func reasonButton(_ reason: BinReason) -> some View {
        let isSelected = selectedReason == reason
        return Button {
            PSHaptics.shared.lightTap()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedReason = reason
            }
        } label: {
            HStack(spacing: PSSpacing.md) {
                ZStack {
                    Circle()
                        .fill(isSelected ? reason.color : reason.color.opacity(0.12))
                        .frame(width: PSLayout.scaled(40), height: PSLayout.scaled(40))
                    Image(systemName: reason.icon)
                        .font(.system(size: PSLayout.scaledFont(18)))
                        .foregroundStyle(isSelected ? .white : reason.color)
                }
                Text(reason.rawValue)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(20)))
                        .foregroundStyle(reason.color)
                }
            }
            .padding(PSSpacing.lg)
            .background(isSelected ? reason.color.opacity(0.08) : PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                    .strokeBorder(isSelected ? reason.color : PSColors.borderLight, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var submitButton: some View {
        Button {
            guard let reason = selectedReason else { return }
            PSHaptics.shared.mediumTap()
            BinLogService.shared.log(item: item, reason: reason)
            onDismiss(reason)
            dismiss()
        } label: {
            Text("Log & Continue")
                .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, PSSpacing.lg)
                .background(selectedReason != nil ? PSColors.primaryGreen : PSColors.borderLight)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(selectedReason == nil)
    }
}

// MARK: - Bin Log Dashboard

struct BinLogDashboardView: View {
    @State private var service = BinLogService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                summaryCard
                stopBuyingSection
                reasonBreakdownSection
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.vertical, PSSpacing.lg)
        }
        .background(PSColors.backgroundPrimary)
        .navigationTitle("Trash Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        let cost = service.totalWastedCost(days: 30)
        let count = service.entries.filter {
            $0.date >= (Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date())
        }.count
        return VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text("LAST 30 DAYS")
                .font(.system(size: PSLayout.scaledFont(11), weight: .black))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(1.5)
            HStack(alignment: .firstTextBaseline) {
                Text("£\(String(format: "%.2f", cost))")
                    .font(.system(size: PSLayout.scaledFont(48), weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("in the bin")
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.leading, PSSpacing.xs)
            }
            Text("\(count) items logged")
                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PSSpacing.xl)
        .background(LinearGradient(
            colors: [PSColors.expiredRed, Color(hex: 0xF97316).opacity(0.9)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .shadow(color: PSColors.expiredRed.opacity(0.25), radius: 20, y: 8)
    }

    private var stopBuyingSection: some View {
        let alerts = service.stopBuyingAlerts()
        return VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: PSLayout.scaledFont(13)))
                    .foregroundStyle(PSColors.expiredRed)
                Text("Stop Buying These")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(PSColors.textSecondary)
                    .textCase(.uppercase).tracking(0.5)
            }
            if alerts.isEmpty {
                Text("No repeat offenders yet. Keep tracking to unlock personalised alerts.")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
                    .padding(PSSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(PSColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            } else {
                ForEach(alerts) { alert in
                    stopBuyingRow(alert)
                }
            }
        }
    }

    private func stopBuyingRow(_ alert: StopBuyingAlert) -> some View {
        HStack(spacing: PSSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PSColors.expiredRed.opacity(0.12))
                    .frame(width: PSLayout.scaled(44), height: PSLayout.scaled(44))
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(PSColors.expiredRed)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.itemName)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text("Binned \(alert.binCount)× — usually: \(alert.topReason.rawValue.lowercased())")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Text("£\(String(format: "%.2f", alert.totalCost))")
                .font(.system(size: PSLayout.scaledFont(14), weight: .black, design: .rounded))
                .foregroundStyle(PSColors.expiredRed)
        }
        .padding(PSSpacing.md)
        .background(PSColors.expiredRed.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .strokeBorder(PSColors.expiredRed.opacity(0.15), lineWidth: 1))
    }

    private var reasonBreakdownSection: some View {
        let breakdown = service.reasonBreakdown()
        let total = breakdown.reduce(0) { $0 + $1.1 }
        return VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: PSLayout.scaledFont(13)))
                    .foregroundStyle(PSColors.accentTeal)
                Text("Why Food Goes Bad")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(PSColors.textSecondary)
                    .textCase(.uppercase).tracking(0.5)
            }
            if breakdown.isEmpty {
                Text("Log items when you bin them to see patterns emerge.")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
                    .padding(PSSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(PSColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            } else {
                VStack(spacing: PSSpacing.sm) {
                    ForEach(breakdown, id: \.0) { reason, count in
                        reasonBar(reason: reason, count: count, total: total)
                    }
                }
                .padding(PSSpacing.lg)
                .background(PSColors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            }
        }
    }

    private func reasonBar(reason: BinReason, count: Int, total: Int) -> some View {
        let pct = total > 0 ? Double(count) / Double(total) : 0
        return VStack(spacing: PSSpacing.xs) {
            HStack {
                Image(systemName: reason.icon)
                    .font(.system(size: PSLayout.scaledFont(12)))
                    .foregroundStyle(reason.color)
                Text(reason.rawValue)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                    .foregroundStyle(reason.color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(reason.color.opacity(0.1)).frame(height: PSLayout.scaled(6))
                    Capsule().fill(reason.color).frame(width: geo.size.width * pct, height: PSLayout.scaled(6))
                }
            }
            .frame(height: PSLayout.scaled(6))
        }
    }
}

#Preview("Dashboard") {
    NavigationStack { BinLogDashboardView() }
}

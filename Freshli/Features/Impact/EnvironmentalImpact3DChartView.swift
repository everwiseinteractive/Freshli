import SwiftUI
import Charts

// ══════════════════════════════════════════════════════════════════
// MARK: - Environmental Impact 3D Chart
// Multi-layered, depth-rich impact visualization using Swift Charts
// with parallax-offset layers, perspective transforms, and animated
// data reveals. Gives the impression of 3D depth while remaining
// fully accessible.
//
// Layers (back → front):
//   1. CO₂ Avoided   — teal AreaMark with gradient fill (background)
//   2. Money Saved    — green LineMark with glow dots (midground)
//   3. Items Rescued  — amber BarMark with glassmorphism (foreground)
//
// Accessibility:
//   - VoiceOver labels for every data point
//   - High Contrast mode swaps glassmorphism for opaque mesh gradients
//   - Reduce Motion disables parallax and uses instant data reveal
//   - Increase Contrast adds thick strokes and removes transparency
// ══════════════════════════════════════════════════════════════════

// MARK: - Data Model

struct ImpactChartDataPoint: Identifiable, Sendable {
    let id = UUID()
    let label: String          // Day label ("Mon", "Tue", etc.)
    let date: Date
    let co2Avoided: Double     // kg
    let moneySaved: Double     // $
    let itemsRescued: Int
}

// MARK: - Main Chart View

struct EnvironmentalImpact3DChartView: View {
    let dataPoints: [ImpactChartDataPoint]
    let totalCO2: Double
    let totalMoney: Double
    let totalItems: Int

    @State private var selectedPoint: ImpactChartDataPoint?
    @State private var chartRevealed = false
    @State private var layerOffsets: [CGFloat] = [0, 0, 0]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.shaderQuality) private var quality

    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            // Section header
            chartHeader

            // 3D layered chart
            ZStack {
                // Layer 1: CO₂ area (background — depth offset)
                co2AreaLayer
                    .offset(y: reduceMotion ? 0 : layerOffsets[0])

                // Layer 2: Money line (midground)
                moneyLineLayer
                    .offset(y: reduceMotion ? 0 : layerOffsets[1])

                // Layer 3: Items bars (foreground)
                itemsBarLayer
                    .offset(y: reduceMotion ? 0 : layerOffsets[2])
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
            .highContrastMaterial(cornerRadius: PSSpacing.radiusXl)

            // Scrub detail
            if let selected = selectedPoint {
                scrubDetail(for: selected)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Totals summary row
            totalsSummary
        }
        .onAppear {
            if reduceMotion {
                chartRevealed = true
            } else {
                withAnimation(.spring(duration: 0.8, bounce: 0.2).delay(0.2)) {
                    chartRevealed = true
                }
                // Subtle parallax breathing
                startParallaxBreathing()
            }
        }
    }

    // MARK: - Header

    private var chartHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: "globe.americas.fill")
                        .foregroundStyle(PSColors.accentTeal)
                    Text(String(localized: "Environmental Impact"))
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)
                }

                Text(String(localized: "Your contribution to reducing food waste"))
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)
            }

            Spacer()

            // Equivalence badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", totalCO2 / 21.0))
                    .font(.system(size: PSLayout.scaledFont(22), weight: .bold, design: .rounded))
                    .foregroundStyle(PSColors.accentTeal)
                    .contentTransition(.numericText())

                Text(String(localized: "trees saved"))
                    .font(.system(size: PSLayout.scaledFont(10), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
            }
        }
    }

    // MARK: - Layer 1: CO₂ Area (Background)

    private var co2AreaLayer: some View {
        Chart(dataPoints) { point in
            AreaMark(
                x: .value("Day", point.label),
                y: .value("CO₂", chartRevealed ? point.co2Avoided : 0)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [
                        PSColors.accentTeal.opacity(reduceTransparency ? 0.6 : 0.35),
                        PSColors.accentTeal.opacity(reduceTransparency ? 0.2 : 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Day", point.label),
                y: .value("CO₂", chartRevealed ? point.co2Avoided : 0)
            )
            .foregroundStyle(PSColors.accentTeal.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: reduceTransparency ? 2.5 : 1.5))
            .interpolationMethod(.catmullRom)
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .chartLegend(.hidden)
        .animation(.spring(duration: 0.8), value: chartRevealed)
        .allowsHitTesting(false)
        .opacity(0.8)
    }

    // MARK: - Layer 2: Money Line (Midground)

    private var moneyLineLayer: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Day", point.label),
                y: .value("Saved", chartRevealed ? point.moneySaved : 0)
            )
            .foregroundStyle(PSColors.primaryGreen)
            .lineStyle(StrokeStyle(lineWidth: reduceTransparency ? 3 : 2))
            .interpolationMethod(.catmullRom)
            .symbol {
                Circle()
                    .fill(PSColors.primaryGreen)
                    .frame(width: reduceTransparency ? 8 : 6, height: reduceTransparency ? 8 : 6)
                    .shadow(color: PSColors.primaryGreen.opacity(0.4), radius: 4)
            }

            if let selected = selectedPoint, selected.label == point.label {
                RuleMark(x: .value("Selected", point.label))
                    .foregroundStyle(PSColors.textTertiary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                PointMark(
                    x: .value("Day", point.label),
                    y: .value("Saved", point.moneySaved)
                )
                .foregroundStyle(PSColors.primaryGreen)
                .symbolSize(120)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .chartLegend(.hidden)
        .animation(.spring(duration: 0.8).delay(0.15), value: chartRevealed)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = value.location.x - geo[plotFrame].origin.x
                                if let label: String = proxy.value(atX: x) {
                                    selectedPoint = dataPoints.first { $0.label == label }
                                    PSHaptics.shared.selection()
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedPoint = nil
                                }
                            }
                    )
            }
        }
    }

    // MARK: - Layer 3: Items Bars (Foreground)

    private var itemsBarLayer: some View {
        Chart(dataPoints) { point in
            BarMark(
                x: .value("Day", point.label),
                y: .value("Items", chartRevealed ? Double(point.itemsRescued) : 0)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [
                        Color(hex: 0xFBBF24).opacity(reduceTransparency ? 0.8 : 0.5),
                        Color(hex: 0xF59E0B).opacity(reduceTransparency ? 0.5 : 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(PSSpacing.radiusSm)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .foregroundStyle(PSColors.textTertiary)
                    .font(.system(size: PSLayout.scaledFont(10), weight: .medium))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)")
                            .font(.system(size: PSLayout.scaledFont(9), weight: .medium))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .animation(.spring(duration: 0.8).delay(0.3), value: chartRevealed)
    }

    // MARK: - Scrub Detail

    private func scrubDetail(for point: ImpactChartDataPoint) -> some View {
        HStack(spacing: PSSpacing.lg) {
            detailPill(icon: "leaf.fill", value: String(format: "%.1fkg", point.co2Avoided),
                       label: "CO₂", tint: PSColors.accentTeal)
            detailPill(icon: "dollarsign.circle.fill", value: String(format: "$%.2f", point.moneySaved),
                       label: "Saved", tint: PSColors.primaryGreen)
            detailPill(icon: "fork.knife", value: "\(point.itemsRescued)",
                       label: "Items", tint: Color(hex: 0xFBBF24))
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .elevation(.z1)
    }

    private func detailPill(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: PSSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(14)))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: PSLayout.scaledFont(14), weight: .bold, design: .rounded))
                .foregroundStyle(PSColors.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: PSLayout.scaledFont(9), weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Totals Summary

    private var totalsSummary: some View {
        HStack(spacing: PSSpacing.md) {
            summaryItem(icon: "leaf.fill", value: String(format: "%.1fkg", totalCO2),
                        label: String(localized: "CO₂ Avoided"), tint: PSColors.accentTeal)
            summaryItem(icon: "dollarsign.circle.fill", value: String(format: "$%.0f", totalMoney),
                        label: String(localized: "Money Saved"), tint: PSColors.primaryGreen)
            summaryItem(icon: "fork.knife", value: "\(totalItems)",
                        label: String(localized: "Items Rescued"), tint: Color(hex: 0xFBBF24))
        }
    }

    private func summaryItem(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: PSSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(18), weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: PSLayout.scaledFont(17), weight: .bold, design: .rounded))
                .foregroundStyle(PSColors.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: PSLayout.scaledFont(10), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .elevation(.z1)
        .highContrastMaterial(cornerRadius: PSSpacing.radiusLg)
    }

    // MARK: - Parallax Breathing

    private func startParallaxBreathing() {
        guard !reduceMotion else { return }
        Task { @MainActor in
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 3.0)) {
                    layerOffsets = [-2, 0, 2]
                }
                try? await Task.sleep(for: .seconds(3.0))
                withAnimation(.easeInOut(duration: 3.0)) {
                    layerOffsets = [2, 0, -2]
                }
                try? await Task.sleep(for: .seconds(3.0))
            }
        }
    }
}

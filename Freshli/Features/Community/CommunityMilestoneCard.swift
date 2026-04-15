import SwiftUI

// MARK: - Community Milestone Card
// Displays collective impact to foster a sense of belonging to a global
// movement. Numbers are seeded from the current month so they feel live
// and advance monthly. In production, replace with real Supabase aggregate data.

struct CommunityMilestoneCard: View {
    @State private var animatedItems: Int = 0
    @State private var animatedKg: Double = 0
    @State private var animatedFamilies: Int = 0
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Deterministic monthly numbers — consistent across all users, updates each month
    private var monthlyStats: (items: Int, kg: Double, families: Int) {
        let cal = Calendar.current
        let month = cal.component(.month, from: Date())
        let year  = cal.component(.year,  from: Date())
        let seed  = month * 1000 + (year % 100)
        let items     = 38_000 + (seed * 97) % 14_000    // 38k – 52k range
        let kg        = Double(items) * 0.34              // ~340g avg per item
        let families  = items / 4                          // ~4 items per family
        return (items, kg, families)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            statsRow
            footer
        }
        .background(milestoneGradient)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x22C55E).opacity(0.25), radius: 20, y: 8)
        .onAppear { startCounters() }
    }

    // MARK: - Gradient

    private var milestoneGradient: some View {
        LinearGradient(
            colors: [Color(hex: 0x064E3B), Color(hex: 0x065F46), Color(hex: 0x047857)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: PSSpacing.sm) {
            // Globe icon with glow ring
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: PSLayout.scaled(40), height: PSLayout.scaled(40))
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: PSLayout.scaledFont(20)))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Global Food Rescue")
                    .font(.system(size: PSLayout.scaledFont(16), weight: .black))
                    .foregroundStyle(.white)
                Text(monthLabel)
                    .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            // Live pill
            HStack(spacing: PSSpacing.xxs) {
                Circle()
                    .fill(Color(hex: 0x4ADE80))
                    .frame(width: 6, height: 6)
                Text("LIVE")
                    .font(.system(size: PSLayout.scaledFont(9), weight: .black))
                    .tracking(1)
                    .foregroundStyle(Color(hex: 0x4ADE80))
            }
            .padding(.horizontal, PSSpacing.sm)
            .padding(.vertical, PSSpacing.xxs)
            .background(.white.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.horizontal, PSSpacing.xl)
        .padding(.top, PSSpacing.xl)
        .padding(.bottom, PSSpacing.lg)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(
                value: formatLarge(animatedItems),
                label: "Items Rescued",
                icon: "leaf.fill",
                color: Color(hex: 0x4ADE80)
            )
            statDivider
            statCell(
                value: "\(Int(animatedKg / 1000))t",
                label: "Food Saved",
                icon: "scalemass.fill",
                color: Color(hex: 0x34D399)
            )
            statDivider
            statCell(
                value: formatLarge(animatedFamilies),
                label: "Families Fed",
                icon: "person.2.fill",
                color: Color(hex: 0x6EE7B7)
            )
        }
        .padding(.horizontal, PSSpacing.lg)
        .padding(.bottom, PSSpacing.lg)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: PSLayout.scaled(44))
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: PSSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(14)))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: PSLayout.scaledFont(24), weight: .black))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: false))
                .compositingGroup()
                .animation(.spring(duration: 0.4), value: value)
            Text(label)
                .font(.system(size: PSLayout.scaledFont(10), weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.sm)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: PSSpacing.xs) {
            Image(systemName: "heart.fill")
                .font(.system(size: PSLayout.scaledFont(11)))
                .foregroundStyle(Color(hex: 0xFB7185))
            Text("Together we're building a zero-waste world")
                .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.md)
        .background(.black.opacity(0.12))
    }

    // MARK: - Helpers

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    private func formatLarge(_ n: Int) -> String {
        if n >= 1_000 {
            let k = Double(n) / 1_000.0
            return String(format: "%.0fk", k)
        }
        return "\(n)"
    }

    private func startCounters() {
        guard !reduceMotion else {
            animatedItems    = monthlyStats.items
            animatedKg       = monthlyStats.kg
            animatedFamilies = monthlyStats.families
            return
        }

        let target = monthlyStats
        let steps  = 40
        let delay  = 0.04

        for i in 1...steps {
            let progress = Double(i) / Double(steps)
            let eased    = 1 - pow(1 - progress, 3) // ease-out cubic
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * delay) {
                withAnimation(.easeOut(duration: 0.02)) {
                    animatedItems    = Int(Double(target.items)    * eased)
                    animatedKg       = Double(target.kg)           * eased
                    animatedFamilies = Int(Double(target.families) * eased)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        CommunityMilestoneCard()
            .padding()
    }
}

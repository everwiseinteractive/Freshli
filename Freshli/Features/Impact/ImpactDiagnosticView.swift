import SwiftUI

// MARK: - Impact Diagnostic View (Debug Builds Only)
// Shows pass/fail status of core impact calculations.
// Accessible via Settings → Debug → Impact Diagnostics.

#if DEBUG

@MainActor
struct ImpactDiagnosticView: View {

    @State private var results: [DiagnosticResult] = []
    @State private var isRunning = false
    @State private var completedCount = 0
    @State private var totalCount = 0

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text("Impact Validation Suite")
                            .font(.system(size: 17, weight: .bold))
                        Text("\(passCount) passed · \(failCount) failed · \(results.count) total")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(failCount > 0 ? PSColors.expiredRed : PSColors.primaryGreen)
                    }
                    Spacer()
                    if isRunning {
                        ProgressView()
                    } else {
                        Button("Run") { Task { await runDiagnostics() } }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PSColors.primaryGreen)
                    }
                }
            } header: {
                Text("Diagnostics")
            }

            if !results.isEmpty {
                Section {
                    ForEach(results) { result in
                        HStack(spacing: PSSpacing.md) {
                            Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.passed ? PSColors.primaryGreen : PSColors.expiredRed)
                                .font(.system(size: 18))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PSColors.textPrimary)
                                if let detail = result.detail {
                                    Text(detail)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(result.passed ? PSColors.textTertiary : PSColors.expiredRed)
                                }
                            }

                            Spacer()

                            Text(String(format: "%.0fms", result.durationMs))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(PSColors.textTertiary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Results")
                }
            }
        }
        .navigationTitle("Impact Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await runDiagnostics() }
    }

    // MARK: - Computed

    private var passCount: Int { results.filter(\.passed).count }
    private var failCount: Int { results.filter { !$0.passed }.count }

    // MARK: - Run Suite

    private func runDiagnostics() async {
        isRunning = true
        results = []

        let engine = ImpactEngine()

        // Financial checks
        await runCheck("Single item = $3.50") {
            let r = await engine.calculateImpact(items: [
                .init(disposition: .consumed)
            ])
            return (r.moneySaved == Decimal(string: "3.50")!, "Got: \(r.moneySaved)")
        }

        await runCheck("Wasted = $0") {
            let r = await engine.calculateImpact(items: [
                .init(disposition: .wasted)
            ])
            return (r.moneySaved == Decimal(0), "Got: \(r.moneySaved)")
        }

        await runCheck("10 items = $35") {
            let items = (0..<10).map { _ in ImpactEngine.ItemInput(disposition: .consumed) }
            let r = await engine.calculateImpact(items: items)
            return (r.moneySaved == Decimal(string: "35.00")!, "Got: \(r.moneySaved)")
        }

        // CO2 checks
        await runCheck("Beef = 27 kg CO2/kg") {
            let item = ImpactEngine.ItemInput(
                category: "meat", quantity: 1,
                estimatedWeightKg: Decimal(string: "1.0")!, disposition: .consumed
            )
            let co2 = await engine.co2ForItem(item)
            return (co2 == Decimal(string: "27.0")!, "Got: \(co2)")
        }

        await runCheck("Vegetables = 2.0 kg CO2/kg") {
            let item = ImpactEngine.ItemInput(
                category: "vegetables", quantity: 1,
                estimatedWeightKg: Decimal(string: "1.0")!, disposition: .consumed
            )
            let co2 = await engine.co2ForItem(item)
            return (co2 == Decimal(string: "2.0")!, "Got: \(co2)")
        }

        // Streak checks
        await runCheck("Consecutive day increments streak") {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
            let (newStreak, _, _) = await engine.computeStreak(
                lastStreakDate: yesterday, today: today, currentStreak: 5
            )
            return (newStreak == 6, "Got: \(newStreak)")
        }

        await runCheck("Gap resets streak to 1") {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
            let (newStreak, _, _) = await engine.computeStreak(
                lastStreakDate: twoDaysAgo, today: today, currentStreak: 10
            )
            return (newStreak == 1, "Got: \(newStreak)")
        }

        // Edge case checks
        await runCheck("Empty input = zero (no NaN)") {
            let r = await engine.calculateImpact(items: [])
            return (
                r.moneySaved == Decimal(0) && r.co2Avoided == Decimal(0),
                "Money: \(r.moneySaved), CO2: \(r.co2Avoided)"
            )
        }

        await runCheck("Decimal precision: 0.1 + 0.2 == 0.3") {
            let sum = Decimal(string: "0.1")! + Decimal(string: "0.2")!
            return (sum == Decimal(string: "0.3")!, "Got: \(sum)")
        }

        await runCheck("Community sharing updates both sides") {
            let items = [ImpactEngine.ItemInput(
                category: "dairy", quantity: 1,
                estimatedWeightKg: Decimal(string: "0.5")!, disposition: .shared
            )]
            let impact = await engine.computeCommunityImpact(sharedItems: items)
            return (
                impact.giverItemsShared == 1 && impact.receiverItemsReceived == 1,
                "Giver: \(impact.giverItemsShared), Receiver: \(impact.receiverItemsReceived)"
            )
        }

        isRunning = false
    }

    private func runCheck(_ name: String, check: @escaping () async -> (Bool, String)) async {
        let start = CFAbsoluteTimeGetCurrent()
        let (passed, detail) = await check()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        results.append(DiagnosticResult(
            name: name,
            passed: passed,
            detail: passed ? nil : detail,
            durationMs: duration
        ))
    }
}

// MARK: - Diagnostic Result

private struct DiagnosticResult: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let detail: String?
    let durationMs: Double
}

#endif

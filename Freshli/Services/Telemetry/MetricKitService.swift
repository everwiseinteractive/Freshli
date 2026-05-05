import Foundation
import MetricKit
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - MetricKitService
//
// On-device telemetry subscriber for performance & diagnostic metrics.
// Apple delivers daily payloads (`MXMetricPayload`) and crash/hang
// diagnostics (`MXDiagnosticPayload`) through the MetricKit framework
// once the app has been backgrounded for ~24 hours. We subscribe at
// launch, persist the payloads to a JSON log in the App Group
// container, and surface the most recent values to the team through
// `os.Logger` (visible in Console.app filtered by subsystem).
//
// What we capture, and why it matters for ADA Performance/Innovation:
//
//   • MXAppLaunchMetric                 — proves cold/warm/resume launch
//                                         budget claims (target < 300ms TTI)
//                                         on real user devices, not just
//                                         test rigs.
//   • MXAnimationMetric                 — `scrollHitchTimeRatio` validates
//                                         the locked 120 Hz ProMotion claim.
//   • MXAppResponsivenessMetric        — `hangTimeHistogram` catches the
//                                         5s freeze heuristic that bit
//                                         App Review builds 19, 20, 22.
//   • MXMemoryMetric / MXCPUMetric     — battery / thermal correlation
//                                         with shader quality tier.
//   • MXSignpostMetric                 — every TTI signpost from
//                                         `TTIInstrumentation.swift`
//                                         is aggregated here.
//
// MetricKit data is privacy-respecting: payloads are aggregated on
// the device by Apple and delivered locally. Nothing is sent off-device
// by this service — it is opt-in via `start()` from `FreshliApp`.
// ══════════════════════════════════════════════════════════════════

@MainActor
final class MetricKitService: NSObject {
    static let shared = MetricKitService()

    private let logger = Logger(subsystem: "com.freshli.app", category: "MetricKit")
    private let metricLogStoreFileName = "metrickit-log.json"
    private var isStarted = false

    private override init() {
        super.init()
    }

    /// Subscribe to MetricKit payloads. Call once from `FreshliApp.task`
    /// (off the splash critical path) — it is fire-and-forget.
    func start() {
        guard !isStarted else { return }
        isStarted = true
        MXMetricManager.shared.add(self)
        logger.info("MetricKit subscriber registered.")
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        MXMetricManager.shared.remove(self)
        logger.info("MetricKit subscriber removed.")
    }

    // MARK: - Persistence

    private var logFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.everwise.interactive.Freshli")?
            .appendingPathComponent(metricLogStoreFileName)
    }

    private func append(_ entry: [String: Any]) {
        guard let url = logFileURL else { return }
        var existing: [[String: Any]] = []
        if let data = try? Data(contentsOf: url),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            existing = parsed
        }
        existing.append(entry)
        // Cap log to most recent 90 entries (~3 months of daily payloads).
        if existing.count > 90 { existing = Array(existing.suffix(90)) }
        if let data = try? JSONSerialization.data(withJSONObject: existing, options: [.prettyPrinted]) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - MXMetricManagerSubscriber

extension MetricKitService: MXMetricManagerSubscriber {
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        // Extract every value we need from `payload` here — on the
        // delivery thread Apple's daemon hands us — before crossing
        // into the MainActor context. `MXMetricPayload` is NSObject-
        // based and not declared `Sendable`, so it must not cross the
        // actor boundary even when we're sure nothing else is using
        // it concurrently.
        for payload in payloads {
            let summary = Self.summarise(payload)
            let jsonString = String(data: payload.jsonRepresentation(), encoding: .utf8) ?? "{}"
            Task { @MainActor in
                self.logger.info("MetricKit payload: \(summary, privacy: .public)")
                self.append([
                    "kind": "metric",
                    "received_at": ISO8601DateFormatter().string(from: Date()),
                    "summary": summary,
                    "raw_json": jsonString
                ])
            }
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let jsonData = payload.jsonRepresentation()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            let byteCount = jsonData.count
            Task { @MainActor in
                self.logger.warning("MetricKit diagnostic payload received (size \(byteCount, privacy: .public) bytes)")
                self.append([
                    "kind": "diagnostic",
                    "received_at": ISO8601DateFormatter().string(from: Date()),
                    "raw_json": jsonString
                ])
            }
        }
    }

    // MARK: - Summary

    nonisolated private static func summarise(_ payload: MXMetricPayload) -> String {
        var parts: [String] = []
        if let launch = payload.applicationLaunchMetrics {
            parts.append("ttfd_p50=\(launch.histogrammedTimeToFirstDraw.bucketEnumerator.allObjects.count)buckets")
        }
        if let anim = payload.animationMetrics {
            parts.append("scrollHitch=\(anim.scrollHitchTimeRatio.value)")
        }
        if let resp = payload.applicationResponsivenessMetrics {
            parts.append("hangBuckets=\(resp.histogrammedApplicationHangTime.bucketEnumerator.allObjects.count)")
        }
        if let mem = payload.memoryMetrics {
            parts.append("peakMemory=\(mem.peakMemoryUsage)")
        }
        if let cpu = payload.cpuMetrics {
            parts.append("cpuTime=\(cpu.cumulativeCPUTime)")
        }
        return parts.joined(separator: ", ")
    }
}

import Foundation
import MetricKit

@Observable @MainActor
final class DiagnosticsService: NSObject, MXMetricManagerSubscriber {
    static let shared = DiagnosticsService()

    private let logger = PSLogger(category: .performance)

    private(set) var lastPayloadDate: Date?
    private(set) var crashCount: Int = 0

    private override init() {
        super.init()
    }

    func start() {
        MXMetricManager.shared.add(self)
        logger.info("MetricKit diagnostics started")
    }

    func stop() {
        MXMetricManager.shared.remove(self)
    }

    // MARK: - MXMetricManagerSubscriber
    // MetricKit calls these on a background thread — must be nonisolated.
    // Extract only Sendable values before hopping to @MainActor to avoid data-race warnings.

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        // Extract Sendable data on the calling (background) thread
        let peakMBValues: [Double] = payloads.compactMap {
            $0.memoryMetrics?.peakMemoryUsage.converted(to: .megabytes).value
        }
        let cpuValues: [Double] = payloads.compactMap {
            $0.cpuMetrics?.cumulativeCPUTime.converted(to: .seconds).value
        }
        let diskValues: [Double] = payloads.compactMap {
            $0.diskIOMetrics?.cumulativeLogicalWrites.converted(to: .megabytes).value
        }
        Task { @MainActor in
            self.lastPayloadDate = Date()
            for mb in peakMBValues { self.logger.info("Peak memory: \(String(format: "%.0f", mb))MB") }
            for cpu in cpuValues   { self.logger.info("Cumulative CPU: \(String(format: "%.1f", cpu))s") }
            for disk in diskValues { self.logger.info("Disk writes: \(String(format: "%.1f", disk))MB") }
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // Extract Sendable counts on the calling (background) thread
        let crashCount  = payloads.reduce(0) { $0 + ($1.crashDiagnostics?.count  ?? 0) }
        let hangCount   = payloads.reduce(0) { $0 + ($1.hangDiagnostics?.count    ?? 0) }
        let cpuCount    = payloads.reduce(0) { $0 + ($1.cpuExceptionDiagnostics?.count ?? 0) }
        let diskCount   = payloads.reduce(0) { $0 + ($1.diskWriteExceptionDiagnostics?.count ?? 0) }
        Task { @MainActor in
            self.crashCount += crashCount
            if crashCount > 0 { self.logger.error("Received \(crashCount) crash diagnostic(s)") }
            if hangCount  > 0 { self.logger.warning("Received \(hangCount) hang diagnostic(s)") }
            if cpuCount   > 0 { self.logger.warning("Received \(cpuCount) CPU exception diagnostic(s)") }
            if diskCount  > 0 { self.logger.warning("Received \(diskCount) disk write exception diagnostic(s)") }
        }
    }

}

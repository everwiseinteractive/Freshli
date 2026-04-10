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

    func didReceive(_ payloads: [MXMetricPayload]) {
        lastPayloadDate = Date()
        for payload in payloads {
            processMetricPayload(payload)
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            processDiagnosticPayload(payload)
        }
    }

    // MARK: - Processing

    private func processMetricPayload(_ payload: MXMetricPayload) {
        // Log app launch time
        if let launchMetrics = payload.applicationLaunchMetrics {
            if let resumeTime = launchMetrics.histogrammedApplicationResumeTime.bucketEnumerator.allObjects.first {
                logger.info("App resume time bucket recorded")
            }
        }

        // Log memory usage
        if let memoryMetrics = payload.memoryMetrics {
            let peakMB = memoryMetrics.peakMemoryUsage.converted(to: .megabytes).value
            logger.info("Peak memory: \(String(format: "%.0f", peakMB))MB")
        }

        // Log CPU time
        if let cpuMetrics = payload.cpuMetrics {
            let cpuSeconds = cpuMetrics.cumulativeCPUTime.converted(to: .seconds).value
            logger.info("Cumulative CPU: \(String(format: "%.1f", cpuSeconds))s")
        }

        // Log disk writes
        if let diskMetrics = payload.diskIOMetrics {
            let writeMB = diskMetrics.cumulativeLogicalWrites.converted(to: .megabytes).value
            logger.info("Disk writes: \(String(format: "%.1f", writeMB))MB")
        }

        logger.info("MetricKit payload processed for period ending \(payload.timeStampEnd)")
    }

    private func processDiagnosticPayload(_ payload: MXDiagnosticPayload) {
        // Count crashes
        if let crashDiagnostics = payload.crashDiagnostics {
            crashCount += crashDiagnostics.count
            logger.error("Received \(crashDiagnostics.count) crash diagnostic(s)")
        }

        // Log hang diagnostics
        if let hangDiagnostics = payload.hangDiagnostics {
            logger.warning("Received \(hangDiagnostics.count) hang diagnostic(s)")
        }

        // Log CPU exceptions
        if let cpuExceptions = payload.cpuExceptionDiagnostics {
            logger.warning("Received \(cpuExceptions.count) CPU exception diagnostic(s)")
        }

        // Log disk write exceptions
        if let diskExceptions = payload.diskWriteExceptionDiagnostics {
            logger.warning("Received \(diskExceptions.count) disk write exception diagnostic(s)")
        }

        logger.info("Diagnostic payload processed")
    }
}

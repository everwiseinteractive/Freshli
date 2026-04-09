import Foundation
import os

/// Queues sync operations when offline and processes them when connectivity returns.
@Observable
final class OfflineSyncQueue {
    static let shared = OfflineSyncQueue()

    private let logger = PSLogger(category: .sync)
    private let queueKey = "com.freshli.offlineSyncQueue"

    private(set) var pendingOperations: [SyncOperation] = []
    private(set) var isProcessing = false

    struct SyncOperation: Codable, Identifiable {
        let id: UUID
        let type: OperationType
        let payload: Data
        let createdAt: Date

        enum OperationType: String, Codable {
            case pushItem
            case deleteItem
            case createListing
            case claimListing
            case recordImpact
            case updateProfile
        }
    }

    private init() {
        loadQueue()
    }

    var hasPendingOperations: Bool {
        !pendingOperations.isEmpty
    }

    var pendingCount: Int {
        pendingOperations.count
    }

    func enqueue(_ operation: SyncOperation) {
        pendingOperations.append(operation)
        saveQueue()
        logger.info("Enqueued offline operation: \(operation.type.rawValue) (\(pendingOperations.count) pending)")
    }

    func enqueueItemPush(itemData: Data) {
        let op = SyncOperation(
            id: UUID(),
            type: .pushItem,
            payload: itemData,
            createdAt: Date()
        )
        enqueue(op)
    }

    func enqueueImpactEvent(eventData: Data) {
        let op = SyncOperation(
            id: UUID(),
            type: .recordImpact,
            payload: eventData,
            createdAt: Date()
        )
        enqueue(op)
    }

    func dequeueAll() -> [SyncOperation] {
        let ops = pendingOperations
        pendingOperations.removeAll()
        saveQueue()
        return ops
    }

    func removeOperation(_ id: UUID) {
        pendingOperations.removeAll { $0.id == id }
        saveQueue()
    }

    /// Process all pending operations. Called when network becomes available.
    func processQueue(using syncService: SyncService) async {
        guard !isProcessing else {
            logger.debug("Queue processing already in progress")
            return
        }
        guard !pendingOperations.isEmpty else { return }
        guard NetworkMonitor.shared.isConnected else {
            logger.debug("Still offline, skipping queue processing")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        logger.info("Processing \(pendingOperations.count) queued operations")

        var processed: [UUID] = []

        for operation in pendingOperations {
            // Check connectivity before each operation
            guard NetworkMonitor.shared.isConnected else {
                logger.warning("Lost connectivity during queue processing")
                break
            }

            switch operation.type {
            case .pushItem, .deleteItem, .createListing, .claimListing, .recordImpact, .updateProfile:
                // For now, mark as processed - the full sync will reconcile
                processed.append(operation.id)
                logger.debug("Processed queued operation: \(operation.type.rawValue)")
            }
        }

        // Remove processed operations
        for id in processed {
            removeOperation(id)
        }

        logger.info("Queue processing complete. \(pendingOperations.count) remaining.")
    }

    // MARK: - Persistence

    private func saveQueue() {
        guard let data = try? JSONEncoder().encode(pendingOperations) else { return }
        UserDefaults.standard.set(data, forKey: queueKey)
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let ops = try? JSONDecoder().decode([SyncOperation].self, from: data) else { return }
        pendingOperations = ops
        if !ops.isEmpty {
            logger.info("Loaded \(ops.count) pending sync operations from disk")
        }
    }
}

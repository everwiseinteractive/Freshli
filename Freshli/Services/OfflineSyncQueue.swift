import Foundation
import SwiftData

// MARK: - OfflineSyncQueue
/// Queues sync operations when offline

@Observable @MainActor
final class OfflineSyncQueue {
    
    static let shared = OfflineSyncQueue()
    
    private init() {
        loadQueue()
    }
    
    struct SyncOperation: Codable, Identifiable {
        let id: UUID
        let type: OperationType
        let payload: Data
        let createdAt: Date
        
        enum OperationType: String, Codable {
            case pushItem
            case deleteItem
            case updateProfile
            case createListing
            case claimListing
            case recordImpact
        }
    }
    
    private(set) var pendingOperations: [SyncOperation] = []
    
    var hasPendingOperations: Bool {
        !pendingOperations.isEmpty
    }
    
    // MARK: - Queue Management
    
    func enqueue(_ operation: SyncOperation) {
        pendingOperations.append(operation)
        saveQueue()
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
    
    func remove(_ operation: SyncOperation) {
        pendingOperations.removeAll { $0.id == operation.id }
        saveQueue()
    }
    
    func clearAll() {
        pendingOperations.removeAll()
        saveQueue()
    }
    
    // MARK: - Processing
    
    func processQueue(using syncService: SyncService) async {
        guard NetworkMonitor.shared.isConnected else { return }
        
        PSLogger.sync.info("Processing \(pendingOperations.count) offline operations")
        
        for operation in pendingOperations {
            // Process each operation (simplified - would need actual implementation)
            PSLogger.sync.debug("Processing operation: \(operation.type.rawValue)")
            
            // Remove after processing
            remove(operation)
            
            // Small delay to avoid overwhelming the server
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        PSLogger.sync.info("Offline queue processing complete")
    }
    
    // MARK: - Persistence
    
    private func saveQueue() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(pendingOperations) {
            UserDefaults.standard.set(data, forKey: "offlineSyncQueue")
        }
    }
    
    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: "offlineSyncQueue"),
              let operations = try? JSONDecoder().decode([SyncOperation].self, from: data) else {
            return
        }
        pendingOperations = operations
    }
}

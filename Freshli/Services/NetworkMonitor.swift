import Foundation
import Network

// MARK: - NetworkMonitor
/// Monitors network connectivity status

@Observable @MainActor
final class NetworkMonitor {
    
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.freshli.networkmonitor")
    
    private(set) var isConnected = true
    private(set) var connectionType: NWInterface.InterfaceType?
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                
                if path.status == .satisfied {
                    PSLogger.network.info("Network connected: \(path.availableInterfaces.first?.type.debugDescription ?? "unknown")")
                } else {
                    PSLogger.network.warning("Network disconnected")
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

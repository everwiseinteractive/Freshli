import Foundation
import Network

@Observable @MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.everwise.Freshli.networkMonitor")
    private let logger = PSLogger(category: .sync)

    private(set) var isConnected: Bool = true
    private(set) var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi, cellular, wired, unknown
    }

    private init() {}

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
                self?.logger.debug("Network status: \(path.status == .satisfied ? "connected" : "disconnected")")
            }
        }
        monitor.start(queue: queue)
        logger.info("Network monitor started")
    }

    func stop() {
        monitor.cancel()
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .unknown
    }
}

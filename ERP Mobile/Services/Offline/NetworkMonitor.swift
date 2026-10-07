import Combine
import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOnline = true
    @Published private(set) var pathStatusDescription = ""

    /// Nonisolated snapshot for service layers (updated on the monitor queue).
    nonisolated(unsafe) private(set) static var isOnlineSnapshot = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ro.dateconta.erp.network-monitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            NetworkMonitor.isOnlineSnapshot = online
            Task { @MainActor in
                guard let self else { return }
                let changed = self.isOnline != online
                self.isOnline = online
                self.pathStatusDescription = online ? "online" : "offline"
                if changed {
                    NotificationCenter.default.post(
                        name: .offlineNetworkStatusDidChange,
                        object: nil,
                        userInfo: ["isOnline": online]
                    )
                    if online {
                        SyncEngine.shared.scheduleSync(reason: "network_online")
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
}

extension Notification.Name {
    static let offlineNetworkStatusDidChange = Notification.Name("offlineNetworkStatusDidChange")
    static let offlineSyncStateDidChange = Notification.Name("offlineSyncStateDidChange")
}

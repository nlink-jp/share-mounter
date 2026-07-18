import Foundation
import Network

/// Watches for the network path becoming satisfied (Wi-Fi/Ethernet/VPN coming
/// up) and fires a callback on each rising edge, so auto-mount shares can be
/// re-mounted after the network returns.
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "jp.nlink.share-mounter.netmon")
    private var wasSatisfied = false

    /// Called (on `queue`) when the path transitions to satisfied.
    var onBecameSatisfied: (() -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let satisfied = path.status == .satisfied
            let risingEdge = satisfied && !self.wasSatisfied
            self.wasSatisfied = satisfied
            if risingEdge { self.onBecameSatisfied?() }
        }
        monitor.start(queue: queue)
    }

    func stop() { monitor.cancel() }
}

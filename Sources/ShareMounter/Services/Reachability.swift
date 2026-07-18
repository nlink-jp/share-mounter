import Foundation
import Network

/// Probes whether a TCP endpoint accepts connections. Abstracted so the waiter
/// can be tested with a deterministic double.
protocol PortProbe {
    func canConnect(host: String, port: UInt16, timeout: TimeInterval) async -> Bool
}

/// Real TCP reachability probe using Network.framework.
final class NWPortProbe: PortProbe {
    func canConnect(host: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: false)
                return
            }
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let queue = DispatchQueue(label: "jp.nlink.share-mounter.probe")
            let once = ResumeOnce { connection.cancel() }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if once.fire() { continuation.resume(returning: true) }
                case .failed, .cancelled:
                    if once.fire() { continuation.resume(returning: false) }
                default:
                    break
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) {
                if once.fire() { continuation.resume(returning: false) }
            }
            connection.start(queue: queue)
        }
    }
}

/// Ensures a continuation resumes exactly once and runs a teardown on first fire.
/// Thread-safe via an internal lock, hence `@unchecked Sendable`.
private final class ResumeOnce: @unchecked Sendable {
    private var done = false
    private let lock = NSLock()
    private let onFire: () -> Void
    init(onFire: @escaping () -> Void) { self.onFire = onFire }
    func fire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        onFire()
        return true
    }
}

/// Exponential backoff schedule. Pure and fully testable.
struct Backoff: Equatable {
    var base: TimeInterval = 1.0
    var factor: Double = 2.0
    var maxDelay: TimeInterval = 30.0
    var maxAttempts: Int = 8

    /// Delay before retry `n` (1-based): delay(1)=base, delay(2)=base*factor, …,
    /// clamped to `maxDelay`. Non-positive `n` yields 0.
    func delay(forAttempt n: Int) -> TimeInterval {
        guard n >= 1 else { return 0 }
        let raw = base * pow(factor, Double(n - 1))
        return min(raw, maxDelay)
    }
}

/// Waits (with backoff) until a host:port becomes reachable, so a login-time
/// mount doesn't fail just because the network/VPN isn't up yet.
struct ReachabilityWaiter {
    let probe: PortProbe
    let backoff: Backoff
    let sleep: (TimeInterval) async -> Void

    init(probe: PortProbe,
         backoff: Backoff = Backoff(),
         sleep: @escaping (TimeInterval) async -> Void = { seconds in
             try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
         }) {
        self.probe = probe
        self.backoff = backoff
        self.sleep = sleep
    }

    /// Returns true as soon as the endpoint is reachable; false after
    /// `backoff.maxAttempts` probes have all failed.
    func waitUntilReachable(host: String, port: UInt16 = 445, timeout: TimeInterval = 5) async -> Bool {
        let attempts = max(1, backoff.maxAttempts)
        for attempt in 1 ... attempts {
            if await probe.canConnect(host: host, port: port, timeout: timeout) {
                return true
            }
            if attempt < attempts {
                await sleep(backoff.delay(forAttempt: attempt))
            }
        }
        return false
    }
}

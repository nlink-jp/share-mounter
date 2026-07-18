import Foundation
@testable import ShareMounter

/// Records mount/unmount calls and returns programmable results.
final class FakeMounter: Mounter {
    var resultPath = "/Volumes/testshare"
    var mountError: Error?
    var unmountError: Error?
    private(set) var mountCalls: [MountRequest] = []
    private(set) var unmountCalls: [String] = []

    func mount(_ request: MountRequest) async throws -> String {
        mountCalls.append(request)
        if let error = mountError { throw error }
        return resultPath
    }

    func unmount(path: String) async throws {
        unmountCalls.append(path)
        if let error = unmountError { throw error }
    }
}

/// Returns a fixed set of "currently mounted" volumes.
final class FakeInventory: MountInventory {
    var mounts: [MountedVolume] = []
    func currentMounts() -> [MountedVolume] { mounts }
}

/// Deterministic reachability probe: fails a set number of times, then succeeds
/// (or always fails).
final class FakeProbe: PortProbe {
    var failuresBeforeSuccess: Int
    var alwaysFail: Bool
    private(set) var calls = 0

    init(failuresBeforeSuccess: Int = 0, alwaysFail: Bool = false) {
        self.failuresBeforeSuccess = failuresBeforeSuccess
        self.alwaysFail = alwaysFail
    }

    func canConnect(host: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        calls += 1
        if alwaysFail { return false }
        return calls > failuresBeforeSuccess
    }
}

import XCTest
@testable import ShareMounter

@MainActor
final class AutoMountTests: XCTestCase {
    private func tempStore(_ shares: [Share]) throws -> ShareStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sm-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("shares.json")
        let store = ShareStore(fileURL: url)
        try store.save(shares)
        return store
    }

    /// A waiter that never really sleeps, so tests are instant.
    private func waiter(_ probe: PortProbe) -> ReachabilityWaiter {
        ReachabilityWaiter(probe: probe, backoff: Backoff(maxAttempts: 3), sleep: { _ in })
    }

    private func makeModel(store: ShareStore, mounter: FakeMounter, inventory: FakeInventory,
                          probe: PortProbe, login: LoginItemManaging = InMemoryLoginItems()) -> AppModel {
        AppModel(store: store, credentials: InMemoryCredentialStore(),
                 mounter: mounter, inventory: inventory,
                 reachability: waiter(probe), loginItems: login)
    }

    func testAutoMountsOnlyReachableFlaggedShares() async throws {
        let store = try tempStore([
            Share(host: "h", shareName: "a", autoMount: true),
            Share(host: "h", shareName: "b", autoMount: false),
        ])
        let mounter = FakeMounter()
        let model = makeModel(store: store, mounter: mounter, inventory: FakeInventory(),
                              probe: FakeProbe())

        await model.autoMountAll()

        XCTAssertEqual(mounter.mountCalls.count, 1)
        XCTAssertEqual(mounter.mountCalls.first?.url, "smb://h/a")
    }

    func testUnreachableShareGetsErrorAndNoMount() async throws {
        let store = try tempStore([Share(host: "h", shareName: "a", autoMount: true)])
        let mounter = FakeMounter()
        let model = makeModel(store: store, mounter: mounter, inventory: FakeInventory(),
                              probe: FakeProbe(alwaysFail: true))

        await model.autoMountAll()

        XCTAssertTrue(mounter.mountCalls.isEmpty)
        guard case .error = model.statuses.first?.state else {
            return XCTFail("expected error state for unreachable share")
        }
    }

    func testAlreadyMountedShareIsSkipped() async throws {
        let store = try tempStore([Share(host: "h", shareName: "a", autoMount: true)])
        let inventory = FakeInventory()
        inventory.mounts = [MountedVolume(from: "//h/a", path: "/Volumes/a")]
        let mounter = FakeMounter()
        let model = makeModel(store: store, mounter: mounter, inventory: inventory,
                              probe: FakeProbe())

        await model.autoMountAll()

        XCTAssertTrue(mounter.mountCalls.isEmpty)
    }

    func testLoginItemToggle() throws {
        let store = try tempStore([])
        let login = InMemoryLoginItems()
        let model = makeModel(store: store, mounter: FakeMounter(), inventory: FakeInventory(),
                              probe: FakeProbe(), login: login)

        XCTAssertFalse(model.isLoginItemEnabled)
        model.setLoginItem(true)
        XCTAssertTrue(model.isLoginItemEnabled)
        model.setLoginItem(false)
        XCTAssertFalse(model.isLoginItemEnabled)
    }
}

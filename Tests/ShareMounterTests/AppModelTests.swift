import XCTest
@testable import ShareMounter

@MainActor
final class AppModelTests: XCTestCase {
    private func tempStore(_ shares: [Share]) throws -> ShareStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sm-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("shares.json")
        let store = ShareStore(fileURL: url)
        try store.save(shares)
        return store
    }

    func testReloadMarksMountedFromInventory() throws {
        let store = try tempStore([Share(host: "h", shareName: "s")])
        let inventory = FakeInventory()
        inventory.mounts = [MountedVolume(from: "//h/s", path: "/Volumes/s")]
        let model = AppModel(store: store, credentials: InMemoryCredentialStore(),
                             mounter: FakeMounter(), inventory: inventory)
        XCTAssertEqual(model.statuses.first?.state, .mounted(path: "/Volumes/s"))
    }

    func testReloadUnmountedWhenNotInInventory() throws {
        let store = try tempStore([Share(host: "h", shareName: "s")])
        let model = AppModel(store: store, credentials: InMemoryCredentialStore(),
                             mounter: FakeMounter(), inventory: FakeInventory())
        XCTAssertEqual(model.statuses.first?.state, .unmounted)
    }

    func testPerformMountSuccessPassesCredentials() async throws {
        let share = Share(host: "h", shareName: "s", username: "alice")
        let store = try tempStore([share])
        let creds = InMemoryCredentialStore([share.credentialKey: "pw"])
        let mounter = FakeMounter()
        mounter.resultPath = "/Volumes/s"
        let model = AppModel(store: store, credentials: creds, mounter: mounter, inventory: FakeInventory())

        await model.performMount(model.shares[0])

        XCTAssertEqual(model.statuses.first?.state, .mounted(path: "/Volumes/s"))
        XCTAssertEqual(mounter.mountCalls.first?.url, "smb://h/s")
        XCTAssertEqual(mounter.mountCalls.first?.password, "pw")
        XCTAssertEqual(mounter.mountCalls.first?.username, "alice")
    }

    func testPerformMountFailureSetsErrorState() async throws {
        let store = try tempStore([Share(host: "h", shareName: "s")])
        let mounter = FakeMounter()
        mounter.mountError = MountError.failed(code: 13, message: "Permission denied")
        let model = AppModel(store: store, credentials: InMemoryCredentialStore(),
                             mounter: mounter, inventory: FakeInventory())

        await model.performMount(model.shares[0])

        guard case .error(let message) = model.statuses.first?.state else {
            return XCTFail("expected error state")
        }
        XCTAssertEqual(message, "Permission denied")
    }

    func testGuestMountSendsNoCredentials() async throws {
        let store = try tempStore([Share(host: "h", shareName: "s", isGuest: true)])
        let mounter = FakeMounter()
        let model = AppModel(store: store, credentials: InMemoryCredentialStore(),
                             mounter: mounter, inventory: FakeInventory())

        await model.performMount(model.shares[0])

        XCTAssertEqual(mounter.mountCalls.first?.guest, true)
        XCTAssertNil(mounter.mountCalls.first?.password)
    }

    func testPerformUnmountTransitionsToUnmounted() async throws {
        let store = try tempStore([Share(host: "h", shareName: "s")])
        let inventory = FakeInventory()
        inventory.mounts = [MountedVolume(from: "//h/s", path: "/Volumes/s")]
        let mounter = FakeMounter()
        let model = AppModel(store: store, credentials: InMemoryCredentialStore(),
                             mounter: mounter, inventory: inventory)

        XCTAssertEqual(model.statuses.first?.state, .mounted(path: "/Volumes/s"))
        await model.performUnmount(model.shares[0])

        XCTAssertEqual(model.statuses.first?.state, .unmounted)
        XCTAssertEqual(mounter.unmountCalls, ["/Volumes/s"])
    }

    func testAutoMountSharesFiltersFlag() throws {
        let store = try tempStore([
            Share(host: "h", shareName: "a", autoMount: true),
            Share(host: "h", shareName: "b", autoMount: false),
        ])
        let model = AppModel(store: store, credentials: InMemoryCredentialStore(),
                             mounter: FakeMounter(), inventory: FakeInventory())
        XCTAssertEqual(model.autoMountShares().map(\.shareName), ["a"])
    }
}

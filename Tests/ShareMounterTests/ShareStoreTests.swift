import XCTest
@testable import ShareMounter

final class ShareStoreTests: XCTestCase {
    private func tempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("sm-test-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("shares.json")
    }

    func testSaveLoadRoundTrip() throws {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = ShareStore(fileURL: url)
        let shares = [
            Share(displayName: "A", host: "h1", shareName: "s1", autoMount: true),
            Share(displayName: "B", host: "h2", shareName: "s2", isGuest: true),
        ]
        try store.save(shares)
        XCTAssertEqual(store.load(), shares)
    }

    func testLoadMissingFileReturnsEmpty() {
        XCTAssertEqual(ShareStore(fileURL: tempFileURL()).load(), [])
    }

    func testLoadCorruptFileReturnsEmpty() throws {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(ShareStore(fileURL: url).load(), [])
    }

    func testSaveCreatesParentDirectory() throws {
        let url = tempFileURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try ShareStore(fileURL: url).save([Share(host: "h", shareName: "s")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}

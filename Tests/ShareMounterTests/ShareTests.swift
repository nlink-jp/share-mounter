import XCTest
@testable import ShareMounter

final class ShareTests: XCTestCase {
    func testSMBURLBuilding() {
        let share = Share(host: "files.local", shareName: "public")
        XCTAssertEqual(share.smbURLString, "smb://files.local/public")
    }

    func testSMBURLEncodesShareName() {
        let share = Share(host: "h", shareName: "My Share")
        XCTAssertEqual(share.smbURLString, "smb://h/My%20Share")
    }

    func testCredentialKey() {
        let share = Share(host: "h", shareName: "sh", username: "alice")
        XCTAssertEqual(share.credentialKey, "alice@h/sh")
    }

    func testEffectiveDisplayNameFallsBackToShareName() {
        XCTAssertEqual(Share(shareName: "docs").effectiveDisplayName, "docs")
        XCTAssertEqual(Share(displayName: "Docs", shareName: "docs").effectiveDisplayName, "Docs")
    }

    func testCodableRoundTrip() throws {
        let share = Share(displayName: "D", host: "h", shareName: "sh",
                          username: "u", isGuest: false, autoMount: true)
        let data = try JSONEncoder().encode(share)
        let restored = try JSONDecoder().decode(Share.self, from: data)
        XCTAssertEqual(share, restored)
    }

    func testNoPasswordFieldIsPersisted() throws {
        let share = Share(host: "h", shareName: "sh", username: "u")
        let json = String(data: try JSONEncoder().encode(share), encoding: .utf8)!
        XCTAssertFalse(json.lowercased().contains("password"))
    }
}

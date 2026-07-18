import XCTest
@testable import ShareMounter

final class MountMatcherTests: XCTestCase {
    private let share = Share(host: "files.local", shareName: "public")

    func testMatchesUserAtHost() {
        XCTAssertTrue(MountMatcher.matches(share: share, from: "//alice@files.local/public"))
    }

    func testMatchesGuestNoUser() {
        XCTAssertTrue(MountMatcher.matches(share: share, from: "//files.local/public"))
    }

    func testMatchesDomainQualifiedUser() {
        XCTAssertTrue(MountMatcher.matches(share: share, from: "//WORKGROUP;alice@files.local/public"))
    }

    func testMatchesWithSubPath() {
        XCTAssertTrue(MountMatcher.matches(share: share, from: "//files.local/public/subdir"))
    }

    func testCaseInsensitive() {
        XCTAssertTrue(MountMatcher.matches(share: share, from: "//FILES.LOCAL/PUBLIC"))
    }

    func testPercentEncodedShareName() {
        let spaced = Share(host: "h", shareName: "My Share")
        XCTAssertTrue(MountMatcher.matches(share: spaced, from: "//h/My%20Share"))
    }

    func testDifferentShareDoesNotMatch() {
        XCTAssertFalse(MountMatcher.matches(share: share, from: "//files.local/private"))
    }

    func testDifferentHostDoesNotMatch() {
        XCTAssertFalse(MountMatcher.matches(share: share, from: "//other.local/public"))
    }

    func testLocalDiskDoesNotMatch() {
        XCTAssertFalse(MountMatcher.matches(share: share, from: "/dev/disk1s1"))
    }

    func testEmptyShareFieldsNeverMatch() {
        XCTAssertFalse(MountMatcher.matches(share: Share(), from: "//h/s"))
    }

    func testMountPathLookupFindsMatch() {
        let mounts = [
            MountedVolume(from: "//files.local/public", path: "/Volumes/public"),
            MountedVolume(from: "//x/y", path: "/Volumes/y"),
        ]
        XCTAssertEqual(MountMatcher.mountPath(for: share, in: mounts), "/Volumes/public")
    }

    func testMountPathLookupNoMatch() {
        let mounts = [MountedVolume(from: "//x/y", path: "/Volumes/y")]
        XCTAssertNil(MountMatcher.mountPath(for: share, in: mounts))
    }
}

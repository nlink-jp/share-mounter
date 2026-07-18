import XCTest
@testable import ShareMounter

final class CredentialStoreTests: XCTestCase {
    func testSetAndGet() {
        let store = InMemoryCredentialStore()
        store.setPassword("secret", for: "alice@h/sh")
        XCTAssertEqual(store.password(for: "alice@h/sh"), "secret")
    }

    func testEmptyPasswordClearsEntry() {
        let store = InMemoryCredentialStore(["k": "v"])
        store.setPassword("", for: "k")
        XCTAssertNil(store.password(for: "k"))
    }

    func testRemove() {
        let store = InMemoryCredentialStore(["k": "v"])
        store.removePassword(for: "k")
        XCTAssertNil(store.password(for: "k"))
    }

    func testMissingKeyIsNil() {
        XCTAssertNil(InMemoryCredentialStore().password(for: "nope"))
    }
}

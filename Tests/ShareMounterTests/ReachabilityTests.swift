import XCTest
@testable import ShareMounter

final class BackoffTests: XCTestCase {
    func testExponentialSchedule() {
        let backoff = Backoff(base: 1, factor: 2, maxDelay: 30, maxAttempts: 8)
        XCTAssertEqual(backoff.delay(forAttempt: 1), 1)
        XCTAssertEqual(backoff.delay(forAttempt: 2), 2)
        XCTAssertEqual(backoff.delay(forAttempt: 3), 4)
        XCTAssertEqual(backoff.delay(forAttempt: 4), 8)
        XCTAssertEqual(backoff.delay(forAttempt: 5), 16)
    }

    func testClampedToMaxDelay() {
        let backoff = Backoff(base: 1, factor: 2, maxDelay: 10, maxAttempts: 8)
        XCTAssertEqual(backoff.delay(forAttempt: 6), 10)  // 32 → clamp
        XCTAssertEqual(backoff.delay(forAttempt: 20), 10)
    }

    func testNonPositiveAttemptIsZero() {
        XCTAssertEqual(Backoff().delay(forAttempt: 0), 0)
        XCTAssertEqual(Backoff().delay(forAttempt: -3), 0)
    }
}

final class ReachabilityWaiterTests: XCTestCase {
    func testReturnsTrueImmediatelyWhenReachable() async {
        let probe = FakeProbe(failuresBeforeSuccess: 0)
        let waiter = ReachabilityWaiter(probe: probe, backoff: Backoff(maxAttempts: 5), sleep: { _ in })
        let reachable = await waiter.waitUntilReachable(host: "h")
        XCTAssertTrue(reachable)
        XCTAssertEqual(probe.calls, 1)
    }

    func testRetriesThenSucceeds() async {
        let probe = FakeProbe(failuresBeforeSuccess: 2)
        let waiter = ReachabilityWaiter(probe: probe, backoff: Backoff(maxAttempts: 5), sleep: { _ in })
        let reachable = await waiter.waitUntilReachable(host: "h")
        XCTAssertTrue(reachable)
        XCTAssertEqual(probe.calls, 3)
    }

    func testFailsAfterMaxAttempts() async {
        let probe = FakeProbe(alwaysFail: true)
        let waiter = ReachabilityWaiter(probe: probe, backoff: Backoff(maxAttempts: 4), sleep: { _ in })
        let reachable = await waiter.waitUntilReachable(host: "h")
        XCTAssertFalse(reachable)
        XCTAssertEqual(probe.calls, 4)
    }
}

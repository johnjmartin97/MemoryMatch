import XCTest
@testable import MemoryMatch

/// Proves the test target is wired to the app target and runs.
final class SmokeTests: XCTestCase {
    func testHarnessRuns() {
        XCTAssertTrue(true, "the unit test target executes")
    }
}

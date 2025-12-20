import XCTest
@testable import ZylixSwift

final class ZylixSwiftTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Initialize before each test
        try? ZylixCore.shared.initialize()
    }

    override func tearDown() {
        // Cleanup after each test
        try? ZylixCore.shared.shutdown()
        super.tearDown()
    }

    func testABIVersion() {
        XCTAssertEqual(ZylixCore.shared.abiVersion, 2, "ABI version should be 2")
    }

    func testInitialization() throws {
        XCTAssertTrue(ZylixCore.shared.isInitialized, "Core should be initialized")
    }

    func testStateAccess() {
        let state = ZylixCore.shared.state
        XCTAssertNotNil(state, "State should not be nil after initialization")
    }

    func testStateVersion() {
        let version = ZylixCore.shared.stateVersion
        XCTAssertGreaterThanOrEqual(version, 0, "State version should be non-negative")
    }

    func testEventDispatch() throws {
        // Dispatch counter increment event (0x1000)
        try ZylixCore.shared.dispatch(eventType: 0x1000)

        let state = ZylixCore.shared.state
        XCTAssertNotNil(state, "State should exist after dispatch")
    }

    func testEventQueue() throws {
        // Queue some events
        try ZylixCore.shared.queueEvent(eventType: 0x1000, priority: .normal)
        try ZylixCore.shared.queueEvent(eventType: 0x1001, priority: .high)

        XCTAssertEqual(ZylixCore.shared.queueDepth, 2, "Queue should have 2 events")

        // Process events
        let processed = ZylixCore.shared.processEvents(maxEvents: 10)
        XCTAssertEqual(processed, 2, "Should process 2 events")

        XCTAssertEqual(ZylixCore.shared.queueDepth, 0, "Queue should be empty")
    }

    func testQueueClear() throws {
        try ZylixCore.shared.queueEvent(eventType: 0x1000)
        try ZylixCore.shared.queueEvent(eventType: 0x1001)

        ZylixCore.shared.clearQueue()

        XCTAssertEqual(ZylixCore.shared.queueDepth, 0, "Queue should be cleared")
    }
}

// Zylix Test Framework - iOS Tests

import XCTest
@testable import ZylixTest

final class ZylixTestServerTests: XCTestCase {

    func testServerInitialization() {
        let server = ZylixTestServer(port: 8100)
        XCTAssertNotNil(server)
    }

    func testAnyCodableString() throws {
        let value = AnyCodable("test")
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "\"test\"")
    }

    func testAnyCodableBool() throws {
        let value = AnyCodable(true)
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "true")
    }

    func testAnyCodableNumber() throws {
        let value = AnyCodable(42)
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "42")
    }

    func testAnyCodableArray() throws {
        let value = AnyCodable([1, 2, 3])
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "[1,2,3]")
    }

    func testAnyCodableDictionary() throws {
        let value = AnyCodable(["key": "value"])
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "{\"key\":\"value\"}")
    }

    func testCommandResultSuccess() throws {
        let result = ZylixTestServer.CommandResult(sessionId: "test-123", success: true)
        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"sessionId\":\"test-123\""))
        XCTAssertTrue(json.contains("\"success\":true"))
    }

    func testCommandResultError() throws {
        let result = ZylixTestServer.CommandResult(error: "Something went wrong")
        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"error\":\"Something went wrong\""))
    }

    func testHandleInvalidPath() {
        let server = ZylixTestServer()
        let result = server.handleCommand(path: "/invalid", method: "POST", body: nil)
        XCTAssertNotNil(result.error)
        XCTAssertEqual(result.error, "Invalid path")
    }

    func testHandleSessionNotFound() {
        let server = ZylixTestServer()
        let result = server.handleCommand(path: "/session/nonexistent/element", method: "POST", body: nil)
        XCTAssertNotNil(result.error)
        XCTAssertEqual(result.error, "Session not found")
    }
}

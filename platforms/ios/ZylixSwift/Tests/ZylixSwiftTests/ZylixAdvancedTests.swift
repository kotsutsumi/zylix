import XCTest
@testable import ZylixSwift

// MARK: - Async Tests

final class ZylixAsyncTests: XCTestCase {

    // MARK: - Future Tests

    func testFutureResolves() async throws {
        let future = ZylixFuture<Int>()
        future.resolve(42)

        XCTAssertEqual(future.state, .fulfilled)
        XCTAssertEqual(future.value, 42)
    }

    func testFutureRejects() async throws {
        let future = ZylixFuture<Int>()
        future.reject(ZylixAsyncError.timeout())

        XCTAssertEqual(future.state, .rejected)
        XCTAssertNotNil(future.error)
    }

    func testFutureCancels() async throws {
        let future = ZylixFuture<Int>()
        future.cancel()

        XCTAssertEqual(future.state, .cancelled)
    }

    func testFutureThenCallback() {
        let expectation = XCTestExpectation(description: "Then callback called")
        let future = ZylixFuture<Int>()

        future.then { value in
            XCTAssertEqual(value, 100)
            expectation.fulfill()
        }

        future.resolve(100)
        wait(for: [expectation], timeout: 1.0)
    }

    func testFutureCatchCallback() {
        let expectation = XCTestExpectation(description: "Catch callback called")
        let future = ZylixFuture<Int>()

        future.catch { error in
            XCTAssertTrue(error is ZylixAsyncError)
            expectation.fulfill()
        }

        future.reject(ZylixAsyncError.networkError(message: "Test error"))
        wait(for: [expectation], timeout: 1.0)
    }

    func testFutureFromAsync() async throws {
        let future = ZylixFuture.from {
            try await Task.sleep(nanoseconds: 100_000_000)
            return "async result"
        }

        let result = try await future.await()
        XCTAssertEqual(result, "async result")
    }

    func testFutureResolved() async throws {
        let future = ZylixFuture.resolved("immediate")
        XCTAssertEqual(future.state, .fulfilled)
        XCTAssertEqual(future.value, "immediate")
    }

    func testFutureRejected() async throws {
        let future = ZylixFuture<String>.rejected(ZylixAsyncError.cancelled())
        XCTAssertEqual(future.state, .rejected)
    }

    // MARK: - HTTP Response Tests

    func testHttpResponseIsSuccess() {
        let successResponse = HttpResponse(statusCode: 200, headers: [:], body: Data())
        XCTAssertTrue(successResponse.isSuccess)

        let createdResponse = HttpResponse(statusCode: 201, headers: [:], body: Data())
        XCTAssertTrue(createdResponse.isSuccess)

        let errorResponse = HttpResponse(statusCode: 404, headers: [:], body: Data())
        XCTAssertFalse(errorResponse.isSuccess)
    }

    func testHttpResponseBodyString() {
        let body = "Hello, World!".data(using: .utf8)!
        let response = HttpResponse(statusCode: 200, headers: [:], body: body)
        XCTAssertEqual(response.bodyString, "Hello, World!")
    }

    func testHttpResponseJson() throws {
        let jsonData = "{\"key\": \"value\"}".data(using: .utf8)!
        let response = HttpResponse(statusCode: 200, headers: [:], body: jsonData)

        let json = try response.json()
        XCTAssertEqual(json["key"] as? String, "value")
    }

    // MARK: - Task Priority Tests

    func testTaskPriorityComparison() {
        XCTAssertTrue(TaskPriority.low < TaskPriority.normal)
        XCTAssertTrue(TaskPriority.normal < TaskPriority.high)
        XCTAssertTrue(TaskPriority.high < TaskPriority.critical)
    }

    // MARK: - Task Handle Tests

    func testTaskHandleInitialState() {
        let handle = ZylixTaskHandle(priority: .high)
        XCTAssertEqual(handle.state, .queued)
        XCTAssertEqual(handle.priority, .high)
        XCTAssertFalse(handle.isCancelled())
    }

    func testTaskHandleCancel() {
        let handle = ZylixTaskHandle()
        handle.cancel()
        XCTAssertTrue(handle.isCancelled())
        XCTAssertEqual(handle.state, .cancelled)
    }

    // MARK: - Debouncer Tests

    func testDebouncerCancels() async {
        let debouncer = Debouncer(delay: 0.5)
        var callCount = 0

        debouncer.debounce { callCount += 1 }
        debouncer.debounce { callCount += 1 }
        debouncer.debounce { callCount += 1 }
        debouncer.cancel()

        try? await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(callCount, 0)
    }

    // MARK: - Throttler Tests

    func testThrottlerLimitsRate() {
        let throttler = Throttler(interval: 0.5)
        var callCount = 0

        for _ in 0..<5 {
            throttler.throttle { callCount += 1 }
        }

        XCTAssertEqual(callCount, 1) // Only first call should execute
    }

    // MARK: - Async Utility Tests

    func testRetry() async throws {
        var attempts = 0

        let result = try await retry(maxAttempts: 3, initialDelay: 0.1) {
            attempts += 1
            if attempts < 3 {
                throw ZylixAsyncError.networkError(message: "Retry test")
            }
            return "success"
        }

        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(result, "success")
    }
}

// MARK: - Animation Tests

final class ZylixAnimationTests: XCTestCase {

    // MARK: - Easing Function Tests

    func testLinearEasing() {
        XCTAssertEqual(ZylixEasing.linear(0), 0)
        XCTAssertEqual(ZylixEasing.linear(0.5), 0.5)
        XCTAssertEqual(ZylixEasing.linear(1), 1)
    }

    func testEaseInQuad() {
        XCTAssertEqual(ZylixEasing.easeInQuad(0), 0)
        XCTAssertEqual(ZylixEasing.easeInQuad(1), 1)
        XCTAssertLessThan(ZylixEasing.easeInQuad(0.5), 0.5)
    }

    func testEaseOutQuad() {
        XCTAssertEqual(ZylixEasing.easeOutQuad(0), 0)
        XCTAssertEqual(ZylixEasing.easeOutQuad(1), 1)
        XCTAssertGreaterThan(ZylixEasing.easeOutQuad(0.5), 0.5)
    }

    func testEaseInOutQuad() {
        XCTAssertEqual(ZylixEasing.easeInOutQuad(0), 0)
        XCTAssertEqual(ZylixEasing.easeInOutQuad(1), 1)
        XCTAssertEqual(ZylixEasing.easeInOutQuad(0.5), 0.5, accuracy: 0.001)
    }

    func testEaseSine() {
        XCTAssertEqual(ZylixEasing.easeInSine(0), 0, accuracy: 0.001)
        XCTAssertEqual(ZylixEasing.easeOutSine(1), 1, accuracy: 0.001)
        XCTAssertEqual(ZylixEasing.easeInOutSine(0.5), 0.5, accuracy: 0.001)
    }

    func testEaseExpo() {
        XCTAssertEqual(ZylixEasing.easeInExpo(0), 0)
        XCTAssertEqual(ZylixEasing.easeOutExpo(1), 1)
    }

    func testEaseBounce() {
        XCTAssertEqual(ZylixEasing.easeOutBounce(0), 0, accuracy: 0.001)
        XCTAssertEqual(ZylixEasing.easeOutBounce(1), 1, accuracy: 0.001)
        XCTAssertEqual(ZylixEasing.easeInBounce(0), 0, accuracy: 0.001)
    }

    func testSpringEasing() {
        let result = ZylixEasing.spring(1.0, stiffness: 100, damping: 10, mass: 1)
        XCTAssertGreaterThan(result, 0)
    }

    // MARK: - SpringConfig Tests

    func testSpringConfigPresets() {
        let defaultConfig = SpringConfig.default
        XCTAssertEqual(defaultConfig.stiffness, 100)
        XCTAssertEqual(defaultConfig.damping, 10)
        XCTAssertEqual(defaultConfig.mass, 1)

        let bouncy = SpringConfig.bouncy
        XCTAssertEqual(bouncy.stiffness, 200)
        XCTAssertEqual(bouncy.damping, 5)
    }

    // MARK: - PlaybackState Tests

    func testPlaybackStates() {
        let stopped = PlaybackState.stopped
        let playing = PlaybackState.playing
        let paused = PlaybackState.paused
        let finished = PlaybackState.finished

        XCTAssertNotEqual(String(describing: stopped), String(describing: playing))
        XCTAssertNotEqual(String(describing: paused), String(describing: finished))
    }

    // MARK: - LoopMode Tests

    func testLoopModes() {
        let none = LoopMode.none
        let loop = LoopMode.loop
        let pingPong = LoopMode.pingPong
        let count = LoopMode.count(3)

        switch count {
        case .count(let n):
            XCTAssertEqual(n, 3)
        default:
            XCTFail("Expected count mode")
        }
    }

    // MARK: - Keyframe Tests

    func testKeyframeInit() {
        let keyframe = Keyframe(time: 0.5, value: 100.0)
        XCTAssertEqual(keyframe.time, 0.5)
        XCTAssertEqual(keyframe.value, 100.0)
    }

    func testKeyframeAnimation() {
        let animation = KeyframeAnimation(keyframes: [
            Keyframe(time: 0, value: 0),
            Keyframe(time: 0.5, value: 50),
            Keyframe(time: 1, value: 100)
        ])

        XCTAssertEqual(animation.value(at: 0), 0)
        XCTAssertEqual(animation.value(at: 1), 100)
        XCTAssertEqual(animation.value(at: 0.5), 50, accuracy: 1)
    }
}

// MARK: - Advanced Feature Tests

final class ZylixAdvancedFeatureTests: XCTestCase {

    // MARK: - Error Boundary Tests

    func testErrorBoundaryState() {
        let normal = ErrorBoundaryState.normal
        let error = ErrorBoundaryState.error(NSError(domain: "test", code: 1))

        switch normal {
        case .normal:
            break
        case .error:
            XCTFail("Expected normal state")
        }

        switch error {
        case .normal:
            XCTFail("Expected error state")
        case .error(let e):
            XCTAssertEqual((e as NSError).code, 1)
        }
    }

    func testErrorHandler() {
        var handledError: Error?
        let handler = ErrorHandler { error in
            handledError = error
        }

        handler(NSError(domain: "test", code: 42))
        XCTAssertEqual((handledError as NSError?)?.code, 42)
    }

    // MARK: - Suspense Tests

    func testSuspenseState() {
        let loading: SuspenseState<Int> = .loading
        let success: SuspenseState<Int> = .success(42)
        let failure: SuspenseState<Int> = .failure(NSError(domain: "test", code: 1))

        switch loading {
        case .loading: break
        default: XCTFail("Expected loading state")
        }

        switch success {
        case .success(let value):
            XCTAssertEqual(value, 42)
        default: XCTFail("Expected success state")
        }

        switch failure {
        case .failure: break
        default: XCTFail("Expected failure state")
        }
    }

    // MARK: - Modal Config Tests

    func testModalConfigDefaults() {
        let config = ModalConfig.default
        XCTAssertEqual(config.cornerRadius, 16)
        XCTAssertEqual(config.shadowRadius, 10)
        XCTAssertEqual(config.animationDuration, 0.3)
    }

    func testModalConfigCustom() {
        let config = ModalConfig(
            cornerRadius: 24,
            shadowRadius: 15,
            animationDuration: 0.5
        )
        XCTAssertEqual(config.cornerRadius, 24)
        XCTAssertEqual(config.shadowRadius, 15)
        XCTAssertEqual(config.animationDuration, 0.5)
    }

    // MARK: - Virtual List Config Tests

    func testVirtualListConfigDefaults() {
        let config = VirtualListConfig()
        XCTAssertEqual(config.itemHeight, 44)
        XCTAssertEqual(config.overscan, 5)
        XCTAssertEqual(config.loadMoreThreshold, 10)
    }

    func testVirtualListConfigCustom() {
        let config = VirtualListConfig(
            itemHeight: 60,
            overscan: 10,
            loadMoreThreshold: 5
        )
        XCTAssertEqual(config.itemHeight, 60)
        XCTAssertEqual(config.overscan, 10)
        XCTAssertEqual(config.loadMoreThreshold, 5)
    }
}

// MARK: - Hot Reload Tests

final class ZylixHotReloadTests: XCTestCase {

    func testHotReloadStates() {
        XCTAssertEqual(HotReloadState.disconnected.rawValue, "disconnected")
        XCTAssertEqual(HotReloadState.connecting.rawValue, "connecting")
        XCTAssertEqual(HotReloadState.connected.rawValue, "connected")
        XCTAssertEqual(HotReloadState.reloading.rawValue, "reloading")
        XCTAssertEqual(HotReloadState.error.rawValue, "error")
    }

    func testBuildError() {
        let error = BuildError(
            file: "test.swift",
            line: 42,
            column: 10,
            message: "Test error",
            severity: "error"
        )

        XCTAssertEqual(error.file, "test.swift")
        XCTAssertEqual(error.line, 42)
        XCTAssertEqual(error.column, 10)
        XCTAssertEqual(error.message, "Test error")
        XCTAssertEqual(error.severity, "error")
        XCTAssertEqual(error.location, "test.swift:42:10")
    }

    func testNotificationNames() {
        XCTAssertEqual(Notification.Name.zylixHotReload.rawValue, "ZylixHotReload")
        XCTAssertEqual(Notification.Name.zylixHotUpdate.rawValue, "ZylixHotUpdate")
    }
}

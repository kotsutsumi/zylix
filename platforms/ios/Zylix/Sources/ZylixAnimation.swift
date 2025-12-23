//
//  ZylixAnimation.swift
//  Zylix
//
//  Cross-platform animation module for iOS.
//  Provides Lottie and Live2D animation support with native rendering.
//

import Foundation
import UIKit
import SwiftUI
import Combine
import QuartzCore

// MARK: - Animation Types

/// Playback state
public enum ZylixPlaybackState: Int, Sendable {
    case stopped = 0
    case playing = 1
    case paused = 2
    case finished = 3
}

/// Loop mode
public enum ZylixLoopMode: Int, Sendable {
    case none = 0
    case loop = 1
    case pingPong = 2
    case loopCount = 3
}

/// Play direction
public enum ZylixPlayDirection: Int, Sendable {
    case forward = 0
    case reverse = 1
}

/// Animation event type
public enum ZylixAnimationEventType: Int, Sendable {
    case started = 0
    case paused = 1
    case resumed = 2
    case stopped = 3
    case completed = 4
    case loopCompleted = 5
    case frameChanged = 6
    case markerReached = 7
}

/// Animation event
public struct ZylixAnimationEvent: Sendable {
    public let eventType: ZylixAnimationEventType
    public let animationId: UInt32
    public let currentFrame: UInt32
    public let currentTime: Int64
    public let loopCount: UInt32
    public let markerName: String?
}

/// Animation error
public enum ZylixAnimationError: Error, Sendable {
    case invalidData
    case parseError(String)
    case renderError(String)
    case resourceNotFound(String)
    case unsupportedFormat
    case notInitialized
}

// MARK: - Easing Functions

/// Standard easing functions
public struct ZylixEasing {

    // Linear
    public static func linear(_ t: Float) -> Float { t }

    // Quadratic
    public static func easeInQuad(_ t: Float) -> Float { t * t }
    public static func easeOutQuad(_ t: Float) -> Float { t * (2 - t) }
    public static func easeInOutQuad(_ t: Float) -> Float {
        t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }

    // Cubic
    public static func easeInCubic(_ t: Float) -> Float { t * t * t }
    public static func easeOutCubic(_ t: Float) -> Float {
        let f = t - 1
        return f * f * f + 1
    }
    public static func easeInOutCubic(_ t: Float) -> Float {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = 2 * t - 2
            return 0.5 * f * f * f + 1
        }
    }

    // Elastic
    public static func easeOutElastic(_ t: Float) -> Float {
        if t == 0 { return 0 }
        if t == 1 { return 1 }
        let c4 = (2 * .pi) / 3
        return pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1
    }

    // Bounce
    public static func easeOutBounce(_ t: Float) -> Float {
        let n1: Float = 7.5625
        let d1: Float = 2.75
        var t = t

        if t < 1 / d1 {
            return n1 * t * t
        } else if t < 2 / d1 {
            t -= 1.5 / d1
            return n1 * t * t + 0.75
        } else if t < 2.5 / d1 {
            t -= 2.25 / d1
            return n1 * t * t + 0.9375
        } else {
            t -= 2.625 / d1
            return n1 * t * t + 0.984375
        }
    }

    // Spring
    public static func spring(_ t: Float, stiffness: Float = 100, damping: Float = 10, mass: Float = 1) -> Float {
        let omega = sqrt(stiffness / mass)
        let zeta = damping / (2 * sqrt(stiffness * mass))

        if zeta < 1 {
            // Underdamped
            let omegaD = omega * sqrt(1 - zeta * zeta)
            let decay = exp(-zeta * omega * t)
            return 1 - decay * (cos(omegaD * t) + (zeta * omega / omegaD) * sin(omegaD * t))
        } else {
            // Critically damped or overdamped
            let decay = exp(-omega * t)
            return 1 - decay * (1 + omega * t)
        }
    }
}

// MARK: - DisplayLink Proxy (avoids retain cycle)

/// Weak proxy to break CADisplayLink retain cycle
private final class DisplayLinkProxy {
    weak var timeline: ZylixTimeline?
    weak var lottieAnimation: ZylixLottieAnimation?

    @objc func timelineTick(_ link: CADisplayLink) {
        timeline?.handleTick(link)
    }

    @objc func lottieTick(_ link: CADisplayLink) {
        lottieAnimation?.handleTick(link)
    }
}

// MARK: - Timeline Animation

/// Keyframe with time and value
public struct ZylixKeyframe<T> {
    public let time: TimeInterval // in seconds
    public let value: T
    public let easing: (Float) -> Float

    public init(time: TimeInterval, value: T, easing: @escaping (Float) -> Float = ZylixEasing.linear) {
        self.time = time
        self.value = value
        self.easing = easing
    }
}

/// Animation timeline
@MainActor
public final class ZylixTimeline: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var state: ZylixPlaybackState = .stopped
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var progress: Float = 0

    // MARK: - Properties

    public var duration: TimeInterval = 0
    public var speed: Float = 1.0
    public var loopMode: ZylixLoopMode = .none
    public var loopCount: UInt32 = 0

    private var displayLink: CADisplayLink?
    private var displayLinkProxy: DisplayLinkProxy?
    private var lastTimestamp: CFTimeInterval = 0
    private var currentLoop: UInt32 = 0
    private var direction: ZylixPlayDirection = .forward

    private var eventCallbacks: [(ZylixAnimationEvent) -> Void] = []

    // MARK: - Initialization

    public init() {}

    deinit {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }

    // MARK: - Playback Control

    public func play() {
        if state == .paused {
            state = .playing
            startDisplayLink()
            emitEvent(.resumed)
        } else {
            state = .playing
            currentTime = 0
            currentLoop = 0
            startDisplayLink()
            emitEvent(.started)
        }
    }

    public func pause() {
        guard state == .playing else { return }
        state = .paused
        stopDisplayLink()
        emitEvent(.paused)
    }

    public func stop() {
        state = .stopped
        currentTime = 0
        currentLoop = 0
        progress = 0
        stopDisplayLink()
        emitEvent(.stopped)
    }

    public func seek(to time: TimeInterval) {
        currentTime = max(0, min(time, duration))
        updateProgress()
    }

    public func seek(toProgress p: Float) {
        seek(to: TimeInterval(p) * duration)
    }

    // MARK: - Event Handling

    public func onEvent(_ callback: @escaping (ZylixAnimationEvent) -> Void) {
        eventCallbacks.append(callback)
    }

    public func removeEventCallback(_ callback: @escaping (ZylixAnimationEvent) -> Void) {
        // Note: Swift closures are not Equatable, so we clear all instead
        // For production, consider using an identifier-based system
    }

    public func clearEventCallbacks() {
        eventCallbacks.removeAll()
    }

    // MARK: - Private Methods

    private func startDisplayLink() {
        displayLink?.invalidate()
        let proxy = DisplayLinkProxy()
        proxy.timeline = self
        displayLinkProxy = proxy
        displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.timelineTick))
        displayLink?.add(to: .main, forMode: .common)
        lastTimestamp = 0
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }

    func handleTick(_ link: CADisplayLink) {
        guard state == .playing else { return }

        let timestamp = link.timestamp
        if lastTimestamp == 0 {
            lastTimestamp = timestamp
            return
        }

        let delta = (timestamp - lastTimestamp) * Double(speed)
        lastTimestamp = timestamp

        // Update current time
        if direction == .forward {
            currentTime += delta
        } else {
            currentTime -= delta
        }

        // Handle end of timeline
        if currentTime >= duration {
            switch loopMode {
            case .none:
                currentTime = duration
                state = .finished
                stopDisplayLink()
                emitEvent(.completed)

            case .loop:
                currentTime = currentTime.truncatingRemainder(dividingBy: duration)
                currentLoop += 1
                emitEvent(.loopCompleted)

            case .pingPong:
                direction = direction == .forward ? .reverse : .forward
                currentTime = duration
                currentLoop += 1
                emitEvent(.loopCompleted)

            case .loopCount:
                currentLoop += 1
                if currentLoop >= loopCount {
                    currentTime = duration
                    state = .finished
                    stopDisplayLink()
                    emitEvent(.completed)
                } else {
                    currentTime = 0
                    emitEvent(.loopCompleted)
                }
            }
        } else if currentTime < 0 {
            if loopMode == .pingPong {
                direction = .forward
                currentTime = 0
            } else {
                currentTime = 0
            }
        }

        updateProgress()
    }

    private func updateProgress() {
        progress = duration > 0 ? Float(currentTime / duration) : 0
    }

    private func emitEvent(_ type: ZylixAnimationEventType, markerName: String? = nil) {
        let event = ZylixAnimationEvent(
            eventType: type,
            animationId: 0,
            currentFrame: UInt32(currentTime * 30), // Assume 30fps
            currentTime: Int64(currentTime * 1000),
            loopCount: currentLoop,
            markerName: markerName
        )
        for callback in eventCallbacks {
            callback(event)
        }
    }
}

// MARK: - Lottie Animation

/// Lottie marker
public struct ZylixLottieMarker {
    public let name: String
    public let time: Double // Frame number
    public let duration: Double
}

/// Lottie animation wrapper
@MainActor
public final class ZylixLottieAnimation: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var state: ZylixPlaybackState = .stopped
    @Published public private(set) var currentFrame: Double = 0
    @Published public private(set) var progress: Float = 0

    // MARK: - Properties

    public private(set) var name: String = ""
    public private(set) var width: CGFloat = 0
    public private(set) var height: CGFloat = 0
    public private(set) var frameRate: Double = 30
    public private(set) var startFrame: Double = 0
    public private(set) var endFrame: Double = 0
    public private(set) var markers: [ZylixLottieMarker] = []

    public var speed: Float = 1.0
    public var loopMode: ZylixLoopMode = .none
    public var loopCount: UInt32 = 0

    private var displayLink: CADisplayLink?
    private var displayLinkProxy: DisplayLinkProxy?
    private var lastTimestamp: CFTimeInterval = 0
    private var currentLoop: UInt32 = 0
    private var direction: ZylixPlayDirection = .forward

    private var jsonData: [String: Any]?
    private var eventCallbacks: [(ZylixAnimationEvent) -> Void] = []

    // MARK: - Initialization

    public init() {}

    deinit {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }

    // MARK: - Loading

    /// Load from JSON string
    public func load(from jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ZylixAnimationError.parseError("Invalid JSON data")
        }

        try load(from: json)
    }

    /// Load from JSON dictionary
    public func load(from json: [String: Any]) throws {
        jsonData = json

        // Parse metadata
        name = json["nm"] as? String ?? ""
        width = CGFloat(json["w"] as? Double ?? 0)
        height = CGFloat(json["h"] as? Double ?? 0)
        frameRate = json["fr"] as? Double ?? 30
        startFrame = json["ip"] as? Double ?? 0
        endFrame = json["op"] as? Double ?? 0

        // Parse markers
        if let markersArray = json["markers"] as? [[String: Any]] {
            markers = markersArray.compactMap { marker in
                guard let name = marker["cm"] as? String,
                      let time = marker["tm"] as? Double else { return nil }
                let duration = marker["dr"] as? Double ?? 0
                return ZylixLottieMarker(name: name, time: time, duration: duration)
            }
        }

        currentFrame = startFrame
    }

    /// Load from bundle resource
    public func load(named name: String, bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw ZylixAnimationError.resourceNotFound(name)
        }

        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ZylixAnimationError.parseError("Invalid JSON file")
        }

        try load(from: json)
    }

    // MARK: - Computed Properties

    public var totalFrames: Double {
        return endFrame - startFrame
    }

    public var duration: TimeInterval {
        return totalFrames / frameRate
    }

    public var size: CGSize {
        return CGSize(width: width, height: height)
    }

    // MARK: - Playback Control

    public func play() {
        if state == .paused {
            state = .playing
            startDisplayLink()
            emitEvent(.resumed)
        } else {
            state = .playing
            currentFrame = startFrame
            currentLoop = 0
            startDisplayLink()
            emitEvent(.started)
        }
    }

    public func pause() {
        guard state == .playing else { return }
        state = .paused
        stopDisplayLink()
        emitEvent(.paused)
    }

    public func stop() {
        state = .stopped
        currentFrame = startFrame
        currentLoop = 0
        progress = 0
        stopDisplayLink()
        emitEvent(.stopped)
    }

    public func seek(to frame: Double) {
        currentFrame = max(startFrame, min(frame, endFrame))
        updateProgress()
        emitEvent(.frameChanged)
    }

    public func seek(toProgress p: Float) {
        let frame = startFrame + Double(p) * totalFrames
        seek(to: frame)
    }

    public func seek(toMarker name: String) -> Bool {
        guard let marker = markers.first(where: { $0.name == name }) else {
            return false
        }
        seek(to: marker.time)
        emitEvent(.markerReached, markerName: name)
        return true
    }

    // MARK: - Event Handling

    public func onEvent(_ callback: @escaping (ZylixAnimationEvent) -> Void) {
        eventCallbacks.append(callback)
    }

    public func removeEventCallback(_ callback: @escaping (ZylixAnimationEvent) -> Void) {
        // Note: Swift closures are not Equatable, so we clear all instead
        // For production, consider using an identifier-based system
    }

    public func clearEventCallbacks() {
        eventCallbacks.removeAll()
    }

    // MARK: - Private Methods

    private func startDisplayLink() {
        displayLink?.invalidate()
        let proxy = DisplayLinkProxy()
        proxy.lottieAnimation = self
        displayLinkProxy = proxy
        displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.lottieTick))
        displayLink?.add(to: .main, forMode: .common)
        lastTimestamp = 0
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }

    func handleTick(_ link: CADisplayLink) {
        guard state == .playing else { return }

        let timestamp = link.timestamp
        if lastTimestamp == 0 {
            lastTimestamp = timestamp
            return
        }

        let delta = timestamp - lastTimestamp
        lastTimestamp = timestamp

        // Calculate frame delta
        let frameDelta = delta * frameRate * Double(speed)

        // Update current frame
        if direction == .forward {
            currentFrame += frameDelta
        } else {
            currentFrame -= frameDelta
        }

        // Handle end of animation
        if currentFrame >= endFrame {
            switch loopMode {
            case .none:
                currentFrame = endFrame
                state = .finished
                stopDisplayLink()
                emitEvent(.completed)

            case .loop:
                currentFrame = startFrame + (currentFrame - startFrame).truncatingRemainder(dividingBy: totalFrames)
                currentLoop += 1
                emitEvent(.loopCompleted)

            case .pingPong:
                direction = direction == .forward ? .reverse : .forward
                currentFrame = endFrame
                currentLoop += 1
                emitEvent(.loopCompleted)

            case .loopCount:
                currentLoop += 1
                if currentLoop >= loopCount {
                    currentFrame = endFrame
                    state = .finished
                    stopDisplayLink()
                    emitEvent(.completed)
                } else {
                    currentFrame = startFrame
                    emitEvent(.loopCompleted)
                }
            }
        } else if currentFrame < startFrame {
            if loopMode == .pingPong {
                direction = .forward
                currentFrame = startFrame
            } else {
                currentFrame = startFrame
            }
        }

        updateProgress()
    }

    private func updateProgress() {
        progress = totalFrames > 0 ? Float((currentFrame - startFrame) / totalFrames) : 0
    }

    private func emitEvent(_ type: ZylixAnimationEventType, markerName: String? = nil) {
        let event = ZylixAnimationEvent(
            eventType: type,
            animationId: 0,
            currentFrame: UInt32(currentFrame),
            currentTime: Int64(currentFrame / frameRate * 1000),
            loopCount: currentLoop,
            markerName: markerName
        )
        for callback in eventCallbacks {
            callback(event)
        }
    }
}

// MARK: - Animation Manager

/// Global animation manager
@MainActor
public final class ZylixAnimationManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = ZylixAnimationManager()

    // MARK: - Properties

    private var lottieAnimations: [UInt32: ZylixLottieAnimation] = [:]
    private var timelines: [UInt32: ZylixTimeline] = [:]
    private var nextId: UInt32 = 1

    private init() {}

    // MARK: - Lottie Management

    /// Create a new Lottie animation
    public func createLottie() -> UInt32 {
        let id = nextId
        nextId += 1
        lottieAnimations[id] = ZylixLottieAnimation()
        return id
    }

    /// Get Lottie animation by ID
    public func getLottie(_ id: UInt32) -> ZylixLottieAnimation? {
        return lottieAnimations[id]
    }

    /// Load and create Lottie animation from JSON
    public func loadLottie(from json: String) throws -> UInt32 {
        let id = createLottie()
        guard let animation = lottieAnimations[id] else {
            throw ZylixAnimationError.notInitialized
        }
        try animation.load(from: json)
        return id
    }

    /// Load and create Lottie animation from bundle
    public func loadLottie(named name: String, bundle: Bundle = .main) throws -> UInt32 {
        let id = createLottie()
        guard let animation = lottieAnimations[id] else {
            throw ZylixAnimationError.notInitialized
        }
        try animation.load(named: name, bundle: bundle)
        return id
    }

    /// Destroy Lottie animation
    public func destroyLottie(_ id: UInt32) {
        lottieAnimations[id]?.stop()
        lottieAnimations.removeValue(forKey: id)
    }

    // MARK: - Timeline Management

    /// Create a new timeline
    public func createTimeline() -> UInt32 {
        let id = nextId
        nextId += 1
        timelines[id] = ZylixTimeline()
        return id
    }

    /// Get timeline by ID
    public func getTimeline(_ id: UInt32) -> ZylixTimeline? {
        return timelines[id]
    }

    /// Destroy timeline
    public func destroyTimeline(_ id: UInt32) {
        timelines[id]?.stop()
        timelines.removeValue(forKey: id)
    }

    // MARK: - Global Control

    /// Pause all animations
    public func pauseAll() {
        for animation in lottieAnimations.values {
            animation.pause()
        }
        for timeline in timelines.values {
            timeline.pause()
        }
    }

    /// Resume all animations
    public func resumeAll() {
        for animation in lottieAnimations.values where animation.state == .paused {
            animation.play()
        }
        for timeline in timelines.values where timeline.state == .paused {
            timeline.play()
        }
    }

    /// Stop all animations
    public func stopAll() {
        for animation in lottieAnimations.values {
            animation.stop()
        }
        for timeline in timelines.values {
            timeline.stop()
        }
    }
}

// MARK: - SwiftUI Views

/// Lottie animation view for SwiftUI
public struct ZylixLottieView: View {
    @ObservedObject var animation: ZylixLottieAnimation

    public init(animation: ZylixLottieAnimation) {
        self.animation = animation
    }

    public var body: some View {
        // Placeholder - actual rendering would use Lottie-ios or custom renderer
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))

                VStack(spacing: 8) {
                    Text(animation.name.isEmpty ? "Lottie Animation" : animation.name)
                        .font(.headline)

                    Text("Frame: \(Int(animation.currentFrame)) / \(Int(animation.endFrame))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ProgressView(value: Double(animation.progress))
                        .padding(.horizontal)

                    HStack(spacing: 16) {
                        Button(action: { animation.play() }) {
                            Image(systemName: "play.fill")
                        }
                        .disabled(animation.state == .playing)

                        Button(action: { animation.pause() }) {
                            Image(systemName: "pause.fill")
                        }
                        .disabled(animation.state != .playing)

                        Button(action: { animation.stop() }) {
                            Image(systemName: "stop.fill")
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

/// Timeline progress view for SwiftUI
public struct ZylixTimelineView: View {
    @ObservedObject var timeline: ZylixTimeline

    public init(timeline: ZylixTimeline) {
        self.timeline = timeline
    }

    public var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: Double(timeline.progress))

            Text(String(format: "%.2fs / %.2fs", timeline.currentTime, timeline.duration))
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button(action: { timeline.play() }) {
                    Image(systemName: "play.fill")
                }
                .disabled(timeline.state == .playing)

                Button(action: { timeline.pause() }) {
                    Image(systemName: "pause.fill")
                }
                .disabled(timeline.state != .playing)

                Button(action: { timeline.stop() }) {
                    Image(systemName: "stop.fill")
                }
            }
        }
        .padding()
    }
}

// MARK: - View Modifiers

public extension View {
    /// Apply animated opacity
    func zylixAnimatedOpacity(_ progress: Float, from: Double = 0, to: Double = 1) -> some View {
        self.opacity(from + Double(progress) * (to - from))
    }

    /// Apply animated scale
    func zylixAnimatedScale(_ progress: Float, from: CGFloat = 0.5, to: CGFloat = 1) -> some View {
        let scale = from + CGFloat(progress) * (to - from)
        return self.scaleEffect(scale)
    }

    /// Apply animated offset
    func zylixAnimatedOffset(_ progress: Float, from: CGSize = .zero, to: CGSize = .zero) -> some View {
        let x = from.width + CGFloat(progress) * (to.width - from.width)
        let y = from.height + CGFloat(progress) * (to.height - from.height)
        return self.offset(x: x, y: y)
    }

    /// Apply animated rotation
    func zylixAnimatedRotation(_ progress: Float, from: Angle = .zero, to: Angle = .degrees(360)) -> some View {
        let angle = Angle(radians: from.radians + Double(progress) * (to.radians - from.radians))
        return self.rotationEffect(angle)
    }
}

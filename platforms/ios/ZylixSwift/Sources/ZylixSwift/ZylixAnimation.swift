// ZylixAnimation.swift - iOS Animation System for Zylix
//
// Provides comprehensive animation support:
// - Easing functions
// - Spring physics
// - Timeline animations
// - Keyframes
// - Transition components

import SwiftUI
import Combine

// MARK: - Easing Functions

/// Standard easing functions
public enum ZylixEasing {
    // Linear
    public static func linear(_ t: Double) -> Double { t }

    // Quadratic
    public static func easeInQuad(_ t: Double) -> Double { t * t }
    public static func easeOutQuad(_ t: Double) -> Double { t * (2 - t) }
    public static func easeInOutQuad(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }

    // Cubic
    public static func easeInCubic(_ t: Double) -> Double { t * t * t }
    public static func easeOutCubic(_ t: Double) -> Double {
        let f = t - 1
        return f * f * f + 1
    }
    public static func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = 2 * t - 2
            return 0.5 * f * f * f + 1
        }
    }

    // Quartic
    public static func easeInQuart(_ t: Double) -> Double { t * t * t * t }
    public static func easeOutQuart(_ t: Double) -> Double {
        let f = t - 1
        return 1 - f * f * f * f
    }
    public static func easeInOutQuart(_ t: Double) -> Double {
        if t < 0.5 {
            return 8 * t * t * t * t
        } else {
            let f = t - 1
            return 1 - 8 * f * f * f * f
        }
    }

    // Sinusoidal
    public static func easeInSine(_ t: Double) -> Double {
        1 - cos(t * .pi / 2)
    }
    public static func easeOutSine(_ t: Double) -> Double {
        sin(t * .pi / 2)
    }
    public static func easeInOutSine(_ t: Double) -> Double {
        0.5 * (1 - cos(.pi * t))
    }

    // Exponential
    public static func easeInExpo(_ t: Double) -> Double {
        t == 0 ? 0 : pow(2, 10 * (t - 1))
    }
    public static func easeOutExpo(_ t: Double) -> Double {
        t == 1 ? 1 : 1 - pow(2, -10 * t)
    }
    public static func easeInOutExpo(_ t: Double) -> Double {
        if t == 0 { return 0 }
        if t == 1 { return 1 }
        if t < 0.5 {
            return 0.5 * pow(2, 20 * t - 10)
        } else {
            return 1 - 0.5 * pow(2, -20 * t + 10)
        }
    }

    // Elastic
    public static func easeInElastic(_ t: Double) -> Double {
        if t == 0 { return 0 }
        if t == 1 { return 1 }
        let c4 = (2 * .pi) / 3
        return -pow(2, 10 * t - 10) * sin((t * 10 - 10.75) * c4)
    }
    public static func easeOutElastic(_ t: Double) -> Double {
        if t == 0 { return 0 }
        if t == 1 { return 1 }
        let c4 = (2 * .pi) / 3
        return pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1
    }

    // Bounce
    public static func easeOutBounce(_ t: Double) -> Double {
        let n1 = 7.5625
        let d1 = 2.75
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
    public static func easeInBounce(_ t: Double) -> Double {
        1 - easeOutBounce(1 - t)
    }

    // Spring
    public static func spring(
        _ t: Double,
        stiffness: Double = 100,
        damping: Double = 10,
        mass: Double = 1
    ) -> Double {
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

// MARK: - Spring Animation

/// Spring configuration
public struct SpringConfig {
    public var stiffness: Double
    public var damping: Double
    public var mass: Double

    public init(stiffness: Double = 100, damping: Double = 10, mass: Double = 1) {
        self.stiffness = stiffness
        self.damping = damping
        self.mass = mass
    }

    public static let `default` = SpringConfig()
    public static let gentle = SpringConfig(stiffness: 50, damping: 8)
    public static let bouncy = SpringConfig(stiffness: 200, damping: 5)
    public static let stiff = SpringConfig(stiffness: 300, damping: 20)
}

/// Spring value animator
@MainActor
public class SpringValue: ObservableObject {
    @Published public private(set) var value: Double
    @Published public private(set) var velocity: Double = 0

    private var target: Double
    private let config: SpringConfig
    private var displayLink: CADisplayLink?

    public init(initialValue: Double, config: SpringConfig = .default) {
        self.value = initialValue
        self.target = initialValue
        self.config = config
    }

    public func set(_ newTarget: Double) {
        target = newTarget
        startAnimation()
    }

    private func startAnimation() {
        stopAnimation()

        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func update(_ displayLink: CADisplayLink) {
        let dt = displayLink.targetTimestamp - displayLink.timestamp
        let dt2 = dt * dt

        let acceleration = config.stiffness * (target - value) - config.damping * velocity
        velocity += acceleration * dt / config.mass
        value += velocity * dt

        // Check if settled
        if abs(value - target) < 0.001 && abs(velocity) < 0.001 {
            value = target
            velocity = 0
            stopAnimation()
        }
    }
}

/// Hook for spring animations
public func useSpring(initial: Double, config: SpringConfig = .default) -> SpringValue {
    SpringValue(initialValue: initial, config: config)
}

// MARK: - Timeline Animation

/// Playback state
public enum PlaybackState {
    case stopped
    case playing
    case paused
    case finished
}

/// Loop mode
public enum LoopMode {
    case none
    case loop
    case pingPong
    case count(Int)
}

/// Animation timeline
@MainActor
public class Timeline: ObservableObject {
    @Published public private(set) var state: PlaybackState = .stopped
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var progress: Double = 0

    public var duration: TimeInterval = 1
    public var speed: Double = 1
    public var loopMode: LoopMode = .none

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var pausedTime: TimeInterval = 0
    private var currentLoopCount = 0
    private var isReversing = false

    public init(duration: TimeInterval = 1) {
        self.duration = duration
    }

    public func play() {
        if state == .paused {
            startTime = CACurrentMediaTime() - pausedTime
        } else {
            startTime = CACurrentMediaTime()
            currentTime = 0
            currentLoopCount = 0
            isReversing = false
        }
        state = .playing
        startDisplayLink()
    }

    public func pause() {
        guard state == .playing else { return }
        pausedTime = currentTime
        state = .paused
        stopDisplayLink()
    }

    public func stop() {
        state = .stopped
        currentTime = 0
        progress = 0
        currentLoopCount = 0
        isReversing = false
        stopDisplayLink()
    }

    public func seek(to time: TimeInterval) {
        currentTime = max(0, min(time, duration))
        updateProgress()
    }

    public func seekToProgress(_ p: Double) {
        seek(to: p * duration)
    }

    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func update(_ displayLink: CADisplayLink) {
        guard state == .playing else { return }

        let elapsed = (CACurrentMediaTime() - startTime) * speed

        if isReversing {
            currentTime = duration - (elapsed.truncatingRemainder(dividingBy: duration))
        } else {
            currentTime = elapsed.truncatingRemainder(dividingBy: duration)
        }

        // Check for completion
        if elapsed >= duration {
            switch loopMode {
            case .none:
                currentTime = duration
                state = .finished
                stopDisplayLink()
            case .loop:
                startTime = CACurrentMediaTime()
                currentLoopCount += 1
            case .pingPong:
                isReversing.toggle()
                startTime = CACurrentMediaTime()
                currentLoopCount += 1
            case .count(let maxLoops):
                currentLoopCount += 1
                if currentLoopCount >= maxLoops {
                    currentTime = duration
                    state = .finished
                    stopDisplayLink()
                } else {
                    startTime = CACurrentMediaTime()
                }
            }
        }

        updateProgress()
    }

    private func updateProgress() {
        progress = duration > 0 ? currentTime / duration : 0
    }
}

// MARK: - Keyframe Animation

/// Keyframe definition
public struct Keyframe<Value> {
    public let time: Double // 0-1 normalized
    public let value: Value
    public let easing: (Double) -> Double

    public init(time: Double, value: Value, easing: @escaping (Double) -> Double = ZylixEasing.linear) {
        self.time = time
        self.value = value
        self.easing = easing
    }
}

/// Keyframe animation for numeric values
public struct KeyframeAnimation {
    private let keyframes: [Keyframe<Double>]

    public init(keyframes: [Keyframe<Double>]) {
        self.keyframes = keyframes.sorted { $0.time < $1.time }
    }

    public func value(at progress: Double) -> Double {
        guard !keyframes.isEmpty else { return 0 }
        guard keyframes.count > 1 else { return keyframes[0].value }

        // Find surrounding keyframes
        var prev = keyframes[0]
        var next = keyframes[keyframes.count - 1]

        for i in 0..<keyframes.count - 1 {
            if progress >= keyframes[i].time && progress <= keyframes[i + 1].time {
                prev = keyframes[i]
                next = keyframes[i + 1]
                break
            }
        }

        // Calculate interpolation
        let segmentDuration = next.time - prev.time
        guard segmentDuration > 0 else { return prev.value }

        let segmentProgress = (progress - prev.time) / segmentDuration
        let easedProgress = next.easing(segmentProgress)

        return prev.value + (next.value - prev.value) * easedProgress
    }
}

// MARK: - Transition Components

/// Transition wrapper for animating view appearance
public struct Transition<Content: View>: View {
    let isVisible: Bool
    let content: () -> Content
    let animation: Animation
    let transition: AnyTransition

    public init(
        isVisible: Bool,
        animation: Animation = .easeInOut(duration: 0.3),
        transition: AnyTransition = .opacity,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isVisible = isVisible
        self.animation = animation
        self.transition = transition
        self.content = content
    }

    public var body: some View {
        if isVisible {
            content()
                .transition(transition)
        }
    }
}

/// Transition group for animating lists
public struct TransitionGroup<Data: RandomAccessCollection, Content: View>: View
where Data.Element: Identifiable {
    let data: Data
    let animation: Animation
    let transition: AnyTransition
    let content: (Data.Element) -> Content

    public init(
        _ data: Data,
        animation: Animation = .easeInOut(duration: 0.3),
        transition: AnyTransition = .opacity.combined(with: .move(edge: .leading)),
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.animation = animation
        self.transition = transition
        self.content = content
    }

    public var body: some View {
        ForEach(data) { item in
            content(item)
                .transition(transition)
        }
        .animation(animation, value: data.count)
    }
}

// MARK: - Animation Modifiers

extension View {
    /// Apply eased animation based on progress
    public func animatedOpacity(progress: Double, from: Double = 0, to: Double = 1) -> some View {
        let value = from + progress * (to - from)
        return opacity(value)
    }

    /// Apply animated scale
    public func animatedScale(progress: Double, from: Double = 0.5, to: Double = 1) -> some View {
        let value = from + progress * (to - from)
        return scaleEffect(value)
    }

    /// Apply animated rotation
    public func animatedRotation(progress: Double, from: Double = 0, to: Double = 360) -> some View {
        let angle = from + progress * (to - from)
        return rotationEffect(.degrees(angle))
    }

    /// Apply animated offset
    public func animatedOffset(
        progress: Double,
        fromX: CGFloat = 0, fromY: CGFloat = 0,
        toX: CGFloat = 0, toY: CGFloat = 0
    ) -> some View {
        let x = fromX + progress * (toX - fromX)
        let y = fromY + progress * (toY - fromY)
        return offset(x: x, y: y)
    }

    /// Shake animation
    public func shake(amount: CGFloat = 10, shakesPerUnit: CGFloat = 3) -> some View {
        modifier(ShakeModifier(amount: amount, shakesPerUnit: shakesPerUnit))
    }
}

/// Shake animation modifier
struct ShakeModifier: GeometryEffect {
    var amount: CGFloat
    var shakesPerUnit: CGFloat
    var animatableData: CGFloat = 0

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * shakesPerUnit),
            y: 0
        ))
    }
}

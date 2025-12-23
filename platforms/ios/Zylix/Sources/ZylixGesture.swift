//
//  ZylixGesture.swift
//  Zylix
//
//  Unified Gesture Recognition System for iOS
//  Supports: Tap, Long Press, Pan, Swipe, Pinch, Rotation
//

import UIKit

// MARK: - Gesture State

public enum ZylixGestureState {
    case possible
    case began
    case changed
    case ended
    case cancelled
    case failed

    var isActive: Bool {
        return self == .began || self == .changed
    }

    var isEnded: Bool {
        return self == .ended || self == .cancelled || self == .failed
    }

    init(from uiState: UIGestureRecognizer.State) {
        switch uiState {
        case .possible: self = .possible
        case .began: self = .began
        case .changed: self = .changed
        case .ended: self = .ended
        case .cancelled: self = .cancelled
        case .failed: self = .failed
        @unknown default: self = .possible
        }
    }
}

// MARK: - Swipe Direction

public enum ZylixSwipeDirection {
    case up
    case down
    case left
    case right

    var uiDirection: UISwipeGestureRecognizer.Direction {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }

    var isHorizontal: Bool {
        return self == .left || self == .right
    }

    var isVertical: Bool {
        return self == .up || self == .down
    }

    var opposite: ZylixSwipeDirection {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}

// MARK: - Gesture Callbacks

public typealias TapCallback = (CGPoint, Int) -> Void
public typealias LongPressCallback = (CGPoint, ZylixGestureState) -> Void
public typealias PanCallback = (CGPoint, CGPoint, CGPoint, ZylixGestureState) -> Void // location, translation, velocity, state
public typealias SwipeCallback = (CGPoint, ZylixSwipeDirection) -> Void
public typealias PinchCallback = (CGPoint, CGFloat, CGFloat, ZylixGestureState) -> Void // center, scale, velocity, state
public typealias RotationCallback = (CGPoint, CGFloat, CGFloat, ZylixGestureState) -> Void // center, rotation, velocity, state

// MARK: - Tap Recognizer

public class ZylixTapRecognizer {
    public var numberOfTapsRequired: Int = 1
    public var numberOfTouchesRequired: Int = 1
    public var callback: TapCallback?

    private var gestureRecognizer: UITapGestureRecognizer?
    private weak var view: UIView?

    public init(numberOfTaps: Int = 1, numberOfTouches: Int = 1) {
        self.numberOfTapsRequired = numberOfTaps
        self.numberOfTouchesRequired = numberOfTouches
    }

    public func attach(to view: UIView) {
        self.view = view
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        recognizer.numberOfTapsRequired = numberOfTapsRequired
        recognizer.numberOfTouchesRequired = numberOfTouchesRequired
        view.addGestureRecognizer(recognizer)
        self.gestureRecognizer = recognizer
    }

    public func detach() {
        if let recognizer = gestureRecognizer, let view = view {
            view.removeGestureRecognizer(recognizer)
        }
        gestureRecognizer = nil
        view = nil
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let view = view else { return }
        let location = recognizer.location(in: view)
        callback?(location, numberOfTapsRequired)
    }
}

// MARK: - Long Press Recognizer

public class ZylixLongPressRecognizer {
    public var minimumPressDuration: TimeInterval = 0.5
    public var numberOfTouchesRequired: Int = 1
    public var allowableMovement: CGFloat = 10
    public var callback: LongPressCallback?

    private var gestureRecognizer: UILongPressGestureRecognizer?
    private weak var view: UIView?

    public init(minimumDuration: TimeInterval = 0.5) {
        self.minimumPressDuration = minimumDuration
    }

    public func attach(to view: UIView) {
        self.view = view
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.minimumPressDuration = minimumPressDuration
        recognizer.numberOfTouchesRequired = numberOfTouchesRequired
        recognizer.allowableMovement = allowableMovement
        view.addGestureRecognizer(recognizer)
        self.gestureRecognizer = recognizer
    }

    public func detach() {
        if let recognizer = gestureRecognizer, let view = view {
            view.removeGestureRecognizer(recognizer)
        }
        gestureRecognizer = nil
        view = nil
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard let view = view else { return }
        let location = recognizer.location(in: view)
        let state = ZylixGestureState(from: recognizer.state)
        callback?(location, state)
    }
}

// MARK: - Pan Recognizer

public class ZylixPanRecognizer {
    public var minimumNumberOfTouches: Int = 1
    public var maximumNumberOfTouches: Int = .max
    public var callback: PanCallback?

    private var gestureRecognizer: UIPanGestureRecognizer?
    private weak var view: UIView?

    public init(minTouches: Int = 1, maxTouches: Int = .max) {
        self.minimumNumberOfTouches = minTouches
        self.maximumNumberOfTouches = maxTouches
    }

    public func attach(to view: UIView) {
        self.view = view
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        recognizer.minimumNumberOfTouches = minimumNumberOfTouches
        recognizer.maximumNumberOfTouches = maximumNumberOfTouches
        view.addGestureRecognizer(recognizer)
        self.gestureRecognizer = recognizer
    }

    public func detach() {
        if let recognizer = gestureRecognizer, let view = view {
            view.removeGestureRecognizer(recognizer)
        }
        gestureRecognizer = nil
        view = nil
    }

    public func setTranslation(_ translation: CGPoint) {
        gestureRecognizer?.setTranslation(translation, in: view)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = view else { return }
        let location = recognizer.location(in: view)
        let translation = recognizer.translation(in: view)
        let velocity = recognizer.velocity(in: view)
        let state = ZylixGestureState(from: recognizer.state)
        callback?(location, translation, velocity, state)
    }
}

// MARK: - Swipe Recognizer

public class ZylixSwipeRecognizer {
    public var direction: ZylixSwipeDirection = .right
    public var numberOfTouchesRequired: Int = 1
    public var callback: SwipeCallback?

    private var gestureRecognizer: UISwipeGestureRecognizer?
    private weak var view: UIView?

    public init(direction: ZylixSwipeDirection = .right) {
        self.direction = direction
    }

    public func attach(to view: UIView) {
        self.view = view
        let recognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        recognizer.direction = direction.uiDirection
        recognizer.numberOfTouchesRequired = numberOfTouchesRequired
        view.addGestureRecognizer(recognizer)
        self.gestureRecognizer = recognizer
    }

    public func detach() {
        if let recognizer = gestureRecognizer, let view = view {
            view.removeGestureRecognizer(recognizer)
        }
        gestureRecognizer = nil
        view = nil
    }

    @objc private func handleSwipe(_ recognizer: UISwipeGestureRecognizer) {
        guard let view = view else { return }
        let location = recognizer.location(in: view)
        callback?(location, direction)
    }
}

// MARK: - Pinch Recognizer

public class ZylixPinchRecognizer {
    public var callback: PinchCallback?

    private var gestureRecognizer: UIPinchGestureRecognizer?
    private weak var view: UIView?

    public init() {}

    public func attach(to view: UIView) {
        self.view = view
        let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(recognizer)
        self.gestureRecognizer = recognizer
    }

    public func detach() {
        if let recognizer = gestureRecognizer, let view = view {
            view.removeGestureRecognizer(recognizer)
        }
        gestureRecognizer = nil
        view = nil
    }

    public func setScale(_ scale: CGFloat) {
        gestureRecognizer?.scale = scale
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let view = view else { return }
        let center = recognizer.location(in: view)
        let scale = recognizer.scale
        let velocity = recognizer.velocity
        let state = ZylixGestureState(from: recognizer.state)
        callback?(center, scale, velocity, state)
    }
}

// MARK: - Rotation Recognizer

public class ZylixRotationRecognizer {
    public var callback: RotationCallback?

    private var gestureRecognizer: UIRotationGestureRecognizer?
    private weak var view: UIView?

    public init() {}

    public func attach(to view: UIView) {
        self.view = view
        let recognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        view.addGestureRecognizer(recognizer)
        self.gestureRecognizer = recognizer
    }

    public func detach() {
        if let recognizer = gestureRecognizer, let view = view {
            view.removeGestureRecognizer(recognizer)
        }
        gestureRecognizer = nil
        view = nil
    }

    public func setRotation(_ rotation: CGFloat) {
        gestureRecognizer?.rotation = rotation
    }

    @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        guard let view = view else { return }
        let center = recognizer.location(in: view)
        let rotation = recognizer.rotation
        let velocity = recognizer.velocity
        let state = ZylixGestureState(from: recognizer.state)
        callback?(center, rotation, velocity, state)
    }
}

// MARK: - Edge Pan Recognizer

public class ZylixEdgePanRecognizer {
    public var edges: UIRectEdge = .left
    public var callback: PanCallback?

    private var gestureRecognizer: UIScreenEdgePanGestureRecognizer?
    private weak var view: UIView?

    public init(edges: UIRectEdge = .left) {
        self.edges = edges
    }

    public func attach(to view: UIView) {
        self.view = view
        let recognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        recognizer.edges = edges
        view.addGestureRecognizer(recognizer)
        self.gestureRecognizer = recognizer
    }

    public func detach() {
        if let recognizer = gestureRecognizer, let view = view {
            view.removeGestureRecognizer(recognizer)
        }
        gestureRecognizer = nil
        view = nil
    }

    @objc private func handleEdgePan(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        guard let view = view else { return }
        let location = recognizer.location(in: view)
        let translation = recognizer.translation(in: view)
        let velocity = recognizer.velocity(in: view)
        let state = ZylixGestureState(from: recognizer.state)
        callback?(location, translation, velocity, state)
    }
}

// MARK: - Gesture Manager

public class ZylixGestureManager {
    public static let shared = ZylixGestureManager()

    private var tapRecognizers: [Int: ZylixTapRecognizer] = [:]
    private var longPressRecognizers: [Int: ZylixLongPressRecognizer] = [:]
    private var panRecognizers: [Int: ZylixPanRecognizer] = [:]
    private var swipeRecognizers: [Int: ZylixSwipeRecognizer] = [:]
    private var pinchRecognizers: [Int: ZylixPinchRecognizer] = [:]
    private var rotationRecognizers: [Int: ZylixRotationRecognizer] = [:]
    private var edgePanRecognizers: [Int: ZylixEdgePanRecognizer] = [:]

    private var nextId: Int = 1

    private init() {}

    // MARK: - Tap

    @discardableResult
    public func addTapRecognizer(
        to view: UIView,
        numberOfTaps: Int = 1,
        numberOfTouches: Int = 1,
        callback: @escaping TapCallback
    ) -> Int {
        let id = nextId
        nextId += 1

        let recognizer = ZylixTapRecognizer(numberOfTaps: numberOfTaps, numberOfTouches: numberOfTouches)
        recognizer.callback = callback
        recognizer.attach(to: view)
        tapRecognizers[id] = recognizer

        return id
    }

    // MARK: - Long Press

    @discardableResult
    public func addLongPressRecognizer(
        to view: UIView,
        minimumDuration: TimeInterval = 0.5,
        callback: @escaping LongPressCallback
    ) -> Int {
        let id = nextId
        nextId += 1

        let recognizer = ZylixLongPressRecognizer(minimumDuration: minimumDuration)
        recognizer.callback = callback
        recognizer.attach(to: view)
        longPressRecognizers[id] = recognizer

        return id
    }

    // MARK: - Pan

    @discardableResult
    public func addPanRecognizer(
        to view: UIView,
        minTouches: Int = 1,
        maxTouches: Int = .max,
        callback: @escaping PanCallback
    ) -> Int {
        let id = nextId
        nextId += 1

        let recognizer = ZylixPanRecognizer(minTouches: minTouches, maxTouches: maxTouches)
        recognizer.callback = callback
        recognizer.attach(to: view)
        panRecognizers[id] = recognizer

        return id
    }

    // MARK: - Swipe

    @discardableResult
    public func addSwipeRecognizer(
        to view: UIView,
        direction: ZylixSwipeDirection,
        callback: @escaping SwipeCallback
    ) -> Int {
        let id = nextId
        nextId += 1

        let recognizer = ZylixSwipeRecognizer(direction: direction)
        recognizer.callback = callback
        recognizer.attach(to: view)
        swipeRecognizers[id] = recognizer

        return id
    }

    // MARK: - Pinch

    @discardableResult
    public func addPinchRecognizer(
        to view: UIView,
        callback: @escaping PinchCallback
    ) -> Int {
        let id = nextId
        nextId += 1

        let recognizer = ZylixPinchRecognizer()
        recognizer.callback = callback
        recognizer.attach(to: view)
        pinchRecognizers[id] = recognizer

        return id
    }

    // MARK: - Rotation

    @discardableResult
    public func addRotationRecognizer(
        to view: UIView,
        callback: @escaping RotationCallback
    ) -> Int {
        let id = nextId
        nextId += 1

        let recognizer = ZylixRotationRecognizer()
        recognizer.callback = callback
        recognizer.attach(to: view)
        rotationRecognizers[id] = recognizer

        return id
    }

    // MARK: - Edge Pan

    @discardableResult
    public func addEdgePanRecognizer(
        to view: UIView,
        edges: UIRectEdge,
        callback: @escaping PanCallback
    ) -> Int {
        let id = nextId
        nextId += 1

        let recognizer = ZylixEdgePanRecognizer(edges: edges)
        recognizer.callback = callback
        recognizer.attach(to: view)
        edgePanRecognizers[id] = recognizer

        return id
    }

    // MARK: - Remove

    public func removeRecognizer(id: Int) {
        if let recognizer = tapRecognizers.removeValue(forKey: id) {
            recognizer.detach()
        } else if let recognizer = longPressRecognizers.removeValue(forKey: id) {
            recognizer.detach()
        } else if let recognizer = panRecognizers.removeValue(forKey: id) {
            recognizer.detach()
        } else if let recognizer = swipeRecognizers.removeValue(forKey: id) {
            recognizer.detach()
        } else if let recognizer = pinchRecognizers.removeValue(forKey: id) {
            recognizer.detach()
        } else if let recognizer = rotationRecognizers.removeValue(forKey: id) {
            recognizer.detach()
        } else if let recognizer = edgePanRecognizers.removeValue(forKey: id) {
            recognizer.detach()
        }
    }

    public func removeAllRecognizers() {
        tapRecognizers.values.forEach { $0.detach() }
        tapRecognizers.removeAll()

        longPressRecognizers.values.forEach { $0.detach() }
        longPressRecognizers.removeAll()

        panRecognizers.values.forEach { $0.detach() }
        panRecognizers.removeAll()

        swipeRecognizers.values.forEach { $0.detach() }
        swipeRecognizers.removeAll()

        pinchRecognizers.values.forEach { $0.detach() }
        pinchRecognizers.removeAll()

        rotationRecognizers.values.forEach { $0.detach() }
        rotationRecognizers.removeAll()

        edgePanRecognizers.values.forEach { $0.detach() }
        edgePanRecognizers.removeAll()
    }
}

// MARK: - SwiftUI Gesture Modifiers

import SwiftUI

public struct ZylixTapGesture: ViewModifier {
    let numberOfTaps: Int
    let action: (CGPoint) -> Void

    public func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture(count: numberOfTaps)
                    .onEnded { _ in
                        // SwiftUI doesn't give location, use center
                        action(.zero)
                    }
            )
    }
}

public struct ZylixLongPressGesture: ViewModifier {
    let minimumDuration: Double
    let onChanged: (Bool) -> Void
    let onEnded: () -> Void

    public func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                LongPressGesture(minimumDuration: minimumDuration)
                    .onChanged { pressing in
                        onChanged(pressing)
                    }
                    .onEnded { _ in
                        onEnded()
                    }
            )
    }
}

public struct ZylixDragGesture: ViewModifier {
    let onChanged: (CGSize, CGPoint) -> Void
    let onEnded: (CGSize, CGPoint) -> Void

    public func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        onChanged(value.translation, value.location)
                    }
                    .onEnded { value in
                        onEnded(value.translation, value.location)
                    }
            )
    }
}

public struct ZylixMagnificationGesture: ViewModifier {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    public func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in
                        onChanged(scale)
                    }
                    .onEnded { scale in
                        onEnded(scale)
                    }
            )
    }
}

public struct ZylixRotationGestureModifier: ViewModifier {
    let onChanged: (Angle) -> Void
    let onEnded: (Angle) -> Void

    public func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                RotationGesture()
                    .onChanged { angle in
                        onChanged(angle)
                    }
                    .onEnded { angle in
                        onEnded(angle)
                    }
            )
    }
}

// MARK: - View Extensions

public extension View {
    func zylixOnTap(count: Int = 1, perform action: @escaping (CGPoint) -> Void) -> some View {
        modifier(ZylixTapGesture(numberOfTaps: count, action: action))
    }

    func zylixOnLongPress(
        minimumDuration: Double = 0.5,
        onChanged: @escaping (Bool) -> Void = { _ in },
        onEnded: @escaping () -> Void
    ) -> some View {
        modifier(ZylixLongPressGesture(
            minimumDuration: minimumDuration,
            onChanged: onChanged,
            onEnded: onEnded
        ))
    }

    func zylixOnDrag(
        onChanged: @escaping (CGSize, CGPoint) -> Void,
        onEnded: @escaping (CGSize, CGPoint) -> Void
    ) -> some View {
        modifier(ZylixDragGesture(onChanged: onChanged, onEnded: onEnded))
    }

    func zylixOnPinch(
        onChanged: @escaping (CGFloat) -> Void,
        onEnded: @escaping (CGFloat) -> Void
    ) -> some View {
        modifier(ZylixMagnificationGesture(onChanged: onChanged, onEnded: onEnded))
    }

    func zylixOnRotation(
        onChanged: @escaping (Angle) -> Void,
        onEnded: @escaping (Angle) -> Void
    ) -> some View {
        modifier(ZylixRotationGestureModifier(onChanged: onChanged, onEnded: onEnded))
    }
}

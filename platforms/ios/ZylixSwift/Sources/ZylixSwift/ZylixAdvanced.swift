// ZylixAdvanced.swift - iOS Advanced Features for Zylix
//
// Provides advanced React-like patterns for SwiftUI:
// - Error Boundaries
// - Context API
// - Suspense with async data loading
// - Portal/Modal system

import SwiftUI
import Combine

// MARK: - Error Boundary

/// Error boundary state
public enum ErrorBoundaryState {
    case normal
    case error(Error)
}

/// Error boundary wrapper for catching and handling errors in SwiftUI views
public struct ErrorBoundary<Content: View, Fallback: View>: View {
    let content: () -> Content
    let fallback: (Error, @escaping () -> Void) -> Fallback
    let onError: ((Error) -> Void)?

    @State private var state: ErrorBoundaryState = .normal

    public init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder fallback: @escaping (Error, @escaping () -> Void) -> Fallback,
        onError: ((Error) -> Void)? = nil
    ) {
        self.content = content
        self.fallback = fallback
        self.onError = onError
    }

    public var body: some View {
        switch state {
        case .normal:
            content()
                .environment(\.errorHandler, ErrorHandler { error in
                    self.state = .error(error)
                    self.onError?(error)
                })
        case .error(let error):
            fallback(error) {
                self.state = .normal
            }
        }
    }
}

/// Error handler for propagating errors to error boundaries
public struct ErrorHandler {
    let handle: (Error) -> Void

    public init(handle: @escaping (Error) -> Void) {
        self.handle = handle
    }

    public func callAsFunction(_ error: Error) {
        handle(error)
    }
}

/// Environment key for error handler
private struct ErrorHandlerKey: EnvironmentKey {
    static let defaultValue = ErrorHandler { _ in }
}

extension EnvironmentValues {
    public var errorHandler: ErrorHandler {
        get { self[ErrorHandlerKey.self] }
        set { self[ErrorHandlerKey.self] = newValue }
    }
}

/// Hook to access error handler in views
public func useErrorHandler() -> ErrorHandler {
    @Environment(\.errorHandler) var handler
    return handler
}

// MARK: - Context API

/// Protocol for context values
public protocol ContextValue: ObservableObject {}

/// Context provider for sharing state across views
public struct ContextProvider<T: ContextValue, Content: View>: View {
    @StateObject var value: T
    let content: () -> Content

    public init(_ value: @autoclosure @escaping () -> T, @ViewBuilder content: @escaping () -> Content) {
        self._value = StateObject(wrappedValue: value())
        self.content = content
    }

    public var body: some View {
        content()
            .environmentObject(value)
    }
}

/// Property wrapper for consuming context values
@propertyWrapper
public struct UseContext<T: ContextValue>: DynamicProperty {
    @EnvironmentObject private var context: T

    public init() {}

    public var wrappedValue: T {
        context
    }
}

// MARK: - Suspense

/// Loading state for async operations
public enum SuspenseState<T> {
    case loading
    case success(T)
    case failure(Error)
}

/// Resource wrapper for async data loading
@MainActor
public class Resource<T>: ObservableObject {
    @Published public private(set) var state: SuspenseState<T> = .loading

    private let fetcher: () async throws -> T
    private var task: Task<Void, Never>?

    public init(fetcher: @escaping () async throws -> T) {
        self.fetcher = fetcher
    }

    public func load() {
        task?.cancel()
        state = .loading

        task = Task {
            do {
                let result = try await fetcher()
                if !Task.isCancelled {
                    self.state = .success(result)
                }
            } catch {
                if !Task.isCancelled {
                    self.state = .failure(error)
                }
            }
        }
    }

    public func reload() {
        load()
    }

    public var data: T? {
        if case .success(let value) = state {
            return value
        }
        return nil
    }

    public var error: Error? {
        if case .failure(let error) = state {
            return error
        }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = state {
            return true
        }
        return false
    }
}

/// Create a resource for async data loading
public func createResource<T>(fetcher: @escaping () async throws -> T) -> Resource<T> {
    let resource = Resource(fetcher: fetcher)
    resource.load()
    return resource
}

/// Suspense wrapper that shows loading state while content is loading
public struct Suspense<Content: View, Fallback: View>: View {
    let isLoading: Bool
    let content: () -> Content
    let fallback: () -> Fallback

    public init(
        isLoading: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder fallback: @escaping () -> Fallback
    ) {
        self.isLoading = isLoading
        self.content = content
        self.fallback = fallback
    }

    public var body: some View {
        if isLoading {
            fallback()
        } else {
            content()
        }
    }
}

/// Default loading view
public struct DefaultLoadingView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Portal / Modal System

/// Portal manager for rendering views outside their parent hierarchy
@MainActor
public class PortalManager: ObservableObject {
    public static let shared = PortalManager()

    @Published public var portals: [String: AnyView] = [:]

    private init() {}

    public func mount(id: String, content: some View) {
        portals[id] = AnyView(content)
    }

    public func unmount(id: String) {
        portals.removeValue(forKey: id)
    }
}

/// Portal host that renders portal content
public struct PortalHost: View {
    @ObservedObject private var manager = PortalManager.shared

    public init() {}

    public var body: some View {
        ZStack {
            ForEach(Array(manager.portals.keys), id: \.self) { key in
                manager.portals[key]
            }
        }
    }
}

/// Portal that renders content outside its parent view hierarchy
public struct Portal<Content: View>: View {
    let id: String
    let content: () -> Content

    @State private var isMounted = false

    public init(id: String = UUID().uuidString, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.content = content
    }

    public var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                PortalManager.shared.mount(id: id, content: content())
                isMounted = true
            }
            .onDisappear {
                PortalManager.shared.unmount(id: id)
                isMounted = false
            }
            .onChange(of: isMounted) { _ in }
    }
}

/// Modal configuration
public struct ModalConfig {
    public var backgroundColor: Color
    public var cornerRadius: CGFloat
    public var shadowRadius: CGFloat
    public var overlayColor: Color
    public var animationDuration: Double

    public init(
        backgroundColor: Color = .white,
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 10,
        overlayColor: Color = Color.black.opacity(0.4),
        animationDuration: Double = 0.3
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.overlayColor = overlayColor
        self.animationDuration = animationDuration
    }

    public static let `default` = ModalConfig()
}

/// Modal view with overlay and dismiss handling
public struct Modal<Content: View>: View {
    @Binding var isPresented: Bool
    let config: ModalConfig
    let content: () -> Content
    let onDismiss: (() -> Void)?

    public init(
        isPresented: Binding<Bool>,
        config: ModalConfig = .default,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.config = config
        self.onDismiss = onDismiss
        self.content = content
    }

    public var body: some View {
        ZStack {
            if isPresented {
                config.overlayColor
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }
                    .transition(.opacity)

                content()
                    .background(config.backgroundColor)
                    .cornerRadius(config.cornerRadius)
                    .shadow(radius: config.shadowRadius)
                    .padding()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: config.animationDuration), value: isPresented)
    }

    private func dismiss() {
        isPresented = false
        onDismiss?()
    }
}

/// View modifier for presenting modals
public struct ModalModifier<ModalContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let config: ModalConfig
    let modalContent: () -> ModalContent

    public func body(content: Content) -> some View {
        ZStack {
            content
            Modal(isPresented: $isPresented, config: config) {
                modalContent()
            }
        }
    }
}

extension View {
    public func modal<Content: View>(
        isPresented: Binding<Bool>,
        config: ModalConfig = .default,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(ModalModifier(isPresented: isPresented, config: config, modalContent: content))
    }
}

/// Tooltip view
public struct Tooltip<Content: View, TooltipContent: View>: View {
    let content: () -> Content
    let tooltip: () -> TooltipContent

    @State private var isShowing = false

    public init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder tooltip: @escaping () -> TooltipContent
    ) {
        self.content = content
        self.tooltip = tooltip
    }

    public var body: some View {
        content()
            .overlay(alignment: .top) {
                if isShowing {
                    tooltip()
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .offset(y: -40)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowing = hovering
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                withAnimation {
                    isShowing.toggle()
                }
            }
    }
}

// MARK: - Virtual List (Lazy Loading)

/// Virtual list configuration
public struct VirtualListConfig {
    public var itemHeight: CGFloat
    public var overscan: Int
    public var loadMoreThreshold: Int

    public init(
        itemHeight: CGFloat = 44,
        overscan: Int = 5,
        loadMoreThreshold: Int = 10
    ) {
        self.itemHeight = itemHeight
        self.overscan = overscan
        self.loadMoreThreshold = loadMoreThreshold
    }
}

/// Virtual list for efficient rendering of large lists
public struct VirtualList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let config: VirtualListConfig
    let content: (Data.Element) -> Content
    let onLoadMore: (() -> Void)?

    public init(
        _ data: Data,
        config: VirtualListConfig = VirtualListConfig(),
        onLoadMore: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.config = config
        self.onLoadMore = onLoadMore
        self.content = content
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    content(item)
                        .frame(height: config.itemHeight)
                        .onAppear {
                            checkLoadMore(index: index)
                        }
                }
            }
        }
    }

    private func checkLoadMore(index: Int) {
        let dataCount = data.count
        if index >= dataCount - config.loadMoreThreshold {
            onLoadMore?()
        }
    }
}

/// Infinite scroll wrapper
public struct InfiniteScroll<Content: View>: View {
    let hasMore: Bool
    let isLoading: Bool
    let content: () -> Content
    let onLoadMore: () -> Void

    public init(
        hasMore: Bool,
        isLoading: Bool,
        onLoadMore: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.hasMore = hasMore
        self.isLoading = isLoading
        self.onLoadMore = onLoadMore
        self.content = content
    }

    public var body: some View {
        ScrollView {
            content()

            if hasMore {
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            onLoadMore()
                        }
                }
            }
        }
    }
}

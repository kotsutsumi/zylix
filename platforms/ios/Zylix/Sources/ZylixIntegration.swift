//
//  ZylixIntegration.swift
//  Zylix
//
//  Cross-platform integration APIs for iOS.
//  Provides unified APIs for Motion, Audio, IAP, Ads, KeyValue, and Lifecycle.
//

import Foundation
import AVFoundation
import StoreKit
import Combine
import UIKit

// MARK: - Motion Frame Provider (#39)

/// Resolution presets for motion capture
public enum MotionResolution: UInt8 {
    case veryLow = 0   // 80x60
    case low = 1       // 160x120
    case medium = 2    // 320x240
    case high = 3      // 640x480

    public var size: CGSize {
        switch self {
        case .veryLow: return CGSize(width: 80, height: 60)
        case .low: return CGSize(width: 160, height: 120)
        case .medium: return CGSize(width: 320, height: 240)
        case .high: return CGSize(width: 640, height: 480)
        }
    }
}

/// Motion frame data
public struct MotionFrame {
    public let width: Int
    public let height: Int
    public let data: Data
    public let timestamp: Int64
    public let sequence: UInt64
    public var motionDetected: Bool = false
    public var motionX: Float = 0.5
    public var motionY: Float = 0.5
    public var motionIntensity: Float = 0.0
}

/// Motion frame configuration
public struct MotionFrameConfig {
    public var targetFPS: Int = 15
    public var resolution: MotionResolution = .low
    public var cameraPosition: AVCaptureDevice.Position = .front
    public var detectMotion: Bool = false
    public var motionSensitivity: Float = 0.5

    public init() {}
}

/// Motion Frame Provider for camera-based motion tracking
@MainActor
public final class ZylixMotionFrameProvider: NSObject, ObservableObject {

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isAuthorized: Bool = false
    @Published public private(set) var frameCount: UInt64 = 0
    @Published public private(set) var lastFrame: MotionFrame?

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var config: MotionFrameConfig
    private var previousFrameData: Data?
    private let processingQueue = DispatchQueue(label: "com.zylix.motion", qos: .userInteractive)

    public var onFrame: ((MotionFrame) -> Void)?

    public static let shared = ZylixMotionFrameProvider()

    private override init() {
        self.config = MotionFrameConfig()
        super.init()
        checkAuthorization()
    }

    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    public func requestPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run { self.isAuthorized = granted }
        return granted
    }

    public func configure(_ config: MotionFrameConfig) {
        self.config = config
    }

    public func start() throws {
        guard isAuthorized else {
            throw ZylixIntegrationError.permissionDenied
        }
        guard !isRunning else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .low

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: config.cameraPosition) else {
            throw ZylixIntegrationError.deviceNotAvailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: processingQueue)
        output.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        self.captureSession = session
        self.videoOutput = output
        self.frameCount = 0
        self.previousFrameData = nil

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            Task { @MainActor in
                self.isRunning = true
            }
        }
    }

    public func stop() {
        guard isRunning else { return }

        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        isRunning = false
    }

    public static func isAvailable() -> Bool {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }
}

extension ZylixMotionFrameProvider: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let data = Data(bytes: baseAddress, count: bytesPerRow * height)
        let timestamp = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000)

        Task { @MainActor in
            self.frameCount += 1

            var frame = MotionFrame(
                width: width,
                height: height,
                data: data,
                timestamp: timestamp,
                sequence: self.frameCount
            )

            // Simple motion detection
            if self.config.detectMotion, let prevData = self.previousFrameData, prevData.count == data.count {
                var diffSum: UInt64 = 0
                var motionPixels: Int = 0

                data.withUnsafeBytes { currentBytes in
                    prevData.withUnsafeBytes { prevBytes in
                        for i in stride(from: 0, to: min(data.count, prevData.count), by: 4) {
                            let diff = abs(Int(currentBytes[i]) - Int(prevBytes[i]))
                            if diff > Int((1.0 - self.config.motionSensitivity) * 255) {
                                motionPixels += 1
                            }
                            diffSum += UInt64(diff)
                        }
                    }
                }

                let pixelCount = data.count / 4
                frame.motionIntensity = Float(diffSum) / Float(pixelCount * 255)
                frame.motionDetected = motionPixels > pixelCount / 100
            }

            self.previousFrameData = data
            self.lastFrame = frame
            self.onFrame?(frame)
        }
    }
}

// MARK: - Audio Clip Player (#40)

/// Audio clip for low-latency playback
public struct AudioClip: Identifiable {
    public let id: String
    public let url: URL
    public var volume: Float = 1.0
    public var loop: Bool = false

    public init(id: String, url: URL) {
        self.id = id
        self.url = url
    }
}

/// Audio Clip Player for low-latency audio playback
@MainActor
public final class ZylixAudioClipPlayer: ObservableObject {

    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var loadedClips: [String: AudioClip] = [:]

    private var players: [String: AVAudioPlayer] = [:]
    private let audioSession = AVAudioSession.sharedInstance()

    public static let shared = ZylixAudioClipPlayer()

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("[ZylixAudioClip] Failed to configure audio session: \(error)")
        }
    }

    /// Load an audio clip for playback
    public func load(_ clip: AudioClip) throws {
        let player = try AVAudioPlayer(contentsOf: clip.url)
        player.prepareToPlay()
        player.volume = clip.volume
        player.numberOfLoops = clip.loop ? -1 : 0
        players[clip.id] = player
        loadedClips[clip.id] = clip
    }

    /// Load from bundled resource
    public func loadFromBundle(id: String, name: String, extension ext: String) throws {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw ZylixIntegrationError.resourceNotFound
        }
        try load(AudioClip(id: id, url: url))
    }

    /// Play a loaded clip
    public func play(_ clipId: String) {
        guard let player = players[clipId] else { return }
        player.currentTime = 0
        player.play()
        isPlaying = true
    }

    /// Stop a playing clip
    public func stop(_ clipId: String) {
        players[clipId]?.stop()
        updatePlayingState()
    }

    /// Pause a playing clip
    public func pause(_ clipId: String) {
        players[clipId]?.pause()
        updatePlayingState()
    }

    /// Set volume for a clip
    public func setVolume(_ clipId: String, volume: Float) {
        players[clipId]?.volume = volume.clamped(to: 0...1)
    }

    /// Unload a clip
    public func unload(_ clipId: String) {
        players[clipId]?.stop()
        players.removeValue(forKey: clipId)
        loadedClips.removeValue(forKey: clipId)
        updatePlayingState()
    }

    /// Unload all clips
    public func unloadAll() {
        players.values.forEach { $0.stop() }
        players.removeAll()
        loadedClips.removeAll()
        isPlaying = false
    }

    private func updatePlayingState() {
        isPlaying = players.values.contains { $0.isPlaying }
    }

    public static func isAvailable() -> Bool {
        return true
    }
}

// MARK: - In-App Purchase Store (#41)

/// Product type
public enum IAPProductType {
    case consumable
    case nonConsumable
    case autoRenewableSubscription
    case nonRenewingSubscription
}

/// IAP Product
public struct IAPProduct: Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    public let price: Decimal
    public let priceFormatted: String
    public let type: IAPProductType

    init(from product: Product) {
        self.id = product.id
        self.displayName = product.displayName
        self.description = product.description
        self.price = product.price
        self.priceFormatted = product.displayPrice

        switch product.type {
        case .consumable:
            self.type = .consumable
        case .nonConsumable:
            self.type = .nonConsumable
        case .autoRenewable:
            self.type = .autoRenewableSubscription
        case .nonRenewable:
            self.type = .nonRenewingSubscription
        @unknown default:
            self.type = .nonConsumable
        }
    }
}

/// Purchase result
public enum IAPPurchaseResult {
    case success(transactionId: String)
    case pending
    case cancelled
    case failed(Error)
}

/// In-App Purchase Store
@MainActor
public final class ZylixIAPStore: ObservableObject {

    @Published public private(set) var products: [IAPProduct] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var isLoading: Bool = false

    private var updateListenerTask: Task<Void, Error>?
    private var productIDs: Set<String> = []

    public static let shared = ZylixIAPStore()

    private init() {
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    /// Configure with product IDs
    public func configure(productIDs: Set<String>) {
        self.productIDs = productIDs
    }

    /// Load products from App Store
    public func loadProducts() async throws {
        isLoading = true
        defer { isLoading = false }

        let storeProducts = try await Product.products(for: productIDs)
        products = storeProducts.map { IAPProduct(from: $0) }

        await updatePurchasedProducts()
    }

    /// Purchase a product
    public func purchase(_ productId: String) async -> IAPPurchaseResult {
        guard let product = try? await Product.products(for: [productId]).first else {
            return .failed(ZylixIntegrationError.productNotFound)
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchasedProducts()
                return .success(transactionId: String(transaction.id))

            case .userCancelled:
                return .cancelled

            case .pending:
                return .pending

            @unknown default:
                return .failed(ZylixIntegrationError.unknown)
            }
        } catch {
            return .failed(error)
        }
    }

    /// Restore purchases
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }

    /// Check if product is purchased
    public func isPurchased(_ productId: String) -> Bool {
        return purchasedProductIDs.contains(productId)
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)
            }
        }

        purchasedProductIDs = purchased
    }

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw ZylixIntegrationError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    public static func isAvailable() -> Bool {
        return true
    }
}

// MARK: - Ads Manager (#42)

/// Ad type
public enum ZylixAdType {
    case banner
    case interstitial
    case rewarded
}

/// Reward from rewarded ad
public struct ZylixAdReward {
    public let type: String
    public let amount: Int
}

/// Ads Manager (AdMob integration placeholder)
/// Note: Actual AdMob integration requires GoogleMobileAds SDK
@MainActor
public final class ZylixAdsManager: ObservableObject {

    @Published public private(set) var isBannerVisible: Bool = false
    @Published public private(set) var isInterstitialReady: Bool = false
    @Published public private(set) var isRewardedReady: Bool = false
    @Published public private(set) var consentStatus: ConsentStatus = .unknown

    public enum ConsentStatus {
        case unknown
        case required
        case notRequired
        case obtained
    }

    private var appId: String?
    private var bannerAdUnitId: String?
    private var interstitialAdUnitId: String?
    private var rewardedAdUnitId: String?

    public var onRewardEarned: ((ZylixAdReward) -> Void)?

    public static let shared = ZylixAdsManager()

    private init() {}

    /// Initialize with AdMob App ID
    public func initialize(appId: String) {
        self.appId = appId
        // GADMobileAds.sharedInstance().start(completionHandler: nil)
        print("[ZylixAds] Initialized with appId: \(appId)")
    }

    /// Configure ad unit IDs
    public func configure(
        bannerAdUnitId: String? = nil,
        interstitialAdUnitId: String? = nil,
        rewardedAdUnitId: String? = nil
    ) {
        self.bannerAdUnitId = bannerAdUnitId
        self.interstitialAdUnitId = interstitialAdUnitId
        self.rewardedAdUnitId = rewardedAdUnitId
    }

    /// Load banner ad
    public func loadBanner() {
        guard bannerAdUnitId != nil else { return }
        // Actual AdMob implementation would go here
        print("[ZylixAds] Loading banner ad")
    }

    /// Show banner ad
    public func showBanner() {
        isBannerVisible = true
    }

    /// Hide banner ad
    public func hideBanner() {
        isBannerVisible = false
    }

    /// Load interstitial ad
    public func loadInterstitial() async {
        guard interstitialAdUnitId != nil else { return }
        // Actual AdMob implementation would go here
        print("[ZylixAds] Loading interstitial ad")
        isInterstitialReady = true
    }

    /// Show interstitial ad
    public func showInterstitial() {
        guard isInterstitialReady else { return }
        // Actual AdMob implementation would go here
        print("[ZylixAds] Showing interstitial ad")
        isInterstitialReady = false
    }

    /// Load rewarded ad
    public func loadRewarded() async {
        guard rewardedAdUnitId != nil else { return }
        // Actual AdMob implementation would go here
        print("[ZylixAds] Loading rewarded ad")
        isRewardedReady = true
    }

    /// Show rewarded ad
    public func showRewarded() {
        guard isRewardedReady else { return }
        // Actual AdMob implementation would go here
        print("[ZylixAds] Showing rewarded ad")
        isRewardedReady = false

        // Simulate reward
        let reward = ZylixAdReward(type: "coins", amount: 100)
        onRewardEarned?(reward)
    }

    /// Request consent (GDPR)
    public func requestConsent() async {
        // UMP SDK implementation would go here
        consentStatus = .obtained
    }

    public static func isAvailable() -> Bool {
        return true
    }
}

// MARK: - Key-Value Store (#43)

/// Persistent Key-Value Store using UserDefaults
@MainActor
public final class ZylixKeyValueStore: ObservableObject {

    @Published public private(set) var count: Int = 0

    private let defaults: UserDefaults
    private let suiteName: String?

    public static let shared = ZylixKeyValueStore()

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
        if let suiteName = suiteName {
            self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            self.defaults = .standard
        }
        updateCount()
    }

    // MARK: - Getters

    public func getBool(_ key: String, default defaultValue: Bool = false) -> Bool {
        if defaults.object(forKey: key) == nil { return defaultValue }
        return defaults.bool(forKey: key)
    }

    public func getInt(_ key: String, default defaultValue: Int = 0) -> Int {
        if defaults.object(forKey: key) == nil { return defaultValue }
        return defaults.integer(forKey: key)
    }

    public func getFloat(_ key: String, default defaultValue: Float = 0.0) -> Float {
        if defaults.object(forKey: key) == nil { return defaultValue }
        return defaults.float(forKey: key)
    }

    public func getDouble(_ key: String, default defaultValue: Double = 0.0) -> Double {
        if defaults.object(forKey: key) == nil { return defaultValue }
        return defaults.double(forKey: key)
    }

    public func getString(_ key: String, default defaultValue: String = "") -> String {
        return defaults.string(forKey: key) ?? defaultValue
    }

    public func getData(_ key: String) -> Data? {
        return defaults.data(forKey: key)
    }

    public func getObject<T: Decodable>(_ key: String, type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - Setters

    public func putBool(_ key: String, value: Bool) {
        defaults.set(value, forKey: key)
        updateCount()
    }

    public func putInt(_ key: String, value: Int) {
        defaults.set(value, forKey: key)
        updateCount()
    }

    public func putFloat(_ key: String, value: Float) {
        defaults.set(value, forKey: key)
        updateCount()
    }

    public func putDouble(_ key: String, value: Double) {
        defaults.set(value, forKey: key)
        updateCount()
    }

    public func putString(_ key: String, value: String) {
        defaults.set(value, forKey: key)
        updateCount()
    }

    public func putData(_ key: String, value: Data) {
        defaults.set(value, forKey: key)
        updateCount()
    }

    public func putObject<T: Encodable>(_ key: String, value: T) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
            updateCount()
        }
    }

    // MARK: - Management

    public func contains(_ key: String) -> Bool {
        return defaults.object(forKey: key) != nil
    }

    public func remove(_ key: String) {
        defaults.removeObject(forKey: key)
        updateCount()
    }

    public func clear() {
        if let suiteName = suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        } else {
            let domain = Bundle.main.bundleIdentifier ?? ""
            defaults.removePersistentDomain(forName: domain)
        }
        updateCount()
    }

    private func updateCount() {
        count = defaults.dictionaryRepresentation().count
    }
}

// MARK: - App Lifecycle (#44)

/// App state
public enum ZylixAppState {
    case notRunning
    case launching
    case foreground
    case background
    case suspended
    case terminating
}

/// Memory pressure level
public enum ZylixMemoryPressure {
    case normal
    case warning
    case critical
}

/// App Lifecycle Manager
@MainActor
public final class ZylixAppLifecycle: ObservableObject {

    @Published public private(set) var state: ZylixAppState = .notRunning
    @Published public private(set) var launchURL: URL?

    private var observers: [NSObjectProtocol] = []

    public var onForeground: (() -> Void)?
    public var onBackground: (() -> Void)?
    public var onTerminate: (() -> Void)?
    public var onMemoryWarning: ((ZylixMemoryPressure) -> Void)?
    public var onOpenURL: ((URL) -> Void)?

    public static let shared = ZylixAppLifecycle()

    private init() {
        setupObservers()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func setupObservers() {
        let nc = NotificationCenter.default

        observers.append(nc.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.state = .foreground
                self?.onForeground?()
            }
        })

        observers.append(nc.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.state = .background
                self?.onBackground?()
            }
        })

        observers.append(nc.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.state = .terminating
                self?.onTerminate?()
            }
        })

        observers.append(nc.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onMemoryWarning?(.warning)
            }
        })
    }

    /// Handle URL open (call from SceneDelegate or AppDelegate)
    public func handleOpenURL(_ url: URL) {
        launchURL = url
        onOpenURL?(url)
    }

    /// Check if app is in foreground
    public var isInForeground: Bool {
        return state == .foreground
    }

    /// Check if app is in background
    public var isInBackground: Bool {
        return state == .background || state == .suspended
    }
}

// MARK: - Unified Integration Manager

/// Unified Integration Manager for all services
@MainActor
public final class ZylixIntegration: ObservableObject {

    public let motion = ZylixMotionFrameProvider.shared
    public let audioClip = ZylixAudioClipPlayer.shared
    public let store = ZylixIAPStore.shared
    public let ads = ZylixAdsManager.shared
    public let keyValue = ZylixKeyValueStore.shared
    public let lifecycle = ZylixAppLifecycle.shared

    public static let shared = ZylixIntegration()

    private init() {}
}

// MARK: - Errors

public enum ZylixIntegrationError: Error, LocalizedError {
    case permissionDenied
    case deviceNotAvailable
    case resourceNotFound
    case productNotFound
    case verificationFailed
    case unknown

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Permission denied"
        case .deviceNotAvailable: return "Device not available"
        case .resourceNotFound: return "Resource not found"
        case .productNotFound: return "Product not found"
        case .verificationFailed: return "Verification failed"
        case .unknown: return "Unknown error"
        }
    }
}

// MARK: - Extensions

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

//
//  ZylixDevice.swift
//  Zylix
//
//  Cross-platform device features for iOS.
//  Provides unified API for location, camera, sensors, haptics, notifications.
//

import Foundation
import CoreLocation
import AVFoundation
import CoreMotion
import UserNotifications
import UIKit
import Combine

// MARK: - Location Manager

@MainActor
public final class ZylixLocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentLocation: CLLocation?
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public private(set) var isUpdating: Bool = false
    @Published public private(set) var lastError: Error?

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    // MARK: - Singleton

    public static let shared = ZylixLocationManager()

    // MARK: - Initialization

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Permission

    public func requestPermission(always: Bool = false) {
        if always {
            locationManager.requestAlwaysAuthorization()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    public var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    // MARK: - Location Updates

    public func startUpdating(accuracy: CLLocationAccuracy = kCLLocationAccuracyBest) {
        locationManager.desiredAccuracy = accuracy
        locationManager.startUpdatingLocation()
        isUpdating = true
    }

    public func stopUpdating() {
        locationManager.stopUpdatingLocation()
        isUpdating = false
    }

    /// Get current location with async/await
    public func getCurrentLocation() async throws -> CLLocation {
        guard isAuthorized else {
            throw ZylixDeviceError.permissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            self.locationManager.requestLocation()
        }
    }

    // MARK: - Distance Calculation

    public func distance(from: CLLocation, to: CLLocation) -> CLLocationDistance {
        return from.distance(from: to)
    }
}

// MARK: - CLLocationManagerDelegate

extension ZylixLocationManager: CLLocationManagerDelegate {

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            self.currentLocation = location
            self.lastError = nil

            if let continuation = self.locationContinuation {
                self.locationContinuation = nil
                continuation.resume(returning: location)
            }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.lastError = error

            if let continuation = self.locationContinuation {
                self.locationContinuation = nil
                continuation.resume(throwing: error)
            }
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}

// MARK: - Haptics Manager

@MainActor
public final class ZylixHapticsManager: ObservableObject {

    // MARK: - Feedback Generators

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    // MARK: - Singleton

    public static let shared = ZylixHapticsManager()

    private init() {
        // Prepare all generators
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactSoft.prepare()
        impactRigid.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    // MARK: - Impact Feedback

    public enum ImpactStyle {
        case light, medium, heavy, soft, rigid
    }

    public func impact(_ style: ImpactStyle, intensity: CGFloat = 1.0) {
        switch style {
        case .light:
            impactLight.impactOccurred(intensity: intensity)
        case .medium:
            impactMedium.impactOccurred(intensity: intensity)
        case .heavy:
            impactHeavy.impactOccurred(intensity: intensity)
        case .soft:
            impactSoft.impactOccurred(intensity: intensity)
        case .rigid:
            impactRigid.impactOccurred(intensity: intensity)
        }
    }

    // MARK: - Notification Feedback

    public enum NotificationType {
        case success, warning, error
    }

    public func notification(_ type: NotificationType) {
        switch type {
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
    }

    // MARK: - Selection Feedback

    public func selection() {
        selectionGenerator.selectionChanged()
    }
}

// MARK: - Sensors Manager

@MainActor
public final class ZylixSensorsManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var accelerometerData: CMAccelerometerData?
    @Published public private(set) var gyroscopeData: CMGyroData?
    @Published public private(set) var magnetometerData: CMMagnetometerData?
    @Published public private(set) var deviceMotion: CMDeviceMotion?
    @Published public private(set) var isAccelerometerActive: Bool = false
    @Published public private(set) var isGyroscopeActive: Bool = false
    @Published public private(set) var isMagnetometerActive: Bool = false
    @Published public private(set) var isDeviceMotionActive: Bool = false

    // MARK: - Private Properties

    private let motionManager = CMMotionManager()
    private let updateInterval: TimeInterval = 0.1 // 10Hz default

    // MARK: - Singleton

    public static let shared = ZylixSensorsManager()

    private init() {}

    // MARK: - Availability

    public var isAccelerometerAvailable: Bool {
        motionManager.isAccelerometerAvailable
    }

    public var isGyroscopeAvailable: Bool {
        motionManager.isGyroAvailable
    }

    public var isMagnetometerAvailable: Bool {
        motionManager.isMagnetometerAvailable
    }

    public var isDeviceMotionAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    // MARK: - Accelerometer

    public func startAccelerometer(interval: TimeInterval = 0.1) {
        guard motionManager.isAccelerometerAvailable else { return }

        motionManager.accelerometerUpdateInterval = interval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            Task { @MainActor in
                self?.accelerometerData = data
            }
        }
        isAccelerometerActive = true
    }

    public func stopAccelerometer() {
        motionManager.stopAccelerometerUpdates()
        isAccelerometerActive = false
    }

    // MARK: - Gyroscope

    public func startGyroscope(interval: TimeInterval = 0.1) {
        guard motionManager.isGyroAvailable else { return }

        motionManager.gyroUpdateInterval = interval
        motionManager.startGyroUpdates(to: .main) { [weak self] data, error in
            Task { @MainActor in
                self?.gyroscopeData = data
            }
        }
        isGyroscopeActive = true
    }

    public func stopGyroscope() {
        motionManager.stopGyroUpdates()
        isGyroscopeActive = false
    }

    // MARK: - Magnetometer

    public func startMagnetometer(interval: TimeInterval = 0.1) {
        guard motionManager.isMagnetometerAvailable else { return }

        motionManager.magnetometerUpdateInterval = interval
        motionManager.startMagnetometerUpdates(to: .main) { [weak self] data, error in
            Task { @MainActor in
                self?.magnetometerData = data
            }
        }
        isMagnetometerActive = true
    }

    public func stopMagnetometer() {
        motionManager.stopMagnetometerUpdates()
        isMagnetometerActive = false
    }

    // MARK: - Device Motion (Combined)

    public func startDeviceMotion(interval: TimeInterval = 0.1) {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = interval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            Task { @MainActor in
                self?.deviceMotion = motion
            }
        }
        isDeviceMotionActive = true
    }

    public func stopDeviceMotion() {
        motionManager.stopDeviceMotionUpdates()
        isDeviceMotionActive = false
    }

    // MARK: - Stop All

    public func stopAll() {
        stopAccelerometer()
        stopGyroscope()
        stopMagnetometer()
        stopDeviceMotion()
    }
}

// MARK: - Notifications Manager

@MainActor
public final class ZylixNotificationsManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public private(set) var pendingCount: Int = 0

    // MARK: - Private Properties

    private let center = UNUserNotificationCenter.current()

    // MARK: - Singleton

    public static let shared = ZylixNotificationsManager()

    private init() {
        Task {
            await refreshStatus()
        }
    }

    // MARK: - Permission

    public func requestPermission(options: UNAuthorizationOptions = [.alert, .sound, .badge]) async throws -> Bool {
        let granted = try await center.requestAuthorization(options: options)
        await refreshStatus()
        return granted
    }

    public var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    // MARK: - Status

    public func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        let requests = await center.pendingNotificationRequests()
        pendingCount = requests.count
    }

    // MARK: - Schedule Notification

    public func schedule(
        id: String,
        title: String,
        body: String,
        sound: UNNotificationSound? = .default,
        badge: NSNumber? = nil,
        trigger: UNNotificationTrigger? = nil
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let sound = sound {
            content.sound = sound
        }
        if let badge = badge {
            content.badge = badge
        }

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
        await refreshStatus()
    }

    /// Schedule notification after delay
    public func scheduleAfter(
        id: String,
        title: String,
        body: String,
        seconds: TimeInterval,
        repeats: Bool = false
    ) async throws {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: repeats)
        try await schedule(id: id, title: title, body: body, trigger: trigger)
    }

    /// Schedule notification at specific date
    public func scheduleAt(
        id: String,
        title: String,
        body: String,
        date: DateComponents,
        repeats: Bool = false
    ) async throws {
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: repeats)
        try await schedule(id: id, title: title, body: body, trigger: trigger)
    }

    // MARK: - Cancel

    public func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        Task { await refreshStatus() }
    }

    public func cancelAll() {
        center.removeAllPendingNotificationRequests()
        Task { await refreshStatus() }
    }
}

// MARK: - Camera Manager

@MainActor
public final class ZylixCameraManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isAuthorized: Bool = false
    @Published public private(set) var isSessionRunning: Bool = false
    @Published public private(set) var capturedImage: UIImage?
    @Published public private(set) var lastError: Error?

    // MARK: - Capture Session

    public let captureSession = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput?
    private var currentDevice: AVCaptureDevice?
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    // MARK: - Singleton

    public static let shared = ZylixCameraManager()

    private override init() {
        super.init()
        checkAuthorization()
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = false
        default:
            isAuthorized = false
        }
    }

    public func requestPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            self.isAuthorized = granted
        }
        return granted
    }

    // MARK: - Session Setup

    public func setupSession(position: AVCaptureDevice.Position = .back) throws {
        guard isAuthorized else {
            throw ZylixDeviceError.permissionDenied
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        // Get camera device
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw ZylixDeviceError.deviceNotAvailable
        }
        currentDevice = device

        // Add input
        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        // Add photo output
        let output = AVCapturePhotoOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            photoOutput = output
        }

        captureSession.commitConfiguration()
    }

    // MARK: - Session Control

    public func startSession() {
        guard !captureSession.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            Task { @MainActor in
                self?.isSessionRunning = true
            }
        }
    }

    public func stopSession() {
        guard captureSession.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            Task { @MainActor in
                self?.isSessionRunning = false
            }
        }
    }

    // MARK: - Capture Photo

    public func capturePhoto() async throws -> UIImage {
        guard let photoOutput = photoOutput else {
            throw ZylixDeviceError.deviceNotAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation

            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Flash

    public func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        // Flash mode is set per-capture in AVCapturePhotoSettings
    }

    // MARK: - Switch Camera

    public func switchCamera() throws {
        let currentPosition = currentDevice?.position ?? .back
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

        captureSession.beginConfiguration()

        // Remove current input
        if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            captureSession.removeInput(currentInput)
        }

        // Add new input
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            captureSession.commitConfiguration()
            throw ZylixDeviceError.deviceNotAvailable
        }

        let newInput = try AVCaptureDeviceInput(device: newDevice)
        if captureSession.canAddInput(newInput) {
            captureSession.addInput(newInput)
            currentDevice = newDevice
        }

        captureSession.commitConfiguration()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension ZylixCameraManager: AVCapturePhotoCaptureDelegate {

    nonisolated public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.lastError = error
                self.photoContinuation?.resume(throwing: error)
                self.photoContinuation = nil
                return
            }

            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                let error = ZylixDeviceError.captureError
                self.lastError = error
                self.photoContinuation?.resume(throwing: error)
                self.photoContinuation = nil
                return
            }

            self.capturedImage = image
            self.photoContinuation?.resume(returning: image)
            self.photoContinuation = nil
        }
    }
}

// MARK: - Audio Manager

@MainActor
public final class ZylixAudioManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var recordingURL: URL?
    @Published public private(set) var lastError: Error?

    // MARK: - Private Properties

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Singleton

    public static let shared = ZylixAudioManager()

    private override init() {
        super.init()
    }

    // MARK: - Permission

    public func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    public var isRecordingAuthorized: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    // MARK: - Audio Session

    public func configureSession(category: AVAudioSession.Category = .playAndRecord) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(category, mode: .default)
        try session.setActive(true)
    }

    // MARK: - Recording

    public func startRecording(to url: URL? = nil) throws {
        guard isRecordingAuthorized else {
            throw ZylixDeviceError.permissionDenied
        }

        try configureSession(category: .record)

        let outputURL = url ?? FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: outputURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()

        recordingURL = outputURL
        isRecording = true
    }

    public func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }

    // MARK: - Playback

    public func play(url: URL) throws {
        try configureSession(category: .playback)

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.play()
        isPlaying = true
    }

    public func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
    }

    public func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
}

// MARK: - AVAudioRecorderDelegate

extension ZylixAudioManager: AVAudioRecorderDelegate {
    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension ZylixAudioManager: AVAudioPlayerDelegate {
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
        }
    }
}

// MARK: - Device Errors

public enum ZylixDeviceError: Error, LocalizedError {
    case permissionDenied
    case deviceNotAvailable
    case captureError
    case recordingError
    case notInitialized

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission denied"
        case .deviceNotAvailable:
            return "Device not available"
        case .captureError:
            return "Failed to capture photo"
        case .recordingError:
            return "Recording failed"
        case .notInitialized:
            return "Not initialized"
        }
    }
}

// MARK: - Unified Device Manager

@MainActor
public final class ZylixDevice: ObservableObject {

    /// Location services
    public let location = ZylixLocationManager.shared

    /// Haptic feedback
    public let haptics = ZylixHapticsManager.shared

    /// Motion sensors
    public let sensors = ZylixSensorsManager.shared

    /// Notifications
    public let notifications = ZylixNotificationsManager.shared

    /// Camera
    public let camera = ZylixCameraManager.shared

    /// Audio
    public let audio = ZylixAudioManager.shared

    // MARK: - Singleton

    public static let shared = ZylixDevice()

    private init() {}
}

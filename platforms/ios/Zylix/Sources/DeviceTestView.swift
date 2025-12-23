//
//  DeviceTestView.swift
//  Zylix
//
//  Test view for device features (Location, Haptics, Sensors, Camera, Audio).
//

import SwiftUI
import CoreLocation
import CoreMotion

struct DeviceTestView: View {
    @StateObject private var device = ZylixDevice.shared
    @State private var statusMessages: [String] = []

    var body: some View {
        NavigationView {
            List {
                // Location Section
                Section("Location") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(device.location.isAuthorized ? "Authorized" : "Not Authorized")
                            .foregroundColor(device.location.isAuthorized ? .green : .red)
                    }

                    if let location = device.location.currentLocation {
                        Text("Lat: \(location.coordinate.latitude, specifier: "%.4f")")
                        Text("Lon: \(location.coordinate.longitude, specifier: "%.4f")")
                    }

                    Button("Request Permission") {
                        device.location.requestPermission()
                        addStatus("Location permission requested")
                    }

                    Button("Get Current Location") {
                        Task {
                            do {
                                let loc = try await device.location.getCurrentLocation()
                                addStatus("Location: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
                            } catch {
                                addStatus("Location error: \(error.localizedDescription)")
                            }
                        }
                    }
                }

                // Haptics Section
                Section("Haptics") {
                    Button("Light Impact") {
                        device.haptics.impact(.light)
                        addStatus("Light haptic triggered")
                    }

                    Button("Medium Impact") {
                        device.haptics.impact(.medium)
                        addStatus("Medium haptic triggered")
                    }

                    Button("Heavy Impact") {
                        device.haptics.impact(.heavy)
                        addStatus("Heavy haptic triggered")
                    }

                    Button("Success Notification") {
                        device.haptics.notification(.success)
                        addStatus("Success notification triggered")
                    }

                    Button("Error Notification") {
                        device.haptics.notification(.error)
                        addStatus("Error notification triggered")
                    }

                    Button("Selection") {
                        device.haptics.selection()
                        addStatus("Selection haptic triggered")
                    }
                }

                // Sensors Section
                Section("Sensors") {
                    HStack {
                        Text("Accelerometer")
                        Spacer()
                        Text(device.sensors.isAccelerometerAvailable ? "Available" : "N/A")
                            .foregroundColor(device.sensors.isAccelerometerAvailable ? .green : .gray)
                    }

                    HStack {
                        Text("Gyroscope")
                        Spacer()
                        Text(device.sensors.isGyroscopeAvailable ? "Available" : "N/A")
                            .foregroundColor(device.sensors.isGyroscopeAvailable ? .green : .gray)
                    }

                    if let accel = device.sensors.accelerometerData {
                        Text("Accel X: \(accel.acceleration.x, specifier: "%.2f")")
                        Text("Accel Y: \(accel.acceleration.y, specifier: "%.2f")")
                        Text("Accel Z: \(accel.acceleration.z, specifier: "%.2f")")
                    }

                    HStack {
                        Button(device.sensors.isAccelerometerActive ? "Stop Accel" : "Start Accel") {
                            if device.sensors.isAccelerometerActive {
                                device.sensors.stopAccelerometer()
                                addStatus("Accelerometer stopped")
                            } else {
                                device.sensors.startAccelerometer()
                                addStatus("Accelerometer started")
                            }
                        }
                        .buttonStyle(.bordered)

                        Button(device.sensors.isGyroscopeActive ? "Stop Gyro" : "Start Gyro") {
                            if device.sensors.isGyroscopeActive {
                                device.sensors.stopGyroscope()
                                addStatus("Gyroscope stopped")
                            } else {
                                device.sensors.startGyroscope()
                                addStatus("Gyroscope started")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Notifications Section
                Section("Notifications") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(device.notifications.isAuthorized ? "Authorized" : "Not Authorized")
                            .foregroundColor(device.notifications.isAuthorized ? .green : .red)
                    }

                    Text("Pending: \(device.notifications.pendingCount)")

                    Button("Request Permission") {
                        Task {
                            do {
                                let granted = try await device.notifications.requestPermission()
                                addStatus("Notification permission: \(granted)")
                            } catch {
                                addStatus("Notification error: \(error.localizedDescription)")
                            }
                        }
                    }

                    Button("Schedule Test (5 sec)") {
                        Task {
                            do {
                                try await device.notifications.scheduleAfter(
                                    id: "test-\(Date().timeIntervalSince1970)",
                                    title: "Zylix Test",
                                    body: "This is a test notification from Zylix Device",
                                    seconds: 5
                                )
                                addStatus("Notification scheduled for 5 seconds")
                            } catch {
                                addStatus("Schedule error: \(error.localizedDescription)")
                            }
                        }
                    }
                }

                // Camera Section
                Section("Camera") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(device.camera.isAuthorized ? "Authorized" : "Not Authorized")
                            .foregroundColor(device.camera.isAuthorized ? .green : .red)
                    }

                    Button("Request Permission") {
                        Task {
                            let granted = await device.camera.requestPermission()
                            addStatus("Camera permission: \(granted)")
                        }
                    }
                }

                // Audio Section
                Section("Audio") {
                    HStack {
                        Text("Recording")
                        Spacer()
                        Text(device.audio.isRecordingAuthorized ? "Authorized" : "Not Authorized")
                            .foregroundColor(device.audio.isRecordingAuthorized ? .green : .red)
                    }

                    Button("Request Permission") {
                        Task {
                            let granted = await device.audio.requestPermission()
                            addStatus("Microphone permission: \(granted)")
                        }
                    }
                }

                // Status Log
                Section("Status Log") {
                    ForEach(statusMessages.reversed(), id: \.self) { message in
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if statusMessages.isEmpty {
                        Text("No status messages yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Device Test")
        }
    }

    private func addStatus(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        statusMessages.append("[\(timestamp)] \(message)")
        if statusMessages.count > 20 {
            statusMessages.removeFirst()
        }
    }
}

#Preview {
    DeviceTestView()
}

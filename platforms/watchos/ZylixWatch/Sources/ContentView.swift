//
//  ContentView.swift
//  ZylixWatch
//
//  Main content view - Counter PoC demonstration for watchOS.
//  Optimized for small watch screen with Digital Crown support.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bridge: ZylixBridge
    @State private var crownValue: Double = 0.0

    var body: some View {
        VStack(spacing: 12) {
            // Header
            headerSection

            // Counter Display
            counterSection

            // Control Buttons
            controlSection

            // State Info (Compact)
            stateInfoSection
        }
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: -1000,
            through: 1000,
            sensitivity: .medium,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            handleCrownChange(newValue)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Image(systemName: "cpu")
                .font(.system(size: 16))
                .foregroundStyle(.blue)

            Text("Zylix")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Counter Section

    private var counterSection: some View {
        VStack(spacing: 4) {
            Text("\(bridge.state.counter)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: bridge.state.counter)

            Text("Counter")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Control Section

    private var controlSection: some View {
        HStack(spacing: 16) {
            // Decrement Button
            Button {
                bridge.decrement()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 32))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .accessibilityLabel("Decrement")

            // Reset Button
            Button {
                bridge.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 24))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)
            .accessibilityLabel("Reset")

            // Increment Button
            Button {
                bridge.increment()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.green)
            .accessibilityLabel("Increment")
        }
    }

    // MARK: - State Info Section (Compact)

    private var stateInfoSection: some View {
        HStack {
            Circle()
                .fill(bridge.isInitialized ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text("v\(bridge.state.version)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Digital Crown Handler

    private var lastCrownPosition: Double = 0.0

    private func handleCrownChange(_ newValue: Double) {
        let delta = Int(newValue - crownValue)
        if delta > 0 {
            bridge.increment()
        } else if delta < 0 {
            bridge.decrement()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(ZylixBridge.shared)
}

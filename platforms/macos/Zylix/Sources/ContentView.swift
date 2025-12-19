//
//  ContentView.swift
//  Zylix
//
//  Main content view - Counter PoC demonstration for macOS.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bridge: ZylixBridge

    var body: some View {
        VStack(spacing: 40) {
            // Header
            headerSection

            Spacer()

            // Counter Display
            counterSection

            Spacer()

            // Control Buttons
            controlSection

            // State Info (Debug)
            stateInfoSection
        }
        .padding(30)
        .frame(minWidth: 350, minHeight: 450)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("Zylix Core")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("State managed by Zig")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Counter Section

    private var counterSection: some View {
        VStack(spacing: 16) {
            Text("\(bridge.state.counter)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: bridge.state.counter)

            Text("Counter Value")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Control Section

    private var controlSection: some View {
        HStack(spacing: 20) {
            // Decrement Button
            Button {
                bridge.decrement()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 60))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)

            // Reset Button
            Button {
                bridge.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 44))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)

            // Increment Button
            Button {
                bridge.increment()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 60))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.green)
        }
    }

    // MARK: - State Info Section

    private var stateInfoSection: some View {
        VStack(spacing: 4) {
            Divider()
                .padding(.vertical, 8)

            HStack {
                Label("State Version", systemImage: "number")
                Spacer()
                Text("\(bridge.state.version)")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Label("Initialized", systemImage: "checkmark.circle")
                Spacer()
                Text(bridge.isInitialized ? "Yes" : "No")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let error = bridge.lastError {
                HStack {
                    Label("Error", systemImage: "exclamationmark.triangle")
                    Spacer()
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(ZylixBridge.shared)
}

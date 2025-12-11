//
//  WebRTCConnectionManager.swift
//  ElderGuard
//
//  Created by Claude on 2025/12/10.
//

import Foundation
import StreamWebRTC
import SwiftUI

enum ConnectionState {
	case disconnected
	case connecting
	case connected
	case reconnecting
	case failed
}

@MainActor
final class WebRTCConnectionManager: ObservableObject {
	static let shared = WebRTCConnectionManager()

	// Published state for SwiftUI
	@Published private(set) var remoteVideoTrack: RTCVideoTrack?
	@Published private(set) var connectionState: ConnectionState = .disconnected
	@Published private(set) var errorMessage: String?

	// Internal components
	private var webRTCClient: WebRTCClient?
	private var signalingClient: SignalingClient?

	// Observer tracking
	private var observerCount = 0

	// Reconnection logic
	private var reconnectTimer: Timer?
	private var reconnectAttempts = 0
	private let maxReconnectDelay: TimeInterval = 30

	private init() {
		print("WebRTCConnectionManager: Initialized")
	}

	// MARK: - Observer Management

	func startObserving() {
		observerCount += 1
		print("WebRTCConnectionManager: Observer added (count: \(observerCount), state: \(connectionState), hasVideoTrack: \(remoteVideoTrack != nil))")

		// First observer should initiate connection if disconnected
		if observerCount == 1, connectionState == .disconnected {
			print("WebRTCConnectionManager: First observer, initiating connection")
			connect()
		}
		// If we have observers joining but connection is failed, try reconnecting
		else if connectionState == .failed {
			print("WebRTCConnectionManager: Observer added but connection failed, reconnecting")
			connect()
		}
		// If connected but no video track, something is wrong - reconnect
		else if connectionState == .connected, remoteVideoTrack == nil {
			print("WebRTCConnectionManager: Observer added but no video track despite connected state, reconnecting")
			disconnect()
			connect()
		}
	}

	func stopObserving() {
		observerCount -= 1
		print("WebRTCConnectionManager: Observer removed (count: \(observerCount))")

		// Keep connection alive even when count reaches 0
		// Only disconnect on app termination
	}

	// MARK: - Connection Lifecycle

	func connect() {
		// Don't start a new connection if already connecting/reconnecting
		if connectionState == .connecting || connectionState == .reconnecting {
			print("WebRTCConnectionManager: Already connecting or reconnecting, skipping")
			return
		}

		// Safety check: if somehow still connected, something is wrong - log and force disconnect
		if connectionState == .connected {
			print("WebRTCConnectionManager: ⚠️ WARNING: connect() called while already connected - forcing disconnect first")
			disconnect()
		}

		print("WebRTCConnectionManager: Connecting...")
		connectionState = .connecting
		errorMessage = nil

		// Create WebRTC client
		webRTCClient = WebRTCClient()
		webRTCClient?.delegate = self

		// Create signaling client
		let signalingURL = AppEnvironment.current.signalingURL
		signalingClient = SignalingClient(url: signalingURL)
		signalingClient?.delegate = self
		signalingClient?.connect()
	}

	func disconnect() {
		print("WebRTCConnectionManager: Disconnecting...")

		cancelReconnect()

		signalingClient?.disconnect()
		webRTCClient?.close()

		signalingClient = nil
		webRTCClient = nil
		remoteVideoTrack = nil

		connectionState = .disconnected
		errorMessage = nil
		reconnectAttempts = 0
	}

	// MARK: - Lifecycle Handling

	func handleBackground() {
		print("WebRTCConnectionManager: App entering background (observers: \(observerCount), state: \(connectionState))")
		// Keep connection alive - WebRTC should continue in background with proper Info.plist config
	}

	func handleForeground() {
		print("WebRTCConnectionManager: App entering foreground (observers: \(observerCount), state: \(connectionState), hasVideoTrack: \(remoteVideoTrack != nil))")

		// If we have observers but no video track, the connection is broken even if state shows connected
		if observerCount > 0 {
			if connectionState == .failed || connectionState == .disconnected {
				print("WebRTCConnectionManager: Reconnecting on foreground (state failed/disconnected)")
				connect()
			} else if connectionState == .connected && remoteVideoTrack == nil {
				// Connection state shows connected but no video track - need to reconnect
				print("WebRTCConnectionManager: Reconnecting on foreground (no video track)")
				disconnect()
				connect()
			} else if connectionState == .connecting || connectionState == .reconnecting {
				// Already trying to connect, do nothing
				print("WebRTCConnectionManager: Already connecting, no action needed")
			}
		}
	}

	// MARK: - Reconnection Logic

	private func scheduleReconnect() {
		cancelReconnect()

		let delay = min(pow(2.0, Double(reconnectAttempts)), maxReconnectDelay)
		reconnectAttempts += 1

		print("WebRTCConnectionManager: Scheduling reconnect in \(delay)s (attempt \(reconnectAttempts))")

		connectionState = .reconnecting

		reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
			Task { @MainActor [weak self] in
				self?.connect()
			}
		}
	}

	private func cancelReconnect() {
		reconnectTimer?.invalidate()
		reconnectTimer = nil
	}

	private func resetReconnectAttempts() {
		reconnectAttempts = 0
		cancelReconnect()
	}
}

// MARK: - SignalingClientDelegate

extension WebRTCConnectionManager: SignalingClientDelegate {
	nonisolated func signalingDidConnect(_ client: SignalingClient) {
		print("WebRTCConnectionManager: Signaling connected, sending ready")
		// Send ready signal to request offer from server
		client.sendReady()
	}

	nonisolated func signalingDidDisconnect(_: SignalingClient) {
		print("WebRTCConnectionManager: Signaling disconnected")
		Task { @MainActor in
			if self.connectionState == .connecting || self.connectionState == .connected {
				self.errorMessage = "Mất kết nối"
				self.connectionState = .failed
				self.scheduleReconnect()
			}
		}
	}

	nonisolated func signaling(_: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
		print("WebRTCConnectionManager: Received remote SDP: \(sdp.type.rawValue)")
		Task { @MainActor in
			self.webRTCClient?.set(remoteSdp: sdp) { [weak self] error in
				if let error {
					print("WebRTCConnectionManager: Failed to set remote SDP: \(error)")
					Task { @MainActor in
						self?.errorMessage = "Kết nối thất bại"
						self?.connectionState = .failed
						self?.scheduleReconnect()
					}
					return
				}

				// Server sends offer, we respond with answer
				if sdp.type == .offer {
					self?.webRTCClient?.answer { [weak self] answerSdp in
						guard let answerSdp else { return }
						print("WebRTCConnectionManager: Sending answer")
						self?.signalingClient?.send(sdp: answerSdp)
					}
				}
			}
		}
	}

	nonisolated func signaling(_: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
		Task { @MainActor in
			self.webRTCClient?.set(remoteCandidate: candidate) { error in
				if let error {
					print("WebRTCConnectionManager: Failed to add ICE candidate: \(error)")
				}
			}
		}
	}
}

// MARK: - WebRTCClientDelegate

extension WebRTCConnectionManager: WebRTCClientDelegate {
	nonisolated func webRTCClient(_: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack) {
		print("WebRTCConnectionManager: Received remote video track")
		Task { @MainActor in
			self.remoteVideoTrack = track
			self.connectionState = .connected
			self.errorMessage = nil
			self.resetReconnectAttempts()
		}
	}

	nonisolated func webRTCClient(_: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
		print("WebRTCConnectionManager: Connection state: \(state.rawValue)")
		Task { @MainActor in
			switch state {
				case .connected, .completed:
					self.connectionState = .connected
					self.errorMessage = nil
					self.resetReconnectAttempts()
				case .failed:
					self.errorMessage = "Kết nối thất bại"
					self.connectionState = .failed
					self.scheduleReconnect()
				case .disconnected:
					self.errorMessage = "Mất kết nối"
					self.connectionState = .failed
					self.scheduleReconnect()
				case .closed:
					self.remoteVideoTrack = nil
					self.connectionState = .disconnected
				default:
					break
			}
		}
	}

	nonisolated func webRTCClient(_: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate) {
		Task { @MainActor in
			self.signalingClient?.send(candidate: candidate)
		}
	}
}

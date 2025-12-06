//
//  WebRTCVideoView.swift
//  ElderGuard
//
//  Created by Claude on 2025/12/06.
//

import StreamWebRTC
import SwiftUI

struct WebRTCVideoView: UIViewRepresentable {
	let videoTrack: RTCVideoTrack?

	func makeUIView(context _: Context) -> RTCMTLVideoView {
		let videoView = RTCMTLVideoView(frame: .zero)
		videoView.videoContentMode = .scaleAspectFill
		videoView.clipsToBounds = true
		return videoView
	}

	func updateUIView(_ uiView: RTCMTLVideoView, context _: Context) {
		if let track = videoTrack {
			track.add(uiView)
		}
	}

	static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator _: ()) {
		uiView.renderFrame(nil)
	}
}

// MARK: - WebRTC Stream View

struct WebRTCStreamView: View {
	@StateObject private var viewModel = WebRTCStreamViewModel()

	var body: some View {
		ZStack {
			if let videoTrack = viewModel.remoteVideoTrack {
				WebRTCVideoView(videoTrack: videoTrack)
			} else {
				Rectangle()
					.fill(Color.black)
					.overlay {
						if viewModel.isConnecting {
							ProgressView()
								.progressViewStyle(.circular)
								.tint(.white)
						} else if let error = viewModel.errorMessage {
							VStack(spacing: 8) {
								Image(systemName: "exclamationmark.triangle")
									.font(.largeTitle)
									.foregroundStyle(.yellow)
								Text(error)
									.font(.caption)
									.foregroundStyle(.white)
									.multilineTextAlignment(.center)
							}
							.padding()
						} else {
							Text("No video")
								.foregroundStyle(.white.opacity(0.6))
						}
					}
			}
		}
		.onAppear {
			viewModel.connect()
		}
		.onDisappear {
			viewModel.disconnect()
		}
	}
}

// MARK: - View Model

@MainActor
final class WebRTCStreamViewModel: ObservableObject {
	@Published private(set) var remoteVideoTrack: RTCVideoTrack?
	@Published private(set) var isConnecting = false
	@Published private(set) var errorMessage: String?

	private var webRTCClient: WebRTCClient?
	private var signalingClient: SignalingClient?

	func connect() {
		isConnecting = true
		errorMessage = nil

		webRTCClient = WebRTCClient()
		webRTCClient?.delegate = self

		let signalingURL = AppEnvironment.current.signalingURL
		signalingClient = SignalingClient(url: signalingURL)
		signalingClient?.delegate = self
		signalingClient?.connect()
	}

	func disconnect() {
		signalingClient?.disconnect()
		webRTCClient?.close()
		signalingClient = nil
		webRTCClient = nil
		remoteVideoTrack = nil
		isConnecting = false
	}
}

// MARK: - SignalingClientDelegate

extension WebRTCStreamViewModel: SignalingClientDelegate {
	nonisolated func signalingDidConnect(_ client: SignalingClient) {
		print("WebRTCStreamViewModel: Signaling connected, sending ready")
		// Send ready signal to request offer from server
		client.sendReady()
	}

	nonisolated func signalingDidDisconnect(_: SignalingClient) {
		print("WebRTCStreamViewModel: Signaling disconnected")
		Task { @MainActor in
			self.isConnecting = false
		}
	}

	nonisolated func signaling(_: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
		print("WebRTCStreamViewModel: Received remote SDP: \(sdp.type.rawValue)")
		Task { @MainActor in
			self.webRTCClient?.set(remoteSdp: sdp) { [weak self] error in
				if let error {
					print("WebRTCStreamViewModel: Failed to set remote SDP: \(error)")
					Task { @MainActor in
						self?.errorMessage = "Connection failed"
						self?.isConnecting = false
					}
					return
				}

				// Server sends offer, we respond with answer
				if sdp.type == .offer {
					self?.webRTCClient?.answer { [weak self] answerSdp in
						guard let answerSdp else { return }
						print("WebRTCStreamViewModel: Sending answer")
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
					print("WebRTCStreamViewModel: Failed to add ICE candidate: \(error)")
				}
			}
		}
	}
}

// MARK: - WebRTCClientDelegate

extension WebRTCStreamViewModel: WebRTCClientDelegate {
	nonisolated func webRTCClient(_: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack) {
		print("WebRTCStreamViewModel: Received remote video track")
		Task { @MainActor in
			self.remoteVideoTrack = track
			self.isConnecting = false
		}
	}

	nonisolated func webRTCClient(_: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
		print("WebRTCStreamViewModel: Connection state: \(state.rawValue)")
		Task { @MainActor in
			switch state {
				case .connected, .completed:
					self.isConnecting = false
					self.errorMessage = nil
				case .failed:
					self.errorMessage = "Connection failed"
					self.isConnecting = false
				case .disconnected:
					self.errorMessage = "Disconnected"
					self.isConnecting = false
				case .closed:
					self.remoteVideoTrack = nil
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

#Preview {
	WebRTCStreamView()
		.frame(height: 250)
}

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
	@ObservedObject private var connectionManager = WebRTCConnectionManager.shared

	var body: some View {
		ZStack {
			if let videoTrack = connectionManager.remoteVideoTrack {
				WebRTCVideoView(videoTrack: videoTrack)
			} else {
				Rectangle()
					.fill(Color.black)
					.overlay {
						if connectionManager.connectionState == .connecting || connectionManager.connectionState == .reconnecting {
							ProgressView()
								.progressViewStyle(.circular)
								.tint(.white)
						} else if let error = connectionManager.errorMessage {
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
			connectionManager.startObserving()
		}
		.onDisappear {
			connectionManager.stopObserving()
		}
	}
}

#Preview {
	WebRTCStreamView()
		.frame(height: 250)
}

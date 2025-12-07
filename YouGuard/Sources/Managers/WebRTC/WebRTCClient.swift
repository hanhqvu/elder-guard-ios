//
//  WebRTCClient.swift
//  ElderGuard
//
//  Created by Claude on 2025/12/06.
//

import Foundation
import StreamWebRTC

protocol WebRTCClientDelegate: AnyObject {
	func webRTCClient(_ client: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack)
	func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
	func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate)
}

final class WebRTCClient: NSObject {
	weak var delegate: WebRTCClientDelegate?

	private static let factory: RTCPeerConnectionFactory = {
		RTCInitializeSSL()
		let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
		let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
		return RTCPeerConnectionFactory(
			encoderFactory: videoEncoderFactory,
			decoderFactory: videoDecoderFactory
		)
	}()

	private let peerConnection: RTCPeerConnection
	private let rtcAudioSession = RTCAudioSession.sharedInstance()

	private(set) var remoteVideoTrack: RTCVideoTrack?

	override init() {
		let config = RTCConfiguration()
		config.iceServers = [
			RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
		]
		config.sdpSemantics = .unifiedPlan
		config.continualGatheringPolicy = .gatherContinually

		let constraints = RTCMediaConstraints(
			mandatoryConstraints: nil,
			optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
		)

		guard let peerConnection = Self.factory.peerConnection(
			with: config,
			constraints: constraints,
			delegate: nil
		) else {
			fatalError("Failed to create RTCPeerConnection")
		}

		self.peerConnection = peerConnection

		super.init()

		self.peerConnection.delegate = self
		configureAudioSession()
	}

	private func configureAudioSession() {
		rtcAudioSession.lockForConfiguration()
		do {
			try rtcAudioSession.setCategory(AVAudioSession.Category(rawValue: AVAudioSession.Category.playback.rawValue))
			try rtcAudioSession.setMode(AVAudioSession.Mode(rawValue: AVAudioSession.Mode.default.rawValue))
		} catch {
			print("WebRTCClient: Failed to configure audio session: \(error)")
		}
		rtcAudioSession.unlockForConfiguration()
	}

	func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
		peerConnection.setRemoteDescription(remoteSdp) { error in
			completion(error)
		}
	}

	func set(remoteCandidate: RTCIceCandidate, completion: @escaping (Error?) -> Void) {
		peerConnection.add(remoteCandidate) { error in
			completion(error)
		}
	}

	func answer(completion: @escaping (RTCSessionDescription?) -> Void) {
		let constraints = RTCMediaConstraints(
			mandatoryConstraints: [
				"OfferToReceiveVideo": "true",
				"OfferToReceiveAudio": "true"
			],
			optionalConstraints: nil
		)

		peerConnection.answer(for: constraints) { [weak self] sdp, error in
			guard let sdp else {
				print("WebRTCClient: Failed to create answer: \(String(describing: error))")
				completion(nil)
				return
			}

			self?.peerConnection.setLocalDescription(sdp) { error in
				if let error {
					print("WebRTCClient: Failed to set local description: \(error)")
					completion(nil)
					return
				}
				completion(sdp)
			}
		}
	}

	func offer(completion: @escaping (RTCSessionDescription?) -> Void) {
		let constraints = RTCMediaConstraints(
			mandatoryConstraints: [
				"OfferToReceiveVideo": "true",
				"OfferToReceiveAudio": "true"
			],
			optionalConstraints: nil
		)

		peerConnection.offer(for: constraints) { [weak self] sdp, error in
			guard let sdp else {
				print("WebRTCClient: Failed to create offer: \(String(describing: error))")
				completion(nil)
				return
			}

			self?.peerConnection.setLocalDescription(sdp) { error in
				if let error {
					print("WebRTCClient: Failed to set local description: \(error)")
					completion(nil)
					return
				}
				completion(sdp)
			}
		}
	}

	func close() {
		peerConnection.close()
	}
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCClient: RTCPeerConnectionDelegate {
	func peerConnection(_: RTCPeerConnection, didChange state: RTCSignalingState) {
		print("WebRTCClient: Signaling state changed: \(state.rawValue)")
	}

	func peerConnection(_: RTCPeerConnection, didAdd stream: RTCMediaStream) {
		print("WebRTCClient: Stream added: \(stream.streamId)")
		if let videoTrack = stream.videoTracks.first {
			remoteVideoTrack = videoTrack
			DispatchQueue.main.async { [weak self] in
				guard let self else { return }
				self.delegate?.webRTCClient(self, didReceiveRemoteVideoTrack: videoTrack)
			}
		}
	}

	func peerConnection(_: RTCPeerConnection, didRemove _: RTCMediaStream) {
		print("WebRTCClient: Stream removed")
	}

	func peerConnectionShouldNegotiate(_: RTCPeerConnection) {
		print("WebRTCClient: Negotiation needed")
	}

	func peerConnection(_: RTCPeerConnection, didChange state: RTCIceConnectionState) {
		print("WebRTCClient: ICE connection state changed: \(state.rawValue)")
		DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			self.delegate?.webRTCClient(self, didChangeConnectionState: state)
		}
	}

	func peerConnection(_: RTCPeerConnection, didChange _: RTCIceGatheringState) {
		print("WebRTCClient: ICE gathering state changed")
	}

	func peerConnection(_: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
		DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			self.delegate?.webRTCClient(self, didGenerateLocalCandidate: candidate)
		}
	}

	func peerConnection(_: RTCPeerConnection, didRemove _: [RTCIceCandidate]) {
		print("WebRTCClient: ICE candidates removed")
	}

	func peerConnection(_: RTCPeerConnection, didOpen _: RTCDataChannel) {
		print("WebRTCClient: Data channel opened")
	}

	func peerConnection(_: RTCPeerConnection, didChange _: RTCPeerConnectionState) {
		print("WebRTCClient: Peer connection state changed")
	}

	func peerConnection(_: RTCPeerConnection, didAdd _: RTCRtpReceiver, streams _: [RTCMediaStream]) {
		print("WebRTCClient: RTP receiver added")
	}

	func peerConnection(_: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
		print("WebRTCClient: Started receiving on transceiver: \(transceiver.mediaType.rawValue)")
		if transceiver.mediaType == .video,
		   let track = transceiver.receiver.track as? RTCVideoTrack {
			remoteVideoTrack = track
			DispatchQueue.main.async { [weak self] in
				guard let self else { return }
				self.delegate?.webRTCClient(self, didReceiveRemoteVideoTrack: track)
			}
		}
	}

	func peerConnection(_: RTCPeerConnection, didRemove _: RTCRtpReceiver) {
		print("WebRTCClient: RTP receiver removed")
	}
}

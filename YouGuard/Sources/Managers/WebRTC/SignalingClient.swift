//
//  SignalingClient.swift
//  ElderGuard
//
//  Created by Claude on 2025/12/06.
//

import Foundation
import StreamWebRTC

protocol SignalingClientDelegate: AnyObject {
	func signaling(_ client: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription)
	func signaling(_ client: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate)
	func signalingDidConnect(_ client: SignalingClient)
	func signalingDidDisconnect(_ client: SignalingClient)
}

final class SignalingClient: NSObject {
	weak var delegate: SignalingClientDelegate?

	private let url: URL
	private var webSocketTask: URLSessionWebSocketTask?
	private var urlSession: URLSession?
	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()

	private var isConnected = false

	init(url: URL) {
		self.url = url
		super.init()
	}

	func connect() {
		let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
		urlSession = session
		webSocketTask = session.webSocketTask(with: url)
		webSocketTask?.resume()
		readMessage()
	}

	/// Send ready signal to request offer from server
	func sendReady() {
		let message = SignalingMessage(
			type: .ready,
			sdp: nil,
			candidate: nil,
			sdpMid: nil,
			sdpMLineIndex: nil
		)
		sendMessage(message)
	}

	func disconnect() {
		webSocketTask?.cancel(with: .goingAway, reason: nil)
		webSocketTask = nil
		urlSession?.invalidateAndCancel()
		urlSession = nil
		isConnected = false
	}

	func send(sdp: RTCSessionDescription) {
		let message = SignalingMessage(
			type: sdp.type == .offer ? .offer : .answer,
			sdp: sdp.sdp,
			candidate: nil,
			sdpMid: nil,
			sdpMLineIndex: nil
		)
		sendMessage(message)
	}

	func send(candidate: RTCIceCandidate) {
		let message = SignalingMessage(
			type: .candidate,
			sdp: nil,
			candidate: candidate.sdp,
			sdpMid: candidate.sdpMid,
			sdpMLineIndex: candidate.sdpMLineIndex
		)
		sendMessage(message)
	}

	private func sendMessage(_ message: SignalingMessage) {
		guard let data = try? encoder.encode(message),
		      let string = String(data: data, encoding: .utf8)
		else {
			return
		}

		webSocketTask?.send(.string(string)) { error in
			if let error {
				print("SignalingClient: Failed to send message: \(error)")
			}
		}
	}

	private func readMessage() {
		webSocketTask?.receive { [weak self] result in
			guard let self else { return }

			switch result {
				case let .success(message):
					switch message {
						case let .string(text):
							self.handleMessage(text)
						case let .data(data):
							if let text = String(data: data, encoding: .utf8) {
								self.handleMessage(text)
							}
						@unknown default:
							break
					}
					self.readMessage()

				case let .failure(error):
					print("SignalingClient: WebSocket receive error: \(error)")
			}
		}
	}

	private func handleMessage(_ text: String) {
		guard let data = text.data(using: .utf8),
		      let message = try? decoder.decode(SignalingMessage.self, from: data)
		else {
			print("SignalingClient: Failed to decode message: \(text)")
			return
		}

		DispatchQueue.main.async { [weak self] in
			guard let self else { return }

			switch message.type {
				case .ready:
					// Server doesn't send ready, only client does
					break

				case .offer:
					if let sdpString = message.sdp {
						let sdp = RTCSessionDescription(type: .offer, sdp: sdpString)
						self.delegate?.signaling(self, didReceiveRemoteSdp: sdp)
					}

				case .answer:
					if let sdpString = message.sdp {
						let sdp = RTCSessionDescription(type: .answer, sdp: sdpString)
						self.delegate?.signaling(self, didReceiveRemoteSdp: sdp)
					}

				case .candidate:
					if let candidateString = message.candidate {
						let candidate = RTCIceCandidate(
							sdp: candidateString,
							sdpMLineIndex: message.sdpMLineIndex ?? 0,
							sdpMid: message.sdpMid
						)
						self.delegate?.signaling(self, didReceiveCandidate: candidate)
					}
			}
		}
	}
}

// MARK: - URLSessionWebSocketDelegate

extension SignalingClient: URLSessionWebSocketDelegate {
	func urlSession(
		_: URLSession,
		webSocketTask _: URLSessionWebSocketTask,
		didOpenWithProtocol _: String?
	) {
		isConnected = true
		DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			self.delegate?.signalingDidConnect(self)
		}
	}

	func urlSession(
		_: URLSession,
		webSocketTask _: URLSessionWebSocketTask,
		didCloseWith _: URLSessionWebSocketTask.CloseCode,
		reason _: Data?
	) {
		isConnected = false
		DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			self.delegate?.signalingDidDisconnect(self)
		}
	}
}

// MARK: - Signaling Message

private enum SignalingMessageType: String, Codable {
	case ready
	case offer
	case answer
	case candidate
}

private struct SignalingMessage: Codable {
	let type: SignalingMessageType
	let sdp: String?
	let candidate: String?
	let sdpMid: String?
	let sdpMLineIndex: Int32?
}

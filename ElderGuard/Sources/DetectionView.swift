//
//  DetectionView.swift
//  ElderGuard
//
//  Created by Hanh Vu on 2025/11/29.
//

import AVKit
import SwiftUI

struct DetectionView: View {
	let notificationId: String
	let phoneNumber: String
	var onDismiss: (() -> Void)?

	@State private var isMicActive = false

	var body: some View {
		VStack {
			VStack(spacing: 0) {
				// Livestream Video
				HLSVideoPlayer()
					.frame(height: 250)

				// Mic Button for 2-way audio
				Button {
					isMicActive.toggle()
				} label: {
					Image(systemName: isMicActive ? "mic.fill" : "mic.slash.fill")
						.font(.title2)
						.foregroundStyle(.white)
						.frame(width: 56, height: 56)
						.background(isMicActive ? Color.green : Color.gray.opacity(0.8))
						.clipShape(Circle())
						.shadow(radius: 4)
				}
				.padding(.top, 8)
			}

			// Buttons
			VStack(spacing: 60) {
				// Slide to Call Button
				SlideToCallButton(phoneNumber: phoneNumber, onDismiss: onDismiss)

				// Dismiss Button
				Button {
					Task {
						try? await DetectionNotificationRepository.shared.markAsViewed(id: notificationId)
						onDismiss?()
					}
				} label: {
					VStack(spacing: 8) {
						Image(systemName: "xmark.circle.fill")
							.font(.system(size: 48))
							.foregroundStyle(.white, Color.gray.opacity(0.6))
						Text("Dismiss")
							.font(.subheadline)
					}
				}
			}
			.padding(.top, 40)
		}
		.padding()
	}
}

// MARK: - Slide to Call Button

struct SlideToCallButton: View {
	let phoneNumber: String
	var onDismiss: (() -> Void)?

	@State private var dragOffset: CGFloat = 0
	@State private var isDragging = false

	private let buttonHeight: CGFloat = 56
	private let thumbSize: CGFloat = 48
	private let padding: CGFloat = 4

	var body: some View {
		GeometryReader { geometry in
			let maxDragOffset = geometry.size.width - thumbSize - (padding * 2)
			let dragProgress = min(dragOffset / maxDragOffset, 1.0)

			ZStack(alignment: .leading) {
				// Background
				RoundedRectangle(cornerRadius: 28)
					.fill(Color.red)

				// Label
				Text("Slide to Call")
					.font(.headline)
					.foregroundStyle(.white.opacity(1 - dragProgress))
					.frame(maxWidth: .infinity)

				// Draggable Thumb
				Circle()
					.fill(.white)
					.frame(width: thumbSize, height: thumbSize)
					.overlay {
						Image(systemName: "phone.fill")
							.foregroundStyle(.red)
							.font(.title3)
					}
					.padding(padding)
					.offset(x: dragOffset)
					.gesture(
						DragGesture()
							.onChanged { value in
								isDragging = true
								dragOffset = min(max(0, value.translation.width), maxDragOffset)
							}
							.onEnded { _ in
								isDragging = false
								if dragProgress >= 0.8 {
									onDismiss?()
									initiateCall()
								}
								withAnimation(.spring(response: 0.3)) {
									dragOffset = 0
								}
							}
					)
			}
		}
		.frame(height: buttonHeight)
	}

	private func initiateCall() {
		guard let url = URL(string: "tel://\(phoneNumber)") else { return }
		UIApplication.shared.open(url)
	}
}

#Preview {
	DetectionView(notificationId: "preview-id", phoneNumber: "911")
}

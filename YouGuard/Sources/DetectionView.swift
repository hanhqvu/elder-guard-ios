//
//  DetectionView.swift
//  ElderGuard
//
//  Created by Hanh Vu on 2025/11/29.
//

import SwiftUI

struct DetectionView: View {
	let notificationId: String
	let phoneNumber: String
	var onDismiss: (() -> Void)?

	@State private var isAudioEnabled = false

	var body: some View {
		VStack {
			// Livestream Video
			WebRTCStreamView()
				.frame(height: 250)

			// Buttons
			VStack(spacing: 60) {
				// Audio Button
				Button {
					withAnimation(.easeInOut(duration: 0.3)) {
						isAudioEnabled.toggle()
					}
				} label: {
					VStack(spacing: 8) {
						Circle()
							.fill(isAudioEnabled ? Color.green : Color.gray)
							.frame(width: 64, height: 64)
							.overlay {
								Image(systemName: isAudioEnabled ? "mic.fill" : "mic.slash.fill")
									.font(.system(size: 28))
									.foregroundStyle(.white)
							}
							.opacity(isAudioEnabled ? 1.0 : 0.6)
					}
				}

				// Slide to Call Button
				SlideToCallButton(phoneNumber: phoneNumber)

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
						Text("Đóng")
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
				Text("Vuốt sang phải để gọi")
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
	DetectionView(notificationId: "preview-id", phoneNumber: "115")
}

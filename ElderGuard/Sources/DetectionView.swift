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

	var body: some View {
		VStack(spacing: 40) {
			Spacer()

			// Warning Icon
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.system(size: 120))
				.foregroundStyle(.yellow)

			Spacer()

			// Buttons
			VStack(spacing: 20) {
				// Dismiss Button
				Button {
					Task {
						try? await DetectionNotificationRepository.shared.markAsViewed(id: notificationId)
						onDismiss?()
					}
				} label: {
					Text("Tap to Dismiss")
						.font(.headline)
						.foregroundStyle(.white)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 16)
						.background(Color.gray.opacity(0.6))
						.clipShape(RoundedRectangle(cornerRadius: 12))
				}

				// Slide to Call Button
				SlideToCallButton(phoneNumber: phoneNumber, onDismiss: onDismiss)
			}
			.padding(.horizontal, 32)
			.padding(.bottom, 60)
		}
		.background(Color.black.opacity(0.9))
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

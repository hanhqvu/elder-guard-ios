//
//  HomeView.swift
//  ElderGuard
//
//  Created by Hanh Vu on 2025/11/29.
//

import AVKit
import SwiftUI

struct HomeView: View {
	@State private var unviewedNotification: DetectionNotification?

	private let emergencyPhoneNumber = "911"

	var body: some View {
		VStack {
			HLSVideoPlayer()
				.frame(height: 250)
				.clipShape(RoundedRectangle(cornerRadius: 12))
				.padding()

			Spacer()
		}
		.task {
			await fetchNotifications()
		}
		.sheet(item: $unviewedNotification) { notification in
			DetectionView(
				notificationId: notification.id,
				phoneNumber: emergencyPhoneNumber,
				onDismiss: {
					unviewedNotification = nil
				}
			)
			.interactiveDismissDisabled()
		}
	}

	private func fetchNotifications() async {
		do {
			let notifications = try await DetectionNotificationRepository.shared.getNotifications()
			unviewedNotification = notifications.first { !$0.isRead }
		} catch {
			print("Failed to fetch notifications: \(error)")
		}
	}
}

// MARK: - HLS Video Player

struct HLSVideoPlayer: UIViewControllerRepresentable {
	private let hlsStreamURL = URL(string: "https://example.com/stream.m3u8")!

	func makeUIViewController(context _: Context) -> AVPlayerViewController {
		let player = AVPlayer(url: hlsStreamURL)
		let controller = AVPlayerViewController()
		controller.player = player
		controller.showsPlaybackControls = true
		player.play()
		return controller
	}

	func updateUIViewController(_: AVPlayerViewController, context _: Context) {}
}

#Preview {
	HomeView()
}

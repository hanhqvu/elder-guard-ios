//
//  HomeView.swift
//  ElderGuard
//
//  Created by Hanh Vu on 2025/11/29.
//

import SwiftUI

struct HomeView: View {
	@State private var unviewedNotification: DetectionNotification?

	private let emergencyPhoneNumber = "911"

	var body: some View {
		Text("Hello, World!")
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

#Preview {
	HomeView()
}

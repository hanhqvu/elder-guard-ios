import SwiftUI

enum AppTab: String {
	case home
	case alert
	case activity
}

struct TabNavigationView: View {
	@State private var selectedTab: AppTab = .home
	@State private var unviewedNotification: DetectionNotification?

	@Environment(\.scenePhase) private var scenePhase

	private let emergencyPhoneNumber = "115"

	var body: some View {
		TabView(selection: $selectedTab) {
			Tab("Cảnh báo", systemImage: "bell.fill", value: .alert) {
				AlertListView()
			}

			Tab("Trang chủ", systemImage: "house.fill", value: .home) {
				HomeView()
			}

			Tab("Hoạt động", systemImage: "list.bullet", value: .activity) {
				ActivityView()
			}
		}
		.tint(.purple)
		.task {
			await fetchNotifications()
		}
		.onChange(of: scenePhase) { _, newPhase in
			switch newPhase {
				case .active:
					Task {
						await fetchNotifications()
					}
					WebRTCConnectionManager.shared.handleForeground()
				case .background:
					WebRTCConnectionManager.shared.handleBackground()
				case .inactive:
					break
				@unknown default:
					break
			}
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
	TabNavigationView()
}

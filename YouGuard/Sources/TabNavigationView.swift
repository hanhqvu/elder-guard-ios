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
			Tab("Alert", systemImage: "bell.fill", value: .alert) {
				AlertListView()
			}

			Tab("Home", systemImage: "house.fill", value: .home) {
				HomeView()
			}

			Tab("Activity", systemImage: "list.bullet", value: .activity) {
				ActivityView()
			}
		}
		.task {
			await fetchNotifications()
		}
		.onChange(of: scenePhase) { _, newPhase in
			if newPhase == .active {
				Task {
					await fetchNotifications()
				}
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

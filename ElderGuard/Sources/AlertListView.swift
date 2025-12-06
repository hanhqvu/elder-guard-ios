import SwiftUI

struct AlertListView: View {
	@State private var notifications: [DetectionNotification] = []
	@State private var isLoading = false
	@State private var errorMessage: String?
	@State private var isShowingAll = false

	private let emergencyPhoneNumber = "911"

	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				if isLoading {
					loadingView
				} else if errorMessage != nil {
					emptyStateView
				} else if filteredNotifications.isEmpty {
					emptyStateView
				} else {
					notificationsList
				}
			}
			.navigationTitle("Alert")
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					HStack(spacing: 4) {
						if isShowingAll {
							Text("Filtered by: All")
								.font(.subheadline)
						}

						Button {
							isShowingAll.toggle()
						} label: {
							Image(systemName:
								isShowingAll ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
						}
					}
				}
			}
			.refreshable {
				await fetchNotifications(forceRefresh: true)
			}
			.task {
				await fetchNotifications()
			}
		}
	}

	private var filteredNotifications: [DetectionNotification] {
		let filtered = isShowingAll
			? notifications.filter { !$0.view }
			: notifications

		return filtered.sorted { $0.timestamp > $1.timestamp }
	}

	private var notificationsList: some View {
		List {
			ForEach(filteredNotifications) { notification in
				NavigationLink {
					DetectionView(
						notificationId: notification.id,
						phoneNumber: emergencyPhoneNumber,
						onDismiss: {
							Task {
								await fetchNotifications(forceRefresh: true)
							}
						}
					)
				} label: {
					NotificationRow(notification: notification)
				}
			}
		}
		.listStyle(.plain)
	}

	private var loadingView: some View {
		VStack {
			Spacer()
			ProgressView("Loading alert...")
			Spacer()
		}
	}

	private var emptyStateView: some View {
		VStack {
			Spacer()
			Spacer()
		}
	}

	private func fetchNotifications(forceRefresh: Bool = false) async {
		isLoading = true
		errorMessage = nil

		do {
			let fetchedNotifications = try await DetectionNotificationRepository.shared
				.getNotifications(forceRefresh: forceRefresh)
			notifications = fetchedNotifications
		} catch {
			errorMessage = error.localizedDescription
		}

		isLoading = false
	}
}

struct NotificationRow: View {
	let notification: DetectionNotification

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			Image(systemName: notificationIcon)
				.font(.system(size: 24))
				.foregroundStyle(notification.view ? Color.secondary : Color.red)
				.frame(width: 40)

			VStack(alignment: .leading, spacing: 4) {
				HStack {
					Text(notification.type.capitalized)
						.font(.headline)

					if !notification.view {
						Circle()
							.fill(.red)
							.frame(width: 8, height: 8)
					}
				}

				Text(formattedDate)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			Spacer()

			Image(systemName: "chevron.right")
				.font(.system(size: 14))
				.foregroundStyle(.secondary)
		}
		.padding(.vertical, 4)
	}

	private var notificationIcon: String {
		switch notification.type.lowercased() {
			case "fall":
				return "figure.fall"
			case "fire":
				return "flame.fill"
			case "intrusion":
				return "person.fill.xmark"
			default:
				return "exclamationmark.triangle.fill"
		}
	}

	private var formattedDate: String {
		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .full
		return formatter.localizedString(for: notification.timestamp, relativeTo: Date())
	}
}

#Preview {
	AlertListView()
}

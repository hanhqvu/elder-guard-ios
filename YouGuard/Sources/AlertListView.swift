import AVKit
import SwiftUI

struct VideoPlayerView: UIViewControllerRepresentable {
	let player: AVPlayer
	let autoplay: Bool

	func makeUIViewController(context _: Context) -> AVPlayerViewController {
		let controller = AVPlayerViewController()
		controller.player = player

		if autoplay {
			player.play()
		}

		return controller
	}

	func updateUIViewController(_: AVPlayerViewController, context _: Context) {}
}

struct AlertListView: View {
	@State private var notifications: [DetectionNotification] = []
	@State private var isLoading = false
	@State private var errorMessage: String?
	@State private var firstNotificationId: String?
	@State private var firstNotificationTapped = false

	private let emergencyPhoneNumber = "115"

	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				if isLoading {
					loadingView
				} else if notifications.isEmpty {
					emptyStateView
				} else {
					notificationsList
				}
			}
			.navigationTitle("Cảnh báo")
			.refreshable {
				await fetchNotifications(forceRefresh: true)
			}
			.onAppear {
				Task {
					await fetchNotifications()
				}
			}
			.alert("Lỗi", isPresented: .constant(errorMessage != nil && !notifications.isEmpty)) {
				Button("Đồng ý") {
					errorMessage = nil
				}
			} message: {
				if let errorMessage {
					Text(errorMessage)
				}
			}
		}
	}

	private var notificationsList: some View {
		let sortedNotifications = notifications.sorted { $0.timestamp > $1.timestamp }
		return List {
			ForEach(Array(sortedNotifications.enumerated()), id: \.element.id) { index, notification in
				NotificationRow(
					notification: notification,
					isFirstNotification: index == 0,
					firstNotificationTapped: firstNotificationTapped,
					onTap: {
						if index == 0 {
							firstNotificationTapped = true
						}
					}
				)
			}
		}
		.listStyle(.plain)
	}

	private var loadingView: some View {
		VStack {
			Spacer()
			ProgressView("Đang tải cảnh báo...")
			Spacer()
		}
	}

	private var emptyStateView: some View {
		VStack(spacing: 16) {
			Spacer()

			if let errorMessage {
				Image(systemName: "exclamationmark.triangle.fill")
					.font(.system(size: 48))
					.foregroundStyle(.secondary)

				Text("Lỗi khi tải cảnh báo")
					.font(.headline)

				Text(errorMessage)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal)
			} else {
				Image(systemName: "bell.slash.fill")
					.font(.system(size: 48))
					.foregroundStyle(.secondary)

				Text("Không có cảnh báo")
					.font(.headline)
			}

			Spacer()
		}
	}

	private func fetchNotifications(forceRefresh: Bool = false) async {
		errorMessage = nil

		// Only show loading indicator for initial load, not for pull-to-refresh
		let shouldShowLoading = !forceRefresh
		var loadingTask: Task<Void, Never>?

		if shouldShowLoading {
			// Delay showing loading indicator by 300ms to avoid flicker
			loadingTask = Task {
				try? await Task.sleep(nanoseconds: 300_000_000)
				if !Task.isCancelled {
					isLoading = true
				}
			}
		}

		do {
			let fetchedNotifications = try await DetectionNotificationRepository.shared
				.getNotifications(forceRefresh: forceRefresh)

			// Reset firstNotificationTapped if the first notification changed
			let newFirstId = fetchedNotifications.sorted { $0.timestamp > $1.timestamp }.first?.id
			if firstNotificationId != newFirstId {
				firstNotificationId = newFirstId
				firstNotificationTapped = false
			}

			notifications = fetchedNotifications
		} catch {
			errorMessage = error.localizedDescription
		}

		// Cancel loading indicator task and hide loading
		loadingTask?.cancel()
		if shouldShowLoading {
			isLoading = false
		}
	}
}

struct NotificationRow: View {
	let notification: DetectionNotification
	let isFirstNotification: Bool
	let firstNotificationTapped: Bool
	let onTap: () -> Void
	@State private var showVideo = false

	var body: some View {
		Button {
			onTap()
			showVideo = true
		} label: {
			HStack(alignment: .top, spacing: 12) {
				Image(systemName: notificationIcon)
					.font(.system(size: 24))
					.foregroundStyle((isFirstNotification && !firstNotificationTapped) ? Color.red : Color.secondary)
					.frame(width: 40)

				VStack(alignment: .leading, spacing: 4) {
					HStack {
						Text("Phát hiện ngã")
							.font(.headline)
							.foregroundStyle((isFirstNotification && !firstNotificationTapped) ? Color.red : Color.primary)

						if isFirstNotification && !firstNotificationTapped {
							Circle()
								.fill(.red)
								.frame(width: 8, height: 8)
						}
					}

					Text(formattedDate)
						.font(.subheadline)
						.foregroundStyle((isFirstNotification && !firstNotificationTapped) ? Color.red : Color.secondary)
				}

				Spacer()

				Image(systemName: "play.circle.fill")
					.font(.system(size: 24))
					.foregroundStyle((isFirstNotification && !firstNotificationTapped) ? Color.red : Color.purple)
			}
			.padding(.vertical, 8)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.fullScreenCover(isPresented: $showVideo) {
			VideoPlayerView(
				player: AVPlayer(url: VideoRepository.shared.getVideoURL(for: notification.eventUUID)),
				autoplay: true
			)
			.ignoresSafeArea()
		}
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

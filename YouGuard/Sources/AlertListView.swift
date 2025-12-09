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

	private let emergencyPhoneNumber = "911"

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
			.navigationTitle("Alert")
			.refreshable {
				await fetchNotifications(forceRefresh: true)
			}
			.onAppear {
				Task {
					await fetchNotifications()
				}
			}
			.alert("Error", isPresented: .constant(errorMessage != nil && !notifications.isEmpty)) {
				Button("OK") {
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
		List {
			ForEach(notifications.sorted { $0.timestamp > $1.timestamp }) { notification in
				NotificationRow(notification: notification)
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
		VStack(spacing: 16) {
			Spacer()

			if let errorMessage {
				Image(systemName: "exclamationmark.triangle.fill")
					.font(.system(size: 48))
					.foregroundStyle(.secondary)

				Text("Error Loading Alerts")
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

				Text("No Alerts")
					.font(.headline)

				Text("You're all caught up!")
					.font(.subheadline)
					.foregroundStyle(.secondary)
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
	@State private var showVideo = false

	var body: some View {
		Button {
			showVideo = true
		} label: {
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

				Image(systemName: "play.circle.fill")
					.font(.system(size: 24))
					.foregroundStyle(.blue)
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

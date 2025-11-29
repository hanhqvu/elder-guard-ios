import Foundation

final class DetectionNotificationRepository {
	static let shared = DetectionNotificationRepository()

	private let networkManager = NetworkManager.shared
	private let cache = CacheManager<String, [DetectionNotification]>(defaultTTL: 300)

	private let cacheKey = "notifications"

	private init() {}

	func getNotifications(forceRefresh: Bool = false) async throws -> [DetectionNotification] {
		if !forceRefresh, let cached = cache.get(cacheKey) {
			return cached
		}

		let notifications = try await networkManager.fetch(
			[DetectionNotification].self,
			from: "notifications"
		)

		cache.set(notifications, forKey: cacheKey)

		return notifications
	}

	func clearCache() {
		cache.remove(cacheKey)
	}

	func markAsViewed(id: String) async throws {
		// Call API to update view status
		try await networkManager.update(
			path: "notifications/\(id)",
			body: ["view": true]
		)

		// Update local cache
		if var cached = cache.get(cacheKey) {
			if let index = cached.firstIndex(where: { $0.id == id }) {
				var notification = cached[index]
				notification = DetectionNotification(
					id: notification.id,
					time: notification.time,
					type: notification.type,
					view: true
				)
				cached[index] = notification
				cache.set(cached, forKey: cacheKey)
			}
		}
	}
}

import Foundation

struct DetectionNotification: Codable, Identifiable, Equatable {
	let id: String
	let time: Date
	let type: String
	let view: Bool

	var isRead: Bool { view }
}

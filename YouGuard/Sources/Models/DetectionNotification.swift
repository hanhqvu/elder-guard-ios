import Foundation

struct DetectionNotification: Codable, Identifiable, Equatable {
	let id: String
	let time: String
	let type: String
	let view: Bool
	let eventUUID: String

	var isRead: Bool { view }
	var timestamp: Date { Self.parseDate(time) }
}

extension DetectionNotification {
	private static func parseDate(_ dateString: String) -> Date {
		var dateString = dateString
		if !dateString.hasSuffix("Z"), !dateString.contains("+") {
			dateString += "Z"
		}

		let iso8601Formatter = ISO8601DateFormatter()
		iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		if let date = iso8601Formatter.date(from: dateString) {
			return date
		}

		iso8601Formatter.formatOptions = [.withInternetDateTime]
		return iso8601Formatter.date(from: dateString) ?? Date()
	}

	private enum CodingKeys: String, CodingKey {
		case id, time, type, view
		case eventUUID = "event_uuid"
	}
}

import Foundation

final class VideoRepository {
	static let shared = VideoRepository()

	private init() {}

	/// Builds the video URL for a given event ID
	func getVideoURL(for eventUUID: String) -> URL {
		AppEnvironment.current.videoBaseURL
			.appendingPathComponent("videos")
			.appendingPathComponent(eventUUID)
	}
}

import Foundation

// MARK: - Environment Configuration

enum AppEnvironment: String {
	case development
	case production

	var baseURL: URL {
		switch self {
			case .development:
				return URL(string: "http://localhost:8080/api")!
			case .production:
				return URL(string: "https://api.elderguard.com/api")!
		}
	}

	static var current: AppEnvironment {
		#if DEBUG
			return .development
		#else
			return .production
		#endif
	}
}

// MARK: - Network Errors

enum NetworkError: Error {
	case invalidURL
	case invalidResponse
	case httpError(statusCode: Int)
	case decodingError(Error)
	case unknown(Error)
}

// MARK: - Network Manager

final class NetworkManager {
	static let shared = NetworkManager()

	private let session: URLSession
	private let decoder: JSONDecoder

	private init() {
		let config = URLSessionConfiguration.default
		config.timeoutIntervalForRequest = 30
		session = URLSession(configuration: config)
		decoder = JSONDecoder()
	}

	func fetch<T: Decodable>(_: T.Type, from path: String) async throws -> T {
		let url = AppEnvironment.current.baseURL.appendingPathComponent(path)

		let (data, response) = try await session.data(from: url)

		guard let httpResponse = response as? HTTPURLResponse else {
			throw NetworkError.invalidResponse
		}

		guard (200 ... 299).contains(httpResponse.statusCode) else {
			throw NetworkError.httpError(statusCode: httpResponse.statusCode)
		}

		do {
			return try decoder.decode(T.self, from: data)
		} catch {
			throw NetworkError.decodingError(error)
		}
	}

	func update(path: String, body: [String: Any]? = nil) async throws {
		let url = AppEnvironment.current.baseURL.appendingPathComponent(path)

		var request = URLRequest(url: url)
		request.httpMethod = "PATCH"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")

		if let body {
			request.httpBody = try JSONSerialization.data(withJSONObject: body)
		}

		let (_, response) = try await session.data(for: request)

		guard let httpResponse = response as? HTTPURLResponse else {
			throw NetworkError.invalidResponse
		}

		guard (200 ... 299).contains(httpResponse.statusCode) else {
			throw NetworkError.httpError(statusCode: httpResponse.statusCode)
		}
	}
}

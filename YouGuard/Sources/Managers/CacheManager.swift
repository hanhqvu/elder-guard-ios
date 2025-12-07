import Foundation

// MARK: - Cache Entry Wrapper

private final class CacheEntry<T> {
	let value: T
	let expirationDate: Date

	init(value: T, ttl: TimeInterval) {
		self.value = value
		expirationDate = Date().addingTimeInterval(ttl)
	}

	var isExpired: Bool {
		Date() > expirationDate
	}
}

// MARK: - Cache Manager

final class CacheManager<Key: Hashable, Value> {
	private let cache = NSCache<WrappedKey, CacheEntry<Value>>()
	private let defaultTTL: TimeInterval

	init(defaultTTL: TimeInterval = 300) {
		self.defaultTTL = defaultTTL
	}

	func get(_ key: Key) -> Value? {
		guard let entry = cache.object(forKey: WrappedKey(key)) else {
			return nil
		}

		if entry.isExpired {
			cache.removeObject(forKey: WrappedKey(key))
			return nil
		}

		return entry.value
	}

	func set(_ value: Value, forKey key: Key, ttl: TimeInterval? = nil) {
		let entry = CacheEntry(value: value, ttl: ttl ?? defaultTTL)
		cache.setObject(entry, forKey: WrappedKey(key))
	}

	func remove(_ key: Key) {
		cache.removeObject(forKey: WrappedKey(key))
	}

	func clear() {
		cache.removeAllObjects()
	}

	// NSCache requires NSObject keys
	private final class WrappedKey: NSObject {
		let key: Key

		init(_ key: Key) {
			self.key = key
		}

		override var hash: Int {
			key.hashValue
		}

		override func isEqual(_ object: Any?) -> Bool {
			guard let other = object as? WrappedKey else { return false }
			return key == other.key
		}
	}
}

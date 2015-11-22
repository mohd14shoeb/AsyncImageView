//
//  TypedCache.swift
//  ChessWatchApp
//
//  Created by Nacho Soto on 9/17/15.
//  Copyright © 2015 Javier Soto. All rights reserved.
//

import Foundation

internal class TypedCache<K: Hashable, V: NSObject> {
	private let cache: NSCache

	init(cacheName: String) {
		self.cache = {
			let cache = NSCache()
			cache.name = cacheName

			return cache
		}()
	}

	func objectForKey(key: K) -> V? {
		return cache.objectForKey(CacheKey(value: key)) as! V?
	}

	func setObject(object: V, forKey key: K) {
		cache.setObject(object, forKey: CacheKey(value: key))
	}
}

private final class CacheKey<K: Hashable>: NSObject {
	private let value: K
	private let cachedHash: Int

	init(value: K) {
		self.value = value
		self.cachedHash = value.hashValue

		super.init()
	}

	private override func isEqual(object: AnyObject?) -> Bool {
		if let otherData = object as? CacheKey<K> {
			return otherData.value == self.value
		} else {
			return false
		}
	}

	private override var hash: Int {
		return self.cachedHash
	}
}
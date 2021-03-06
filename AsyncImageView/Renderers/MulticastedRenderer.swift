//
//  MulticastedRenderer.swift
//  AsyncImageView
//
//  Created by Nacho Soto on 11/27/15.
//  Copyright © 2015 Nacho Soto. All rights reserved.
//

import UIKit

import ReactiveCocoa
import Result

// The initial value is `nil`.
private typealias ImageProperty = AnyProperty<ImageResult?>

/// `RendererType` decorator which guarantees that images for a given `RenderDataType`
/// are only rendered once, and multicasted to every observer.
public final class MulticastedRenderer<
	Data: RenderDataType,
	Renderer: RendererType
	where
	Renderer.Data == Data,
	Renderer.Error == NoError
>: RendererType {
	private let renderer: Renderer
	private let cache: Atomic<[Data : ImageProperty]>

	private let memoryWarningDisposable: Disposable

	public init(renderer: Renderer) {
		self.renderer = renderer
		self.cache = Atomic([:])

		self.memoryWarningDisposable = MulticastedRenderer.clearCacheOnMemoryWarning(self.cache)
	}

	deinit {
		self.memoryWarningDisposable.dispose()
	}

	public func renderImageWithData(data: Data) -> SignalProducer<ImageResult, NoError> {
		let property = getPropertyForData(data)

		return property.producer
			.filter { $0 != nil } // Skip initial `nil` value.
			.map { $0! }
			.take(1)
 	}

	private func getPropertyForData(data: Data) -> ImageProperty {
		var result: ImageProperty!

		self.cache.modify { cache in
			var mutableCache = cache

			if let property = cache[data] {
				result = property
				return cache
			}

			result = ImageProperty(
				initialValue: nil,
				producer: renderer.createProducerForRenderingData(data)
					.map(Optional.init)
			)

			mutableCache[data] = result
			return mutableCache
		}

		return result
	}

	private static func clearCacheOnMemoryWarning(cache: Atomic<[Data : ImageProperty]>) -> Disposable {
		return NSNotificationCenter.defaultCenter()
			.rac_notifications(UIApplicationDidReceiveMemoryWarningNotification, object: nil)
			.observeOn(QueueScheduler())
			.startWithNext { _ in
				cache.modify { _ in [:] }
			}
	}
}

extension RendererType where Error == NoError {
	/// Multicasts the results of this `RendererType`.
	public func multicasted() -> MulticastedRenderer<Self.Data, Self> {
		return MulticastedRenderer(renderer: self)
	}
}

extension RendererType {
	private func createProducerForRenderingData(data: Data) -> SignalProducer<ImageResult, Error> {
		return self.renderImageWithData(data)
			.flatMap(.Concat) { result in
				return SignalProducer(values: [
					ImageResult(image: result.image, cacheHit: false),
					ImageResult(image: result.image, cacheHit: true)
				])
		}
	}
}

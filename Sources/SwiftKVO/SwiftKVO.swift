//
//  SwiftKVO.swift
//  SwiftKVO
//
//  Created by William Kent on 5/19/19.
//  Copyright © 2019 William Kent. All rights reserved.
//

import Foundation

public final class SwiftKVO {
	private init() {
		// This class should not be initialized.
	}

	internal typealias ObserverToken = UInt
	internal typealias ProxyData = (options: Set<ChangeType>, callbackHolder: AnyObject)

	public enum ChangeType {
		case beforeChange
		case afterChange
		case initial
	}

	public final class Observer {
		internal init(callback: @escaping () -> Void) {
			self.callback = callback
		}

		deinit {
			cancel()
		}

		private var callback: () -> Void

		public func cancel() {
			callback()
		}
	}

	public final class Proxy<TObject: AnyObject> {
		private final class CallbackHolder<TProperty> {
			internal typealias Callback = (ChangeType, TProperty) -> Void

			internal init(_ callback: @escaping Callback) {
				self.callback = callback
			}

			public var callback: Callback
		}

		public init() {}

		public weak var owner: TObject? {
			willSet {
				if self.owner != nil {
					fatalError("KVO.Proxy.owner can only be set once")
				}
			}
		}

		private var cache = [AnyKeyPath: [ObserverToken: ProxyData]]()
		private var nextId: ObserverToken = 0

		private func getCachedValue(keyPath: AnyKeyPath, id: ObserverToken) -> ProxyData? {
			if cache[keyPath] == nil {
				cache[keyPath] = [:]
			}

			return cache[keyPath]![id]
		}

		private func setCachedValue(keyPath: AnyKeyPath, id: ObserverToken, value: ProxyData) {
			if cache[keyPath] == nil {
				cache[keyPath] = [:]
			}

			cache[keyPath]![id] = value
		}

		public func addObserver<TProperty>(keyPath: KeyPath<TObject, TProperty>, options: Set<ChangeType>, callback: @escaping (ChangeType, TProperty) -> Void) -> Observer {
			guard let owner = owner else {
				fatalError("owner died before its KVO.Proxy did")
			}

			nextId += 1
			let id = nextId

			let holder = CallbackHolder(callback)
			setCachedValue(keyPath: keyPath, id: id, value: (options, holder))

			if options.contains(.initial) {
				callback(.initial, owner[keyPath: keyPath])
			}

			return Observer {
				[weak self] in
				self?.cache[keyPath]?.removeValue(forKey: id)
			}
		}

		public func willChangeValue<TProperty>(keyPath: KeyPath<TObject, TProperty>) {
			guard let owner = owner else {
				fatalError("owner died before its KVO.Proxy did")
			}

			if let cacheDict = cache[keyPath] {
				let value = owner[keyPath: keyPath]
				for (_, proxyData) in cacheDict {
					let (options, callbackHolder) = proxyData

					if options.contains(.beforeChange) {
						guard let typedHolder = callbackHolder as? CallbackHolder<TProperty> else {
							fatalError("callback type mismatch")
						}
						typedHolder.callback(.beforeChange, value)
					}
				}
			}
		}

		public func didChangeValue<TProperty>(keyPath: KeyPath<TObject, TProperty>) {
			guard let owner = owner else {
				fatalError("owner died before its KVO.Proxy did")
			}

			if let cacheDict = cache[keyPath] {
				let value = owner[keyPath: keyPath]
				for (_, proxyData) in cacheDict {
					let (options, callbackHolder) = proxyData

					if options.contains(.afterChange) {
						guard let typedHolder = callbackHolder as? CallbackHolder<TProperty> else {
							fatalError("callback type mismatch")
						}
						typedHolder.callback(.afterChange, value)
					}
				}
			}
		}
	}
}

// Copyright (c) 2019 William Kent
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

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

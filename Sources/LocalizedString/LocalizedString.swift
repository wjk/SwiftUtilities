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

public func localize(_ string: LocalizedStringBuilder, table: String? = nil, bundle: Bundle? = nil) -> String {
	return string.resolve(tableName: table, bundle: bundle)
}

public struct LocalizedStringBuilder: ExpressibleByStringInterpolation {
	public typealias StringLiteralType = String
	fileprivate typealias InterpolatedValueProvider = () -> CVarArg

	private let key: String
	private let valueProviders: [InterpolatedValueProvider]

	public init(stringLiteral: String) {
		self.key = stringLiteral
		self.valueProviders = []
	}

	public init(stringInterpolation: StringInterpolation) {
		self.key = stringInterpolation.key
		self.valueProviders = stringInterpolation.providers
	}

	public func resolve(tableName table: String? = nil, bundle: Bundle? = nil) -> String {
		let bundle = bundle ?? Bundle.main

		if valueProviders.count > 0 {
			let arguments = valueProviders.map { provider in provider() }
			let format = bundle.localizedString(forKey: self.key, value: nil, table: table)
			return String(format: format, arguments: arguments)
		} else {
			return bundle.localizedString(forKey: self.key, value: nil, table: table)
		}
	}

	public struct StringInterpolation: StringInterpolationProtocol {
		public typealias StringLiteralType = String

		fileprivate var key = ""
		fileprivate var providers: [InterpolatedValueProvider] = []

		public init(literalCapacity: Int, interpolationCount: Int) {
		}

		public mutating func appendLiteral(_ literal: String) {
			key += literal
		}

		public mutating func appendInterpolation(_ value: String) {
			key += "%@"
			providers.append { value as NSString }
		}

		public mutating func appendInterpolation<Subject: CustomStringConvertible>(_ object: Subject) {
			key += "%@"
			providers.append { object.description as NSString }
		}

		public mutating func appendInterpolation<Subject>(_ object: Subject, formatter: Formatter) {
			key += "%@"
			providers.append {
				guard let string = formatter.string(for: object) else {
					fatalError("Could not convert object to string")
				}
				return string as NSString
			}
		}

		public mutating func appendInterpolation(value: Int) {
			key += "%ld"
			providers.append { value }
		}
	}
}

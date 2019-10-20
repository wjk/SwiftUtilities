//
//  LocalizedString.swift
//  LocalizedString
//
//  Created by William Kent on 6/21/19.
//  Copyright © 2019 William Kent. All rights reserved.
//

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

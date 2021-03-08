//
//  NotImplementedError.swift
//  CommonUI
//
//  Created by William Kent on 8/23/20.
//  Copyright © 2020 William Kent. All rights reserved.
//

import Foundation
import LocalizedString

public enum NotImplementedError: LocalizedError {
	case generic
	case specific(String)

	public var errorDescription: String? {
		localize("This feature is not implemented.", bundle: Bundle.module)
	}

	public var failureReason: String? {
		switch self {
		case .generic: return nil
		case .specific(let reason): return reason
		}
	}
}

public enum UnexpectedFailureError: LocalizedError {
	case generic
	case specific(String)

	public var errorDescription: String? {
		localize("An internal failure has occurred.", bundle: Bundle.module)
	}

	// This is not guaranteed to be localized.
	public var failureReason: String? {
		switch self {
		case .generic: return nil
		case .specific(let reason): return reason
		}
	}
}

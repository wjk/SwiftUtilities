//
// This file is based on SwiftPrivilegedHelper.
// Copyright (c) 2018 Erik Berglund
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
//

import Foundation
import Security

let kSecCSDefaultFlags = 0

enum CodesignCheckError: LocalizedError {
    case status(OSStatus)
    case message(String)

    var failureReason: String? {
        switch self {
        case .message(let message):
            return message
        case .status(let status):
            if let cfString = SecCopyErrorMessageString(status, nil) {
                return cfString as String
            } else {
                return "Error \(status) (SecCopyErrorMessageString failure)"
            }
        }
    }
}

public enum CodesignCheck {
    public static func codeSigningMatches(pid: pid_t) throws -> Bool {
        return try self.codeSigningCertificatesForSelf() == self.codeSigningCertificates(forPID: pid)
    }

    // MARK: Public Functions

    public static func codeSigningCertificatesForSelf() throws -> [SecCertificate] {
        guard let secStaticCode = try secStaticCodeSelf() else { return [] }
        return try codeSigningCertificates(forStaticCode: secStaticCode)
    }

    public static func codeSigningCertificates(forPID pid: pid_t) throws -> [SecCertificate] {
        guard let secStaticCode = try secStaticCode(forPID: pid) else { return [] }
        return try codeSigningCertificates(forStaticCode: secStaticCode)
    }

    public static func codeSigningCertificates(forURL url: URL) throws -> [SecCertificate] {
        guard let secStaticCode = try secStaticCode(forURL: url) else { return [] }
        return try codeSigningCertificates(forStaticCode: secStaticCode)
    }

    // MARK: Private Functions

    private static func executeSecFunction(_ secFunction: () -> (OSStatus) ) throws {
        let osStatus = secFunction()
        guard osStatus == errSecSuccess else {
            throw CodesignCheckError.status(osStatus)
        }
    }

    private static func secStaticCodeSelf() throws -> SecStaticCode? {
        var secCodeSelf: SecCode?
        try executeSecFunction { SecCodeCopySelf(SecCSFlags(rawValue: 0), &secCodeSelf) }
        guard let secCode = secCodeSelf else {
            throw CodesignCheckError.message("SecCode returned empty from SecCodeCopySelf")
        }
        return try secStaticCode(forSecCode: secCode)
    }

    private static func secStaticCode(forPID pid: pid_t) throws -> SecStaticCode? {
        var secCodePID: SecCode?
        try executeSecFunction { SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &secCodePID) }
        guard let secCode = secCodePID else {
            throw CodesignCheckError.message("SecCode returned empty from SecCodeCopyGuestWithAttributes")
        }
        return try secStaticCode(forSecCode: secCode)
    }

    private static func secStaticCode(forURL url: URL) throws -> SecStaticCode? {
        var secStaticCodePath: SecStaticCode?
        try executeSecFunction { SecStaticCodeCreateWithPath(url as CFURL, [], &secStaticCodePath) }
        guard let secStaticCode = secStaticCodePath else {
            throw CodesignCheckError.message("SecStaticCode returned empty from SecStaticCodeCreateWithPath")
        }
        return secStaticCode
    }

    private static func secStaticCode(forSecCode secCode: SecCode) throws -> SecStaticCode? {
        var secStaticCodeCopy: SecStaticCode?
        try executeSecFunction { SecCodeCopyStaticCode(secCode, [], &secStaticCodeCopy) }
        guard let secStaticCode = secStaticCodeCopy else {
            throw CodesignCheckError.message("SecStaticCode returned empty from SecCodeCopyStaticCode")
        }
        return secStaticCode
    }

    private static func isValid(secStaticCode: SecStaticCode) throws {
        try executeSecFunction { SecStaticCodeCheckValidity(secStaticCode, SecCSFlags(rawValue: kSecCSDoNotValidateResources | kSecCSCheckNestedCode), nil) }
    }

    private static func secCodeInfo(forStaticCode secStaticCode: SecStaticCode) throws -> [String: Any]? {
        try isValid(secStaticCode: secStaticCode)
        var secCodeInfoCFDict:  CFDictionary?
        try executeSecFunction { SecCodeCopySigningInformation(secStaticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &secCodeInfoCFDict) }
        guard let secCodeInfo = secCodeInfoCFDict as? [String: Any] else {
            throw CodesignCheckError.message("CFDictionary returned empty from SecCodeCopySigningInformation")
        }
        return secCodeInfo
    }

    private static func codeSigningCertificates(forStaticCode secStaticCode: SecStaticCode) throws -> [SecCertificate] {
        guard
            let secCodeInfo = try secCodeInfo(forStaticCode: secStaticCode),
            let secCertificates = secCodeInfo[kSecCodeInfoCertificates as String] as? [SecCertificate] else { return [] }
        return secCertificates
    }
}

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

public struct AuthorizationRight {
    public enum RuleKeys {
        static let ruleClass = "class"
        static let group = "group"
        static let rule = "rule"
        static let timeout = "timeout"
        static let version = "version"
    }

    public enum RuleDefinition {
        case constant(name: String)
        case custom(definition: [String: Any])
    }

    public let name: String
    public let description: String
    public let ruleDefinition: RuleDefinition

    public init(name: String, description: String, ruleDefinition: RuleDefinition) {
        self.name = name
        self.description = description
        self.ruleDefinition = ruleDefinition
    }

    internal func rule() -> CFTypeRef {
        let rule: CFTypeRef

        switch self.ruleDefinition {
        case .constant(let name):
            rule = name as CFString
        case .custom(let definition):
            rule = definition as CFDictionary
        }

        return rule
    }

    public static let authenticateAsAdminRule: [String: Any] = [
        AuthorizationRight.RuleKeys.ruleClass: "user",
        AuthorizationRight.RuleKeys.group: "admin",
        AuthorizationRight.RuleKeys.version: 1
    ]
}

// MARK: -

public enum AuthorizationError: Error {
    case canceled
    case denied
    case message(String)
}

public enum Authorization {
    public static func authorizationRightsUpdateDatabase(rights: [AuthorizationRight], bundle: Bundle?, stringTableName: String?) throws {
        let cfBundle: CFBundle?
        let cfStringTableName: CFString?
        if let bundle = bundle, let bundleIdentifier = bundle.bundleIdentifier {
            cfBundle = CFBundleGetBundleWithIdentifier(bundleIdentifier as CFString)

            guard let stringTableName = stringTableName else {
                fatalError("A string table name must be specified if a bundle is")
            }

            cfStringTableName = stringTableName as CFString
        } else {
            cfBundle = nil
            cfStringTableName = nil
        }

        guard let authRef = try self.emptyAuthorizationRef() else {
            throw AuthorizationError.message("Failed to get empty authorization ref")
        }

        for authorizationRight in rights {
            var osStatus = errAuthorizationSuccess
            var currentRule: CFDictionary?

            osStatus = AuthorizationRightGet(authorizationRight.name, &currentRule)
            if osStatus == errAuthorizationDenied || self.authorizationRuleUpdateRequired(currentRule, authorizationRight: authorizationRight) {
                osStatus = AuthorizationRightSet(authRef, authorizationRight.name, authorizationRight.rule(), authorizationRight.description as CFString, cfBundle, cfStringTableName)
            }

            guard osStatus == errAuthorizationSuccess else {
                NSLog("AuthorizationRightSet or Get failed with error: \(String(describing: SecCopyErrorMessageString(osStatus, nil)))")
                continue
            }
        }
    }

    private static func authorizationRuleUpdateRequired(_ currentRuleCFDict: CFDictionary?, authorizationRight: AuthorizationRight) -> Bool {
        guard let currentRuleDict = currentRuleCFDict as? [String: Any] else {
            return true
        }

        let newRule = authorizationRight.rule()
        if CFGetTypeID(newRule) == CFStringGetTypeID() {
            if
                let currentRule = currentRuleDict[AuthorizationRight.RuleKeys.rule] as? [String] {
                switch authorizationRight.ruleDefinition {
                case .constant(let name):
                    return currentRule != [name]
                case .custom(_):
                    return true
                }
            }
        } else if CFGetTypeID(newRule) == CFDictionaryGetTypeID() {
            if let currentVersion = currentRuleDict[AuthorizationRight.RuleKeys.version] as? Int {
                switch authorizationRight.ruleDefinition {
                case .constant(_):
                    return true
                case .custom(let definition):
                    if let newVersion = definition[AuthorizationRight.RuleKeys.version] as? Int {
                        return currentVersion != newVersion
                    } else {
                        return true
                    }
                }
            }
        }

        return true
    }

    // MARK: Authorization Wrapper

    private static func executeAuthorizationFunction(_ authorizationFunction: () -> (OSStatus)) throws {
        let osStatus = authorizationFunction()
        guard osStatus == errAuthorizationSuccess else {
            if osStatus == errAuthorizationCanceled {
                throw AuthorizationError.canceled
            } else if osStatus == errAuthorizationDenied {
                throw AuthorizationError.denied
            } else {
                throw AuthorizationError.message(String(describing: SecCopyErrorMessageString(osStatus, nil)))
            }
        }
    }

    // MARK: AuthorizationRef

    public static func authorizationRef(_ rights: UnsafePointer<AuthorizationRights>?, _ environment: UnsafePointer<AuthorizationEnvironment>?, _ flags: AuthorizationFlags) throws -> AuthorizationRef? {
        var authRef: AuthorizationRef?
        try executeAuthorizationFunction { AuthorizationCreate(rights, environment, flags, &authRef) }
        return authRef
    }

    public static func authorizationRef(fromExternalForm data: NSData) throws -> AuthorizationRef? {
        // Create an AuthorizationExternalForm from it's data representation
        var authRef: AuthorizationRef?
        let authRefExtForm: UnsafeMutablePointer<AuthorizationExternalForm> = UnsafeMutablePointer.allocate(capacity: Int(kAuthorizationExternalFormLength) * MemoryLayout<AuthorizationExternalForm>.size)
        defer { authRefExtForm.deallocate() }
        memcpy(authRefExtForm, data.bytes, data.length)

        // Extract the AuthorizationRef from it's external form
        try executeAuthorizationFunction { AuthorizationCreateFromExternalForm(authRefExtForm, &authRef) }
        return authRef
    }

    // MARK: Empty Authorization Refs

    public static func emptyAuthorizationRef() throws -> AuthorizationRef? {
        var authRef: AuthorizationRef?

        // Create an empty AuthorizationRef
        try executeAuthorizationFunction { AuthorizationCreate(nil, nil, [], &authRef) }
        return authRef
    }

    public static func emptyAuthorizationExternalForm() throws -> AuthorizationExternalForm? {
        // Create an empty AuthorizationRef
        guard let authorizationRef = try self.emptyAuthorizationRef() else { return nil }

        // Make an external form of the AuthorizationRef
        var authRefExtForm = AuthorizationExternalForm()
        try executeAuthorizationFunction { AuthorizationMakeExternalForm(authorizationRef, &authRefExtForm) }
        return authRefExtForm
    }

    public static func emptyAuthorizationExternalFormData() throws -> NSData? {
        guard var authRefExtForm = try self.emptyAuthorizationExternalForm() else { return nil }

        // Encapsulate the external form AuthorizationRef in an NSData object
        return NSData(bytes: &authRefExtForm, length: Int(kAuthorizationExternalFormLength))
    }

    // MARK: Verification

    public static func verifyAuthorization(_ authExtData: NSData?, forAuthorizationRight authRight: AuthorizationRight, promptText: String?) throws {
        // Verify that the passed authExtData looks reasonable
        guard let authorizationExtData = authExtData, authorizationExtData.length == kAuthorizationExternalFormLength else {
            throw AuthorizationError.message("Invalid Authorization External Form Data")
        }

        // Convert the external form to an AuthorizationRef
        guard let authorizationRef = try self.authorizationRef(fromExternalForm: authorizationExtData) else {
            throw AuthorizationError.message("Failed to convert the Authorization External Form to an Authorization Reference")
        }

        // Verify the user has the right to run the passed command
        try self.verifyAuthorization(authorizationRef, forAuthorizationRight: authRight, promptText: promptText)
    }

    public static func verifyAuthorization(_ authRef: AuthorizationRef, forAuthorizationRight authRight: AuthorizationRight, promptText: String?) throws {
        // Get the authorization name in the correct format
        guard let authRightName = (authRight.name as NSString).utf8String else {
            throw AuthorizationError.message("Failed to convert authorization name to C string")
        }

        if let promptText = promptText {
            guard let promptCString = (promptText as NSString).utf8String else {
                throw AuthorizationError.message("Failed to convert prompt text to C string")
            }

            let promptCStringPtr = UnsafeMutableRawPointer(mutating: promptCString)
            var envItem = kAuthorizationEnvironmentPrompt.withCString { promptStr in
                AuthorizationItem(name: promptStr, valueLength: promptText.lengthOfBytes(using: .utf8), value: promptCStringPtr, flags: 0)
            }

            try withUnsafeMutablePointer(to: &envItem, { envItemPtr in
                var authEnvironment = AuthorizationEnvironment(count: 1, items: envItemPtr)

                // Create an AuthorizationItem using the authorization right name
                var authItem = AuthorizationItem(name: authRightName, valueLength: 0, value: UnsafeMutableRawPointer(bitPattern: 0), flags: 0)

                // Create the AuthorizationRights for using the AuthorizationItem
                try withUnsafeMutablePointer(to: &authItem) { authItemPtr in
                    var authRights = AuthorizationRights(count: 1, items: authItemPtr)

                    // Check if the user is authorized for the AuthorizationRights.
                    // If not the user might be asked for an admin credential.
                    try executeAuthorizationFunction { AuthorizationCopyRights(authRef, &authRights, &authEnvironment, [.extendRights, .interactionAllowed], nil) }
                }
            })
        } else {
            // Create an AuthorizationItem using the authorization right name
            var authItem = AuthorizationItem(name: authRightName, valueLength: 0, value: UnsafeMutableRawPointer(bitPattern: 0), flags: 0)

            // Create the AuthorizationRights for using the AuthorizationItem
            try withUnsafeMutablePointer(to: &authItem) { authItemPtr in
                var authRights = AuthorizationRights(count: 1, items: authItemPtr)

                // Check if the user is authorized for the AuthorizationRights.
                // If not the user might be asked for an admin credential.
                try executeAuthorizationFunction { AuthorizationCopyRights(authRef, &authRights, nil, [.extendRights, .interactionAllowed], nil) }
            }
        }
    }
}

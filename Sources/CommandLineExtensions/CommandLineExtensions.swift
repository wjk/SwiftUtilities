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

public final class _StandardErrorOutputStream: TextOutputStream {
    fileprivate init() {}

    public func write(_ string: String) {
        fputs(string, stderr)
    }
}

public final class _EnvironmentAccessor {
    fileprivate init() {}

    public subscript(name: String) -> String? {
        get {
            let buffer = name.withCString {
                nameBuffer in
                getenv(nameBuffer)
            }

            if let buffer = buffer {
                return String(cString: buffer)
            } else {
                return nil
            }
        }

        set {
            if let newValue = newValue {
                _ = name.withCString {
                    nameBuffer in
                    newValue.withCString {
                        valueBuffer in
                        setenv(nameBuffer, valueBuffer, 1)
                    }
                }
            } else {
                _ = name.withCString {
                    nameBuffer in
                    unsetenv(nameBuffer)
                }
            }
        }
    }
}

public extension CommandLine {
    static let standardError = _StandardErrorOutputStream()
    static let environment = _EnvironmentAccessor()

    static var workingDirectory: URL {
        get {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MAXPATHLEN) * MemoryLayout<UInt8>.stride)
            defer {
                buffer.deallocate()
            }

            getcwd(buffer, Int(MAXPATHLEN))
            let path = String(cString: buffer)
            return URL(fileURLWithPath: path)
        }

        set {
            precondition(newValue.isFileURL, "Working directory must be a file URL")
            _ = newValue.path.withCString {
                buffer in
                chdir(buffer)
            }
        }
    }
}

public extension FileManager {
    func directoryExists(atPath path: String) -> Bool {
        var isDir = ObjCBool(false)
        let exists = self.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    func fileExists(atPath path: String) -> Bool {
        var isDir = ObjCBool(false)
        let exists = self.fileExists(atPath: path, isDirectory: &isDir)
        return exists && !isDir.boolValue
    }
}

public func joinPathComponents(_ paths: String...) -> String {
    var accumulator = URL(fileURLWithPath: paths[0])
    for element in paths[1...] {
        accumulator = accumulator.appendingPathComponent(element)
    }
    return accumulator.path
}

public func joinPathComponents(_ paths: [String]) -> String {
    var accumulator = URL(fileURLWithPath: paths[0])
    for element in paths[1...] {
        accumulator = accumulator.appendingPathComponent(element)
    }
    return accumulator.path
}

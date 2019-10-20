import Foundation

public struct _StandardErrorOutputStream: TextOutputStream {
	fileprivate init() {}

	public mutating func write(_ string: String) {
		fputs(string, stderr)
	}
}

public struct _EnvironmentAccessor {
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
	static var standardError = _StandardErrorOutputStream()
	static let environment = _EnvironmentAccessor()

	static var workingDirectory: URL {
		get {
			let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(MAXPATHLEN) * MemoryLayout<Int8>.stride)
			defer {
				buffer.deallocate()
			}

			getcwd(buffer, Int(MAXPATHLEN))
			let path = String(cString: UnsafePointer<UInt8>(OpaquePointer(buffer)))
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

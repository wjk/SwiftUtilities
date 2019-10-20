// swift-tools-version:5.0
import PackageDescription

let package = Package(
	name: "SwiftUtilities",
	targets: [
		.target(name: "SwiftKVO"),
		.target(name: "LocalizedString"),
		.target(name: "CommandLineExtensions"),
	]
)

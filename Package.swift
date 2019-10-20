// swift-tools-version:5.0
import PackageDescription

let package = Package(
	name: "SwiftUtilities",
	products: [
		.library(name: "SwiftKVO", targets: ["SwiftKVO"]),
		.library(name: "LocalizedString", targets: ["LocalizedString"]),
		.library(name: "CommandLineExtensions", targets: ["CommandLineExtensions"]),
	],
	targets: [
		.target(name: "SwiftKVO"),
		.target(name: "LocalizedString"),
		.target(name: "CommandLineExtensions"),
	]
)

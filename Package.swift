// swift-tools-version:5.0
import PackageDescription

let package = Package(
	name: "SwiftUtilities",
	products: [
		.library(name: "SwiftKVO", targets: ["SwiftKVO"]),
		.library(name: "LocalizedString", targets: ["LocalizedString"]),
		.library(name: "CommandLineExtensions", targets: ["CommandLineExtensions"]),
		.library(name: "AuthorizationAPI", targets: ["AuthorizationAPI"]),
		.library(name: "CodesignCheck", targets: ["CodesignCheck"]),
	],
	targets: [
		.target(name: "SwiftKVO"),
		.target(name: "LocalizedString"),
		.target(name: "CommandLineExtensions"),
		.target(name: "AuthorizationAPI"),
		.target(name: "CodesignCheck"),
	]
)

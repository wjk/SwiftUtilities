// swift-tools-version:5.3
import PackageDescription

let package = Package(
	name: "SwiftUtilities",
	defaultLocalization: "en",
	products: [
		.library(name: "LocalizedString", targets: ["LocalizedString"]),
		.library(name: "CommandLineExtensions", targets: ["CommandLineExtensions"]),
		.library(name: "AuthorizationAPI", targets: ["AuthorizationAPI"]),
		.library(name: "CodesignCheck", targets: ["CodesignCheck"]),
		.library(name: "NotImplementedError", targets: ["NotImplementedError"]),
	],
	targets: [
		.target(name: "LocalizedString"),
		.target(name: "CommandLineExtensions"),
		.target(name: "AuthorizationAPI"),
		.target(name: "CodesignCheck"),
		.target(name: "NotImplementedError", dependencies: [
			"LocalizedString"
		]),
	]
)

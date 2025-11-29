// swift-tools-version: 6.0
import PackageDescription

#if TUIST
	import struct ProjectDescription.PackageSettings

	let packageSettings = PackageSettings(
		// Customize the product types for specific package product
		// Default is .staticFramework
		// productTypes: ["Alamofire": .framework,]
		productTypes: [:]
	)
#endif

let package = Package(
	name: "ElderGuard",
	dependencies: [
		.package(url: "https://github.com/kean/Nuke", .upToNextMajor(from: "12.8.0"))
	]
)

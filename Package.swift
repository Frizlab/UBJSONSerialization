// swift-tools-version:4.2
import PackageDescription



let package = Package(
	name: "UBJSONSerialization",
	products: [
		.library(name: "UBJSONSerialization", targets: ["UBJSONSerialization"])
	],
	dependencies: [
		.package(url: "https://github.com/Frizlab/SimpleStream", from: "2.0.0")
	],
	targets: [
		.target(name: "UBJSONSerialization", dependencies: ["SimpleStream"]),
		.testTarget(name: "UBJSONSerializationTests", dependencies: ["UBJSONSerialization"])
	]
)

// swift-tools-version:4.2
import PackageDescription



let package = Package(
	name: "UBJSONSerialization",
	products: [
		.library(name: "UBJSONSerialization", targets: ["UBJSONSerialization"])
	],
	dependencies: [
		.package(url: "https://github.com/Frizlab/stream-reader.git", from: "3.0.0-rc.3")
	],
	targets: [
		.target(name: "UBJSONSerialization", dependencies: ["StreamReader"]),
		.testTarget(name: "UBJSONSerializationTests", dependencies: ["UBJSONSerialization"])
	]
)

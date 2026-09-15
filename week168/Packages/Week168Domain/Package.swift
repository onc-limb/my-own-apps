// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Week168Domain",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "Week168Domain", targets: ["Week168Domain"])
    ],
    targets: [
        .target(name: "Week168Domain"),
        .testTarget(name: "Week168DomainTests", dependencies: ["Week168Domain"])
    ]
)

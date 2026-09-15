// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Week168Persistence",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "Week168Persistence", targets: ["Week168Persistence"])],
    dependencies: [.package(path: "../Week168Domain")],
    targets: [
        .target(name: "Week168Persistence", dependencies: ["Week168Domain"]),
        .testTarget(name: "Week168PersistenceTests", dependencies: ["Week168Persistence"])
    ]
)

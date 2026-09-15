// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Week168UseCases",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "Week168UseCases", targets: ["Week168UseCases"])],
    dependencies: [.package(path: "../Week168Domain"), .package(path: "../Week168Persistence")],
    targets: [
        .target(name: "Week168UseCases", dependencies: ["Week168Domain", "Week168Persistence"]),
        .testTarget(name: "Week168UseCasesTests", dependencies: ["Week168UseCases"])
    ]
)

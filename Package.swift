// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "YASDIDriver",
    platforms: [.macOS(.v11)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "YASDIDriver",
            targets: ["YASDIDriver"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "ClibYASDI", url: "https://github.com/TheMisfit68/ClibYASDI.git",.branch("master")),
        .package(name: "JVCocoa", url: "https://github.com/TheMisfit68/JVCocoa.git",  .branch("master")),
        .package(name: "SwiftSMTP", url: "https://github.com/IBM-Swift/Swift-SMTP.git", .upToNextMajor(from:"5.1.2"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "YASDIDriver",
            dependencies: [
                "ClibYASDI",
                "JVCocoa",
                "SwiftSMTP"
            ],
            resources:[
                .copy("Resources/YasdiConfigFile.ini"),
                .copy("Resources/InvertersData.sqlite")
            ]
        ),
        .testTarget(
            name: "YASDIDriverTests",
            dependencies: ["YASDIDriver"]),
    ]
)

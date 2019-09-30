// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xcupdate",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(
            name: "xcupdate",
            targets: ["xcupdate"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/nsomar/Guaka.git", from: "0.0.0"),
        .package(url: "https://github.com/getGuaka/Prompt.git", from: "0.0.0"),
        .package(url: "https://github.com/getGuaka/Colorizer.git", from: "0.0.0"),
        .package(url: "https://github.com/getGuaka/Run.git", from: "0.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "XCUFoundation",
            dependencies: ["Colorizer"]
        ),
        .target(
            name: "XCUnxip",
            dependencies: []
        ),
        .testTarget(
            name: "XCUFoundationTests",
            dependencies: ["XCUFoundation"]
        ),
        .target(
            name: "xcupdate",
            dependencies: ["xcupdateCore", "Guaka", "Prompt", "Colorizer", "Run", "XCUFoundation"],
            linkerSettings: [
                LinkerSetting.linkedFramework("PackageKit"),
                LinkerSetting.unsafeFlags(["-F/System/Library/PrivateFrameworks/"]),
            ]
        ),
        .target(
            name: "xcupdateCore",
            dependencies: ["OlympUs", "XCUFoundation", "XCUnxip"]
        ),
        .testTarget(
            name: "xcupdateCoreTests",
            dependencies: ["xcupdateCore", "Prompt", "Run", "XCUnxip"],
            linkerSettings: [
                LinkerSetting.linkedFramework("PackageKit"),
                LinkerSetting.unsafeFlags(["-F/System/Library/PrivateFrameworks/"]),
            ]
        ),
        .target(
            name: "OlympUs",
            dependencies: ["XCUFoundation"]
        ),
    ]
)

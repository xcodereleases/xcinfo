// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xcinfo",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(
            name: "xcinfo",
            targets: ["xcinfo"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/nsomar/Guaka.git", .branch("master")),
        .package(url: "https://github.com/getGuaka/Prompt.git", from: "0.0.0"),
        .package(url: "https://github.com/getGuaka/Colorizer.git", from: "0.0.0"),
        .package(url: "https://github.com/getGuaka/Run.git", from: "0.1.0"),
        .package(url: "https://github.com/xcodereleases/data.git", .branch("master"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "XCIFoundation",
            dependencies: ["Colorizer"]
        ),
        .target(
            name: "XCUnxip",
            dependencies: []
        ),
        .testTarget(
            name: "XCIFoundationTests",
            dependencies: ["XCIFoundation"]
        ),
        .target(
            name: "xcinfo",
            dependencies: ["xcinfoCore", "Guaka", "Prompt", "Colorizer", "Run", "XCIFoundation"],
            linkerSettings: [
                LinkerSetting.linkedFramework("PackageKit"),
                LinkerSetting.unsafeFlags(["-F/System/Library/PrivateFrameworks/"]),
            ]
        ),
        .target(
            name: "xcinfoCore",
            dependencies: ["OlympUs", "XCIFoundation", "XCUnxip", "XCModel"]
        ),
        .testTarget(
            name: "xcinfoCoreTests",
            dependencies: ["xcinfoCore", "Prompt", "Run", "XCUnxip", "Guaka"],
            linkerSettings: [
                LinkerSetting.linkedFramework("PackageKit"),
                LinkerSetting.unsafeFlags(["-F/System/Library/PrivateFrameworks/"]),
            ]
        ),
        .target(
            name: "OlympUs",
            dependencies: ["XCIFoundation"]
        ),
    ]
)

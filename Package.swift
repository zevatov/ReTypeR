// swift-tools-version: 6.0
// SwiftPM wrapper used ONLY for headless verification (no Xcode installed).
// The canonical build system is XcodeGen (project.yml) + xcodebuild.
import PackageDescription

let package = Package(
    name: "ReTypeR",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "2.4.0")
    ],
    targets: [
        .executableTarget(
            name: "ReTypeR",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "ReTypeRTests",
            dependencies: ["ReTypeR"],
            path: "Tests/ReTypeRTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)

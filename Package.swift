// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShareMounter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ShareMounter",
            path: "Sources/ShareMounter",
            linkerSettings: [
                // NetFS drives the window-less network-volume mount under /Volumes.
                .linkedFramework("NetFS"),
            ]
        ),
        .testTarget(
            name: "ShareMounterTests",
            dependencies: ["ShareMounter"],
            path: "Tests/ShareMounterTests"
        ),
    ]
)

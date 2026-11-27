// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Klikr",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Klikr",
            path: "Sources/Klikr",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)

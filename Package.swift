// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "EclipseApp",
    platforms: [.macOS(.v11)],
    targets: [
        .executableTarget(
            name: "EclipseApp",
            path: "Sources/EclipseApp",
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Users/jai/Documents/Eclipse/SonyCRSDK/canon_sdk/EDSDK/Framework",
                    "-framework", "EDSDK",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Users/jai/Documents/Eclipse/SonyCRSDK/canon_sdk/EDSDK/Framework"
                ])
            ]
        )
    ]
)

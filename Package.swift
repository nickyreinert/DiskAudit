// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DiskAuditApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DiskAuditApp", targets: ["DiskAuditApp"])
    ],
    targets: [
        .executableTarget(
            name: "DiskAuditApp"
        )
    ]
)

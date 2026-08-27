// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "timesheet-alert-comments",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "timesheet-alert-comments", targets: ["timesheet-alert-comments"]),
    ],
    targets: [
        .executableTarget(
            name: "timesheet-alert-comments"
        ),
    ]
)

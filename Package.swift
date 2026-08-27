// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "timesheet-alert-comments",
    platforms: [
        .macOS(.v13)
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

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PulseMonitor",
    defaultLocalization: "es",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PulseCore",
            targets: ["PulseCore"]
        ),
        .executable(
            name: "PulseMonitor",
            targets: ["PulseMonitor"]
        ),
        .executable(
            name: "PulseWidgets",
            targets: ["PulseWidgets"]
        )
    ],
    targets: [
        .target(
            name: "PulseCore",
            dependencies: [],
            path: "Sources/PulseCore",
            cSettings: [
                .headerSearchPath("include")
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("EventKit"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .executableTarget(
            name: "PulseMonitor",
            dependencies: ["PulseCore"],
            path: "Sources/PulseMonitor",
            exclude: ["Resources/Info.plist", "Resources/PulseMonitor.entitlements", "Resources/AppIcon.icns"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("Charts"),
                .linkedFramework("SwiftData"),
                .linkedFramework("AppIntents"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "PulseWidgets",
            dependencies: ["PulseCore"],
            path: "Sources/PulseWidgets",
            exclude: ["Resources/Info.plist", "Resources/PulseWidgets.entitlements"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("WidgetKit"),
                .linkedFramework("Charts"),
                .linkedFramework("AppIntents")
            ]
        ),
        .executableTarget(
            name: "PulseTestsRunner",
            dependencies: ["PulseCore"],
            path: "Tests/PulseTestsRunner"
        )
    ]
)

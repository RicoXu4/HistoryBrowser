// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HistoryBrowser",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HistoryBrowser", targets: ["HistoryBrowser"])
    ],
    targets: [
        .executableTarget(
            name: "HistoryBrowser",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)

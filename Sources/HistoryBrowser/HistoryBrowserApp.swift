import SwiftUI

@main
struct HistoryBrowserApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .importExport) {
                Button("Grant Safari Folder...") {
                    NotificationCenter.default.post(name: .historyBrowserGrantSafariFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Choose History Database...") {
                    NotificationCenter.default.post(name: .historyBrowserChooseDatabase, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .option])

                Button("Reveal History Database in Finder") {
                    NotificationCenter.default.post(name: .historyBrowserRevealDatabase, object: nil)
                }

                Divider()

                Button("Open Full Disk Access Settings") {
                    NotificationCenter.default.post(name: .historyBrowserOpenFullDiskAccess, object: nil)
                }
            }

            CommandMenu("History") {
                Button("Refresh History") {
                    NotificationCenter.default.post(name: .historyBrowserRefresh, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Jump to Today") {
                    NotificationCenter.default.post(name: .historyBrowserJumpToday, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Show All Dates") {
                    NotificationCenter.default.post(name: .historyBrowserShowAllDates, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

import AppKit
import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDatabaseURL = SafariHistoryReader.defaultHistoryURL

    private let bookmarkDefaultsKey = "SafariFolderBookmark"
    private var selectedAccessURL: URL?

    init() {
        restoreSafariFolderBookmark()
    }

    var oldestVisit: Date? {
        entries.last?.visitDate
    }

    var newestVisit: Date? {
        entries.first?.visitDate
    }

    func loadDefaultHistory() {
        load(from: selectedDatabaseURL, scopedAccessURL: selectedAccessURL)
    }

    func chooseSafariFolder() {
        let panel = NSOpenPanel()
        panel.title = "Grant Access to Safari History"
        panel.message = "Select the Safari folder so History Browser can read History.db and its sidecar files."
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = SafariHistoryReader.defaultHistoryURL.deletingLastPathComponent()

        if panel.runModal() == .OK, let folderURL = panel.url {
            selectedAccessURL = folderURL
            selectedDatabaseURL = folderURL.appendingPathComponent("History.db")
            storeSafariFolderBookmark(folderURL)
            load(from: selectedDatabaseURL, scopedAccessURL: folderURL)
        }
    }

    func chooseDatabase() {
        let panel = NSOpenPanel()
        panel.title = "Choose Safari History.db"
        panel.message = "Select a standalone or copied History.db file. Use Grant Safari Folder for live Safari history."
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.database, .data]
        panel.directoryURL = SafariHistoryReader.defaultHistoryURL.deletingLastPathComponent()

        if panel.runModal() == .OK, let url = panel.url {
            selectedAccessURL = url
            selectedDatabaseURL = url
            load(from: url, scopedAccessURL: url)
        }
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([selectedDatabaseURL])
    }

    func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func load(from url: URL, scopedAccessURL: URL?) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loadedEntries = try await Task.detached(priority: .userInitiated) {
                    let didStartAccessing = scopedAccessURL?.startAccessingSecurityScopedResource() ?? false
                    defer {
                        if didStartAccessing {
                            scopedAccessURL?.stopAccessingSecurityScopedResource()
                        }
                    }

                    return try SafariHistoryReader().load(from: url)
                }.value

                entries = loadedEntries
            } catch {
                entries = []
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }

            isLoading = false
        }
    }

    private func storeSafariFolderBookmark(_ folderURL: URL) {
        do {
            let bookmarkData = try folderURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkDefaultsKey)
        } catch {
            errorMessage = "History Browser can use this folder now, but could not remember it for next launch. \(error.localizedDescription)"
        }
    }

    private func restoreSafariFolderBookmark() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkDefaultsKey) else {
            return
        }

        do {
            var isStale = false
            let folderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            selectedAccessURL = folderURL
            selectedDatabaseURL = folderURL.appendingPathComponent("History.db")

            if isStale {
                storeSafariFolderBookmark(folderURL)
            }
        } catch {
            UserDefaults.standard.removeObject(forKey: bookmarkDefaultsKey)
        }
    }
}

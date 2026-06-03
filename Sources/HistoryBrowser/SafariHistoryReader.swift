import Foundation
import SQLite3

struct HistoryEntry: Identifiable, Hashable {
    let id: Int64
    let url: String
    let title: String
    let visitDate: Date
    let visitCount: Int

    var host: String {
        URL(string: url)?.host(percentEncoded: false) ?? ""
    }
}

enum HistoryReaderError: LocalizedError {
    case databaseNotFound(URL)
    case copyFailed(String)
    case openFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseNotFound(let url):
            return "Could not find History.db at \(url.path)."
        case .copyFailed(let message):
            return "Could not copy Safari history into a temporary read location. \(message)"
        case .openFailed(let message):
            return "Could not open the history database. \(message)"
        case .queryFailed(let message):
            return "Could not read Safari history. \(message)"
        }
    }
}

final class SafariHistoryReader {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    static var defaultHistoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/History.db")
    }

    func load(from sourceURL: URL = SafariHistoryReader.defaultHistoryURL) throws -> [HistoryEntry] {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw HistoryReaderError.databaseNotFound(sourceURL)
        }

        let workingDirectory = try createTemporaryDatabaseCopy(from: sourceURL)
        defer {
            try? fileManager.removeItem(at: workingDirectory)
        }

        let copiedDatabaseURL = workingDirectory.appendingPathComponent("History.db")
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(copiedDatabaseURL.path, &database, flags, nil) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error."
            sqlite3_close(database)
            throw HistoryReaderError.openFailed(message)
        }

        defer {
            sqlite3_close(database)
        }

        return try queryEntries(database)
    }

    private func createTemporaryDatabaseCopy(from sourceURL: URL) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("HistoryBrowser-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            for suffix in ["", "-wal", "-shm"] {
                let source = URL(fileURLWithPath: sourceURL.path + suffix)
                let destination = directory.appendingPathComponent("History.db\(suffix)")

                if fileManager.fileExists(atPath: source.path) {
                    try fileManager.copyItem(at: source, to: destination)
                }
            }
        } catch {
            throw HistoryReaderError.copyFailed(error.localizedDescription)
        }

        return directory
    }

    private func queryEntries(_ database: OpaquePointer?) throws -> [HistoryEntry] {
        let sql = """
        SELECT
            history_visits.id,
            history_items.url,
            COALESCE(history_visits.title, ''),
            history_visits.visit_time,
            history_items.visit_count
        FROM history_visits
        JOIN history_items ON history_items.id = history_visits.history_item
        ORDER BY history_visits.visit_time DESC
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryReaderError.queryFailed(sqliteMessage(database))
        }

        defer {
            sqlite3_finalize(statement)
        }

        var entries: [HistoryEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)
            let url = stringColumn(statement, 1)
            let title = stringColumn(statement, 2)
            let visitTime = sqlite3_column_double(statement, 3)
            let visitCount = Int(sqlite3_column_int(statement, 4))

            entries.append(
                HistoryEntry(
                    id: id,
                    url: url,
                    title: title.isEmpty ? url : title,
                    visitDate: Date(timeIntervalSinceReferenceDate: visitTime),
                    visitCount: visitCount
                )
            )
        }

        let result = sqlite3_errcode(database)
        guard result == SQLITE_DONE || result == SQLITE_OK else {
            throw HistoryReaderError.queryFailed(sqliteMessage(database))
        }

        return entries
    }

    private func stringColumn(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: text)
    }

    private func sqliteMessage(_ database: OpaquePointer?) -> String {
        guard let database else {
            return "Unknown SQLite error."
        }
        return String(cString: sqlite3_errmsg(database))
    }
}

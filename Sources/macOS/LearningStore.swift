import Foundation
import SQLite3

struct LearnedEntry: Codable { let mode: String; let key: String; let value: String; let count: Int }
struct Backup: Codable { let format: Int; let entries: [LearnedEntry] }
enum DataError: Error { case invalidBackup, database }
struct LearningStore {
    static let shared = LearningStore()
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ArmKeyKey", isDirectory: true)
    }
    let modes = ["cj", "simplex", "cj5", "smartZhuyin"]
    func database(_ mode: String, body: (OpaquePointer) throws -> Void) throws {
        let folder = directory
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var db: OpaquePointer?
        guard sqlite3_open(folder.appendingPathComponent("Generic-\(mode)-cin-DynamicCandidateOrder.sqlite3").path, &db) == SQLITE_OK, let db else { if let db { sqlite3_close(db) }; throw DataError.database }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1000)
        guard sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS user_frequency (key, value, count)", nil, nil, nil) == SQLITE_OK else { throw DataError.database }
        try body(db)
    }
    func exportData() throws -> Data {
        var entries: [LearnedEntry] = []
        for mode in modes {
            try database(mode) { db in
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(db, "SELECT key,value,count FROM user_frequency ORDER BY rowid", -1, &statement, nil) == SQLITE_OK else { throw DataError.database }
                defer { sqlite3_finalize(statement) }
                var result = sqlite3_step(statement)
                while result == SQLITE_ROW {
                    entries.append(LearnedEntry(mode: mode, key: String(cString: sqlite3_column_text(statement, 0)), value: String(cString: sqlite3_column_text(statement, 1)), count: Int(sqlite3_column_int64(statement, 2))))
                    result = sqlite3_step(statement)
                }
                guard result == SQLITE_DONE else { throw DataError.database }
            }
        }
        return try JSONEncoder().encode(Backup(format: 2, entries: entries))
    }
    func replace(_ data: Data, dictionary: URL? = Bundle.main.url(forResource: "Dictionary", withExtension: "sqlite3"), mandarin: URL? = Bundle.main.url(forResource: "Mandarin", withExtension: "sqlite3")) throws {
        guard data.count <= 16 * 1024 * 1024 else { throw DataError.invalidBackup }
        let backup = try JSONDecoder().decode(Backup.self, from: data)
        guard [1, 2].contains(backup.format), backup.entries.count <= 100_000 else { throw DataError.invalidBackup }
        let targetModes = backup.format == 1 ? ["cj", "simplex"] : modes
        var seen = Set<String>()
        for entry in backup.entries {
            let smart = entry.mode == "smartZhuyin"
            let validKey = smart ? entry.key.utf8.count <= 128 && entry.key.unicodeScalars.allSatisfy({ (0x3105...0x3129).contains($0.value) || "ˊˇˋ˙-".unicodeScalars.contains($0) }) : entry.key.utf8.count <= 5 && entry.key.utf8.allSatisfy({ $0 >= 32 && $0 < 127 })
            guard targetModes.contains(entry.mode), !entry.key.isEmpty, validKey, !entry.value.isEmpty,
                  entry.value.utf8.count <= 128, entry.count > 0, entry.count <= Int(Int32.max),
                  seen.insert("\(entry.mode)\u{0}\(entry.key)\u{0}\(entry.value)").inserted else { throw DataError.invalidBackup }
        }
        let copyText = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for mode in targetModes {
            let entries = backup.entries.filter { $0.mode == mode }
            if entries.isEmpty { continue }
            guard let url = mode == "smartZhuyin" ? mandarin : dictionary else { throw DataError.database }
            var source: OpaquePointer?
            guard sqlite3_open_v2(url.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let source else { if let source { sqlite3_close(source) }; throw DataError.database }
            defer { sqlite3_close(source) }
            for entry in entries {
                var query: OpaquePointer?
                let wildcard = ["cj", "cj5"].contains(mode) && entry.key.count > 1 && (entry.key.contains("*") || entry.key.contains("?"))
                let predicate = wildcard ? "key LIKE ? ESCAPE '!'" : "key = ?"
                let pattern = wildcard ? entry.key.replacingOccurrences(of: "!", with: "!!").replacingOccurrences(of: "%", with: "!%").replacingOccurrences(of: "_", with: "!_").replacingOccurrences(of: "*", with: "%").replacingOccurrences(of: "?", with: "_") : entry.key
                let table = mode == "smartZhuyin" ? "smart" : "Generic-\(mode)-cin"
                let sql = "SELECT 1 FROM '\(table)' WHERE \(predicate) AND value = ? AND substr(key,1,11) != '__property_' LIMIT 1"
                guard sqlite3_prepare_v2(source, sql, -1, &query, nil) == SQLITE_OK else { throw DataError.database }
                defer { sqlite3_finalize(query) }
                sqlite3_bind_text(query, 1, pattern, -1, copyText)
                sqlite3_bind_text(query, 2, entry.value, -1, copyText)
                guard sqlite3_step(query) == SQLITE_ROW else { throw DataError.invalidBackup }
            }
        }
        // All participating databases use rollback journals for cross-file atomicity.
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        try database("cj") { db in
            for mode in targetModes where mode != "cj" {
                var attach: OpaquePointer?
                guard sqlite3_prepare_v2(db, "ATTACH DATABASE ? AS \(mode)", -1, &attach, nil) == SQLITE_OK else { throw DataError.database }
                let path = directory.appendingPathComponent("Generic-\(mode)-cin-DynamicCandidateOrder.sqlite3").path
                sqlite3_bind_text(attach, 1, path, -1, transient)
                let attached = sqlite3_step(attach)
                sqlite3_finalize(attach)
                guard attached == SQLITE_DONE, sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS \(mode).user_frequency (key,value,count)", nil, nil, nil) == SQLITE_OK else { throw DataError.database }
            }
            guard sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else { throw DataError.database }
            do {
                for mode in targetModes {
                    let schema = mode == "cj" ? "main" : mode
                    guard sqlite3_exec(db, "DELETE FROM \(schema).user_frequency", nil, nil, nil) == SQLITE_OK else { throw DataError.database }
                    var statement: OpaquePointer?
                    guard sqlite3_prepare_v2(db, "INSERT INTO \(schema).user_frequency VALUES(?,?,?)", -1, &statement, nil) == SQLITE_OK else { throw DataError.database }
                    defer { sqlite3_finalize(statement) }
                    for entry in backup.entries where entry.mode == mode {
                        sqlite3_bind_text(statement, 1, entry.key, -1, transient)
                        sqlite3_bind_text(statement, 2, entry.value, -1, transient)
                        sqlite3_bind_int64(statement, 3, Int64(entry.count))
                        guard sqlite3_step(statement) == SQLITE_DONE else { throw DataError.database }
                        sqlite3_reset(statement)
                    }
                }
                guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else { throw DataError.database }
            } catch { sqlite3_exec(db, "ROLLBACK", nil, nil, nil); throw error }
        }
        Self.changed()
    }
    static func changed() { let d = UserDefaults.standard; d.set(d.integer(forKey: "dataGeneration") + 1, forKey: "dataGeneration") }
}


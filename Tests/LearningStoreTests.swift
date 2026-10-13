import Foundation
import SQLite3
@main struct LearningStoreTests {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        let dictionary = URL(fileURLWithPath: CommandLine.arguments[2])
        let store = LearningStore(directory: directory)
        let valid = Backup(format: 1, entries: [LearnedEntry(mode: "cj", key: "a", value: "日", count: 3), LearnedEntry(mode: "simplex", key: "a", value: "日", count: 2)])
        try store.replace(JSONEncoder().encode(valid), dictionary: dictionary)
        let exported = try JSONDecoder().decode(Backup.self, from: store.exportData())
        precondition(exported.entries.count == 2 && exported.entries[0].count == 3)
        for invalid in [Backup(format: 1, entries: [LearnedEntry(mode: "simplex", key: "*", value: "日", count: 1)]), Backup(format: 99, entries: []), Backup(format: 1, entries: [LearnedEntry(mode: "cj", key: "a", value: "not a candidate", count: 1)]), Backup(format: 1, entries: [LearnedEntry(mode: "cj", key: "a", value: "日", count: -1)]), Backup(format: 1, entries: valid.entries + valid.entries)] {
            var rejected = false
            do { try store.replace(JSONEncoder().encode(invalid), dictionary: dictionary) } catch { rejected = true }
            precondition(rejected)
            let stillSaved = try JSONDecoder().decode(Backup.self, from: store.exportData())
            precondition(stillSaved.entries.count == 2 && stillSaved.entries[0].count == 3)
        }
        // Force failure in the second database after the first database was updated.
        try store.database("simplex") { db in
            precondition(sqlite3_exec(db, "CREATE TRIGGER reject_import BEFORE INSERT ON user_frequency BEGIN SELECT RAISE(ABORT, 'test failure'); END", nil, nil, nil) == SQLITE_OK)
        }
        var rolledBack = false
        do { try store.replace(JSONEncoder().encode(Backup(format: 1, entries: [LearnedEntry(mode: "cj", key: "a", value: "日", count: 99), LearnedEntry(mode: "simplex", key: "a", value: "日", count: 99)])), dictionary: dictionary) } catch { rolledBack = true }
        precondition(rolledBack)
        let afterFailure = try JSONDecoder().decode(Backup.self, from: store.exportData())
        precondition(afterFailure.entries[0].count == 3 && afterFailure.entries[1].count == 2)
        try store.database("simplex") { db in precondition(sqlite3_exec(db, "DROP TRIGGER reject_import", nil, nil, nil) == SQLITE_OK) }
        try store.replace(JSONEncoder().encode(Backup(format: 1, entries: [])), dictionary: dictionary)
        let empty = try JSONDecoder().decode(Backup.self, from: store.exportData())
        precondition(empty.entries.isEmpty)
        print("PASS learning backup roundtrip, invalid import rejection, cross-database rollback, reset")
    }
}

import Foundation

struct UpdateRelease: Codable, Equatable, Sendable {
    struct Package: Codable, Equatable, Sendable {
        let url: URL
        let size: Int64
        let sha256: String
    }
    let version: String
    let build: Int
    let minimumSystemVersion: String
    let architectures: [String]
    let notes: String
    let package: Package
}

struct UpdateFeed: Codable, Sendable {
    let schemaVersion: Int
    let bundleIdentifier: String
    let channel: String
    let releases: [UpdateRelease]

    static let endpoint = URL(string: "https://jr-everstar.github.io/ArmKeyKey/updates/stable.json")!
    static let bundleID = "everstar.inputmethod.armkeykey.mac"
    static let maximumPackageSize: Int64 = 512 * 1024 * 1024

    static func versionParts(_ value: String) -> [Int]? {
        guard value.range(of: #"^\d+\.\d+(?:\.\d+)?$"#, options: .regularExpression) != nil else { return nil }
        let parts = value.split(separator: ".").compactMap { Int($0) }
        guard parts.count == value.split(separator: ".").count else { return nil }
        return parts + Array(repeating: 0, count: 3 - parts.count)
    }
    static func validPackageURL(_ url: URL) -> Bool {
        guard url.scheme == "https", url.host == "github.com", url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil else { return false }
        return url.path.range(of: #"^/jr-everstar/ArmKeyKey/releases/download/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+\.pkg$"#,
                              options: .regularExpression) != nil
    }
    static func decode(_ data: Data) throws -> UpdateFeed {
        guard data.count <= 1024 * 1024 else { throw UpdateFailure.invalidFeed }
        let feed = try JSONDecoder().decode(UpdateFeed.self, from: data)
        guard feed.schemaVersion == 1, feed.bundleIdentifier == bundleID, feed.channel == "stable",
              feed.releases.count <= 1000 else { throw UpdateFailure.invalidFeed }
        var builds = Set<Int>()
        for release in feed.releases {
            guard release.build > 0, builds.insert(release.build).inserted,
                  versionParts(release.version) != nil, versionParts(release.minimumSystemVersion) != nil,
                  !release.architectures.isEmpty, !release.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  release.notes.utf8.count <= 64 * 1024,
                  release.package.size > 0, release.package.size <= maximumPackageSize,
                  validPackageURL(release.package.url),
                  release.package.sha256.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil
            else { throw UpdateFailure.invalidFeed }
        }
        return feed
    }
    func newest(currentBuild: Int, system: String, architecture: String = "arm64") -> UpdateRelease? {
        guard let os = Self.versionParts(system) else { return nil }
        return releases.filter {
            guard let minimum = Self.versionParts($0.minimumSystemVersion) else { return false }
            return $0.build > currentBuild && $0.architectures.contains(architecture) && !os.lexicographicallyPrecedes(minimum)
        }.max { $0.build < $1.build }
    }
}

enum UpdateFailure: LocalizedError {
    case invalidFeed, download, verification, timedOut, activeInput, personalInstallation
    var errorDescription: String? {
        switch self {
        case .invalidFeed: return "更新資料格式不正確，請稍後再試。"
        case .download: return "下載未完成或伺服器回應不正確，請重新檢查更新後再試。"
        case .verification: return "安裝包驗證失敗，未啟動安裝。請重新下載。"
        case .timedOut: return "操作逾時，請稍後再試。"
        case .activeInput: return "請先從選單列切換至其他輸入法，再繼續。"
        case .personalInstallation: return "偵測到個人安裝版。請先切換其他輸入法、退出 ArmKeyKey，移走個人 Input Methods 內的舊 App，再開啟安裝包。請保留 Application Support 中的個人資料。"
        }
    }
}

enum UpdateSchedule {
    static func shouldNotify(manual: Bool, enabled: Bool, build: Int, skipped: Int, notified: Int) -> Bool {
        !manual && enabled && build != skipped && build > notified
    }
    static func due(enabled: Bool, lastAttempt: Date?, now: Date) -> Bool {
        guard enabled else { return false }
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= 86400 || lastAttempt > now
    }
}

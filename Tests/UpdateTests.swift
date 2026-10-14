import Foundation
import CryptoKit

final class UpdateStub: URLProtocol, @unchecked Sendable {
    static var data = Data()
    static var status = 200
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: [:])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
    static func session(_ data: Data, status: Int = 200) -> URLSession {
        self.data = data; self.status = status
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdateStub.self]
        return URLSession(configuration: configuration)
    }
}

@main struct UpdateTests {
    static func require(_ condition: Bool, _ message: String) {
        if !condition { fatalError(message) }
    }
    static func release(_ build: Int = 15, system: String = "26.0", architecture: String = "arm64", data: Data = Data("pkg".utf8)) -> UpdateRelease {
        UpdateRelease(version: "0.8.0", build: build, minimumSystemVersion: system, architectures: [architecture], notes: "測試更新",
                      package: .init(url: URL(string: "https://github.com/jr-everstar/ArmKeyKey/releases/download/v0.8.0-build15/ArmKeyKey.pkg")!,
                                     size: Int64(data.count), sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()))
    }
    static func feed(_ releases: [UpdateRelease]) -> UpdateFeed {
        UpdateFeed(schemaVersion: 1, bundleIdentifier: UpdateFeed.bundleID, channel: "stable", releases: releases)
    }
    static func rejected(_ action: () throws -> Void) {
        do { try action(); fatalError("Expected rejection") } catch {}
    }
    static func main() async throws {
        if CommandLine.arguments.dropFirst().first == "--live-feed" {
            let live = try await UpdateTransport.feed()
            print("PASS live GitHub Pages feed: \(live.releases.count) releases")
            return
        }
        if CommandLine.arguments.count == 2 {
            let package = URL(fileURLWithPath: CommandLine.arguments[1])
            let data = try Data(contentsOf: package)
            let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: "Resources/Info.plist")), format: nil) as! [String: Any]
            let fixture = UpdateRelease(version: info["CFBundleShortVersionString"] as! String, build: Int(info["CFBundleVersion"] as! String)!, minimumSystemVersion: info["LSMinimumSystemVersion"] as! String, architectures: ["arm64"], notes: "Local verification only", package: release(data: data).package)
            try UpdateInstaller.validate(package, release: fixture)
            print("PASS real signed PKG: checksum, Gatekeeper notarization, team, payload, receipt and logout requirement")
            return
        }
        // Input-source switching is tested with fixtures; never change the real desktop.
        let abc = UpdateKeyboardSource(id: "com.apple.keylayout.ABC", name: "ABC", enabled: true, selectable: true, keyboardLayout: true)
        let other = UpdateKeyboardSource(id: "com.apple.keylayout.US", name: "U.S.", enabled: true, selectable: true, keyboardLayout: true)
        let disabled = UpdateKeyboardSource(id: "disabled", name: "Disabled", enabled: false, selectable: true, keyboardLayout: true)
        let unselectable = UpdateKeyboardSource(id: "not-selectable", name: "Unavailable", enabled: true, selectable: false, keyboardLayout: true)
        let method = UpdateKeyboardSource(id: "other.method", name: "Other IME", enabled: true, selectable: true, keyboardLayout: false)
        let arm = UpdateKeyboardSource(id: UpdateFeed.bundleID, name: "ArmKeyKey", enabled: true, selectable: true, keyboardLayout: true)
        require(UpdateInputSourcePreparation.candidate([other, abc], preferredID: abc.id) == abc, "prefer last ASCII keyboard among enabled layouts")
        require(UpdateInputSourcePreparation.candidate([disabled, unselectable, method, arm, other], preferredID: "missing") == other, "fallback uses only enabled selectable keyboard layout")
        require(UpdateInputSourcePreparation.candidate([disabled, unselectable, method, arm], preferredID: nil) == nil, "no safe keyboard candidate")
        var current: String? = UpdateFeed.bundleID
        var selections = 0
        let switched = try UpdateInputSourcePreparation.prepare(currentID: { current }, sources: [abc], preferredID: abc.id) { selected in
            selections += 1; current = selected.id; return true
        }
        require(switched == abc.id && selections == 1 && current == abc.id, "switch ArmKeyKey and verify actual current source")
        let retained = try UpdateInputSourcePreparation.prepare(currentID: { other.id }, sources: [], preferredID: nil) { _ in
            fatalError("must not switch an already safe source")
        }
        require(retained == other.id, "preserve existing other source")
        current = UpdateFeed.bundleID
        rejected { try UpdateInputSourcePreparation.prepare(currentID: { current }, sources: [], preferredID: nil, select: { _ in fatalError("no candidate") }) }
        rejected { try UpdateInputSourcePreparation.prepare(currentID: { nil }, sources: [abc], preferredID: nil, select: { _ in fatalError("unknown current source") }) }
        rejected { try UpdateInputSourcePreparation.prepare(currentID: { current }, sources: [abc], preferredID: nil, select: { _ in false }) }
        rejected { try UpdateInputSourcePreparation.prepare(currentID: { current }, sources: [abc], preferredID: nil, select: { _ in true }) }
        require(current == UpdateFeed.bundleID, "failed selection must not proceed as if switched")
        let candidate = release()
        let encoded = try JSONEncoder().encode(feed([candidate]))
        require(try UpdateFeed.decode(encoded).newest(currentBuild: 14, system: "26.0") == candidate, "select newer")
        require(feed([]).newest(currentBuild: 14, system: "26.0") == nil, "empty feed")
        require(feed([candidate]).newest(currentBuild: 15, system: "26.0") == nil, "equal build")
        require(feed([candidate]).newest(currentBuild: 16, system: "26.0") == nil, "no downgrade")
        require(feed([release(16, system: "27.0"), candidate]).newest(currentBuild: 14, system: "26.2") == candidate, "OS fallback")
        require(feed([release(16, architecture: "x86_64"), candidate]).newest(currentBuild: 14, system: "26.2") == candidate, "architecture fallback")
        rejected { _ = try UpdateFeed.decode(JSONEncoder().encode(feed([candidate, candidate]))) }
        rejected { _ = try UpdateFeed.decode(Data("{}".utf8)) }
        rejected { _ = try UpdateFeed.decode(Data(repeating: 32, count: 1024 * 1024 + 1)) }
        for url in ["http://github.com/jr-everstar/ArmKeyKey/releases/download/v1/app.pkg", "https://evil.example/app.pkg", "https://github.com/other/other/releases/download/v1/app.pkg", "https://github.com/jr-everstar/ArmKeyKey/releases/latest/download/app.pkg", "https://user@github.com/jr-everstar/ArmKeyKey/releases/download/v1/app.pkg"] {
            require(!UpdateFeed.validPackageURL(URL(string: url)!), "reject URL")
        }
        require(UpdateRedirects.allowed(URL(string: "https://release-assets.githubusercontent.com/file?signature=test")!, package: true), "GitHub asset redirect")
        require(!UpdateRedirects.allowed(URL(string: "https://evil.example/file")!, package: true), "reject redirect")
        require(!UpdateRedirects.allowed(URL(string: "http://release-assets.githubusercontent.com/file")!, package: true), "reject HTTP")
        require(UpdateSchedule.shouldNotify(manual: false, enabled: true, build: 15, skipped: 0, notified: 0), "new notification")
        require(!UpdateSchedule.shouldNotify(manual: false, enabled: true, build: 15, skipped: 15, notified: 0), "skip")
        require(!UpdateSchedule.shouldNotify(manual: false, enabled: true, build: 15, skipped: 0, notified: 15), "once per version")
        require(!UpdateSchedule.shouldNotify(manual: true, enabled: true, build: 15, skipped: 0, notified: 0), "manual no banner")
        require(!UpdateSchedule.shouldNotify(manual: false, enabled: false, build: 15, skipped: 0, notified: 0), "disabled no banner")
        require(!UpdateSchedule.shouldNotify(manual: false, enabled: true, build: 15, skipped: 0, notified: 16), "withdrawal does not repeat older banner")
        let now = Date()
        require(UpdateSchedule.due(enabled: true, lastAttempt: nil, now: now), "initial check")
        require(!UpdateSchedule.due(enabled: false, lastAttempt: nil, now: now), "disabled")
        require(!UpdateSchedule.due(enabled: true, lastAttempt: now.addingTimeInterval(-3600), now: now), "throttle")
        require(UpdateSchedule.due(enabled: true, lastAttempt: now.addingTimeInterval(-86400), now: now), "daily")
        require(UpdateSchedule.due(enabled: true, lastAttempt: now.addingTimeInterval(3600), now: now), "clock reset")
        let fetched = try await UpdateTransport.feed(using: UpdateStub.session(encoded))
        require(fetched.releases == [candidate], "network feed")
        do { _ = try await UpdateTransport.feed(using: UpdateStub.session(encoded, status: 404)); fatalError("HTTP failure") } catch {}
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let target = temp.appendingPathComponent("test.pkg")
        try await UpdateTransport.download(candidate, to: target, using: UpdateStub.session(Data("pkg".utf8))) { _ in }
        require(try Data(contentsOf: target) == Data("pkg".utf8), "download bytes")
        for wrong in [Data("bad".utf8), Data("pk".utf8), Data("pkg-too-long".utf8)] {
            do { try await UpdateTransport.download(candidate, to: target, using: UpdateStub.session(wrong)) { _ in }; fatalError("download mismatch") } catch {}
        }
        rejected { try UpdateInstaller.validate(target, release: candidate) }
        let cancelled = Task {
            try await UpdateTransport.download(candidate, to: target, using: UpdateStub.session(Data("pkg".utf8))) { _ in }
        }
        cancelled.cancel()
        do { try await cancelled.value; fatalError("cancellation") } catch {}
        print("PASS updater: feed/compatibility/URLs/redirects/daily schedule/HTTP/download size and checksum/cancellation")
    }
}

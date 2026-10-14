import Foundation
import CryptoKit
import AppKit
import Carbon

// Testable selection policy. Only enabled, selectable keyboard layouts are
// eligible; preparing an update never enables or installs an input source.
struct UpdateKeyboardSource: Equatable {
    let id: String
    let name: String
    let enabled: Bool
    let selectable: Bool
    let keyboardLayout: Bool
}

enum UpdateInputSourcePreparation {
    static func candidate(_ sources: [UpdateKeyboardSource], preferredID: String?) -> UpdateKeyboardSource? {
        let eligible = sources.filter { $0.id != UpdateFeed.bundleID && $0.enabled && $0.selectable && $0.keyboardLayout }
        return eligible.first { $0.id == preferredID } ?? eligible.first
    }
    @discardableResult static func prepare(currentID: () -> String?, sources: [UpdateKeyboardSource],
                                          preferredID: String?, select: (UpdateKeyboardSource) -> Bool) throws -> String {
        guard let current = currentID() else { throw UpdateFailure.inputSourceSwitch }
        if current != UpdateFeed.bundleID { return current }
        guard let source = candidate(sources, preferredID: preferredID), select(source), currentID() == source.id else {
            throw UpdateFailure.inputSourceSwitch
        }
        return source.id
    }
}

// Blocking verification runs off the UI thread, and before any Installer handoff.
enum UpdateInstaller {
    static let team = "6495K4X8W5"
    static func command(_ executable: String, _ arguments: [String], timeout: TimeInterval = 120) throws -> String {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: output.path, contents: nil, attributes: [.posixPermissions: 0o600])
        defer { try? FileManager.default.removeItem(at: output) }
        let handle = try FileHandle(forWritingTo: output)
        defer { try? handle.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = handle; process.standardError = handle
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() > deadline { process.terminate(); throw UpdateFailure.timedOut }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard process.terminationStatus == 0 else { throw UpdateFailure.verification }
        return String(decoding: try Data(contentsOf: output), as: UTF8.self)
    }
    static func validate(_ package: URL, release: UpdateRelease) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: package.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? NSNumber)?.int64Value == release.package.size else { throw UpdateFailure.verification }
        let handle = try FileHandle(forReadingFrom: package)
        defer { try? handle.close() }
        var sha = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty { sha.update(data: chunk) }
        guard sha.finalize().map({ String(format: "%02x", $0) }).joined() == release.package.sha256 else { throw UpdateFailure.verification }
        let signature = try command("/usr/sbin/pkgutil", ["--check-signature", package.path])
        guard signature.contains("Developer ID Installer:"), signature.contains("(\(team))") else { throw UpdateFailure.verification }
        let assessment = try command("/usr/sbin/spctl", ["--assess", "--type", "install", "--verbose=2", package.path])
        guard assessment.contains("source=Notarized Developer ID") else { throw UpdateFailure.verification }
        // Gatekeeper verifies notarization. The PKG must retain its staple for offline installation.
        // stapler is a developer tool, so consumer Macs rely on Gatekeeper's assessment.
        let expanded = FileManager.default.temporaryDirectory.appendingPathComponent("ArmKeyKey-verify-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: expanded) }
        _ = try command("/usr/sbin/pkgutil", ["--expand-full", package.path, expanded.path])
        let components = try FileManager.default.contentsOfDirectory(at: expanded, includingPropertiesForKeys: nil).filter { $0.pathExtension == "pkg" }
        guard components.count == 1, components[0].lastPathComponent == "ArmKeyKey-component.pkg" else { throw UpdateFailure.verification }
        let receipt = try XMLDocument(contentsOf: expanded.appendingPathComponent("ArmKeyKey-component.pkg/PackageInfo"))
        guard let root = receipt.rootElement(), root.attribute(forName: "identifier")?.stringValue == "everstar.armkeykey.mac.pkg",
              root.attribute(forName: "version")?.stringValue == String(release.build),
              root.attribute(forName: "install-location")?.stringValue == "/Library/Input Methods" else { throw UpdateFailure.verification }
        let distribution = try XMLDocument(contentsOf: expanded.appendingPathComponent("Distribution"))
        guard let options = try distribution.nodes(forXPath: "/installer-gui-script/options").first as? XMLElement,
              options.attribute(forName: "hostArchitectures")?.stringValue == "arm64",
              let conclusion = try distribution.nodes(forXPath: "/installer-gui-script/pkg-ref[@onConclusion='RequireLogout']").first,
              ["ArmKeyKey-component.pkg", "#ArmKeyKey-component.pkg"].contains(conclusion.stringValue ?? "") else { throw UpdateFailure.verification }
        let app = expanded.appendingPathComponent("ArmKeyKey-component.pkg/Payload/ArmKeyKey.app")
        _ = try command("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        let signing = try command("/usr/bin/codesign", ["-dv", "--verbose=4", app.path])
        guard signing.contains("TeamIdentifier=\(team)"), signing.contains("Authority=Developer ID Application:"),
              let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")), format: nil) as? [String: Any],
              info["CFBundleIdentifier"] as? String == UpdateFeed.bundleID,
              info["CFBundleShortVersionString"] as? String == release.version,
              (info["CFBundleVersion"] as? String).flatMap(Int.init) == release.build,
              info["LSMinimumSystemVersion"] as? String == release.minimumSystemVersion
        else { throw UpdateFailure.verification }
    }
    static var personalInstallation: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods/ArmKeyKey.app")
    }
    private static func sourceString(_ input: TISInputSource, _ key: CFString) -> String? {
        guard let value = TISGetInputSourceProperty(input, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }
    private static func sourceBool(_ input: TISInputSource, _ key: CFString) -> Bool {
        guard let value = TISGetInputSourceProperty(input, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue())
    }
    private static func currentInputSourceID() -> String? {
        guard let input = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return sourceString(input, kTISPropertyInputSourceID)
    }
    static func requireOtherInputSource() throws {
        guard let identifier = currentInputSourceID(), identifier != UpdateFeed.bundleID else { throw UpdateFailure.activeInput }
    }
    private static func keyboardSources() -> [(UpdateKeyboardSource, TISInputSource)] {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String,
                      kTISPropertyInputSourceIsEnabled as String: true] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return [] }
        return list.compactMap { input in
            guard let id = sourceString(input, kTISPropertyInputSourceID) else { return nil }
            return (UpdateKeyboardSource(id: id, name: sourceString(input, kTISPropertyLocalizedName) ?? id,
                       enabled: sourceBool(input, kTISPropertyInputSourceIsEnabled),
                       selectable: sourceBool(input, kTISPropertyInputSourceIsSelectCapable),
                       keyboardLayout: sourceString(input, kTISPropertyInputSourceType) == kTISTypeKeyboardLayout as String), input)
        }
    }
    private static func preferredKeyboardID() -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() else { return nil }
        return sourceString(source, kTISPropertyInputSourceID)
    }
    @MainActor static var preparationMessage: String {
        if let current = currentInputSourceID(), current != UpdateFeed.bundleID {
            return "請先儲存其他 App 的工作。確認後會退出 ArmKeyKey 並開啟安裝程式；安裝完成後需要登出再登入。"
        }
        if let source = UpdateInputSourcePreparation.candidate(keyboardSources().map { $0.0 }, preferredID: preferredKeyboardID()) {
            return "請先儲存其他 App 的工作。確認後會自動切換至「\(source.name)」，再退出 ArmKeyKey 並開啟安裝程式，毋須自行使用快捷鍵切換。安裝完成後需要登出再登入。"
        }
        return "請先儲存其他 App 的工作。未找到可切換的已啟用鍵盤來源；請在系統鍵盤設定加入 ABC 等鍵盤來源後重試。安裝完成後需要登出再登入。"
    }
    @MainActor static func prepareInputSource() throws {
        let sources = keyboardSources()
        try UpdateInputSourcePreparation.prepare(currentID: currentInputSourceID,
            sources: sources.map { $0.0 }, preferredID: preferredKeyboardID()) { chosen in
                guard let input = sources.first(where: { $0.0.id == chosen.id })?.1 else { return false }
                return TISSelectInputSource(input) == noErr
            }
    }
    @MainActor static func handoff(package: URL, release: UpdateRelease) throws {
        try prepareInputSource()
        let receipt = package.deletingLastPathComponent().appendingPathComponent("release.json")
        try JSONEncoder().encode(release).write(to: receipt, options: .atomic)
        let helper = Process()
        helper.executableURL = Bundle.main.executableURL
        helper.arguments = ["--update-installer", String(getpid()), package.path, receipt.path]
        try helper.run()
        NSApp.terminate(nil)
    }
    // Spawn the same signed executable directly, before IMK initialization. It waits
    // for its parent to exit, validates again, then execs open. The package
    // supports background relaunches and requires logout to end old sessions.
    static func runHandoffIfRequested() {
        guard CommandLine.arguments.contains("--update-installer") else { return }
        do {
            let args = CommandLine.arguments
            guard args.count == 5, args[1] == "--update-installer", let parent = Int32(args[2]), parent > 1 else { throw UpdateFailure.verification }
            let package = URL(fileURLWithPath: args[3])
            let release = try JSONDecoder().decode(UpdateRelease.self, from: Data(contentsOf: URL(fileURLWithPath: args[4])))
            let feed = UpdateFeed(schemaVersion: 1, bundleIdentifier: UpdateFeed.bundleID, channel: "stable", releases: [release])
            _ = try UpdateFeed.decode(JSONEncoder().encode(feed))
            let current = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? Int.max
            guard release.build > current else { throw UpdateFailure.verification }
            let deadline = Date().addingTimeInterval(30)
            while kill(parent, 0) == 0 {
                guard Date() < deadline else { throw UpdateFailure.timedOut }
                Thread.sleep(forTimeInterval: 0.1)
            }
            // The input source can change after parent exit (including IMK
            // relaunch). Do not reject a verified package on that race.
            try validate(package, release: release)
            let strings = ["/usr/bin/open", "-a", "/System/Library/CoreServices/Installer.app", package.path]
            let pointers = strings.map { strdup($0) }
            defer { pointers.forEach { free($0) } }
            var argv = pointers + [nil]
            _ = argv.withUnsafeMutableBufferPointer { execv("/usr/bin/open", $0.baseAddress!) }
            throw UpdateFailure.verification
        } catch {
            let alert = NSAlert()
            alert.messageText = "未能開啟更新安裝程式"
            alert.informativeText = error.localizedDescription + "\n現有版本仍然保留，可以重新開啟 ArmKeyKey。"
            alert.runModal()
            exit(1)
        }
    }
}

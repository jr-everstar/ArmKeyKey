import Foundation
import CryptoKit
import AppKit
import Carbon

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
    static func requireOtherInputSource() throws {
        guard let input = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let value = TISGetInputSourceProperty(input, kTISPropertyInputSourceID) else { throw UpdateFailure.activeInput }
        let identifier = Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
        guard identifier != UpdateFeed.bundleID else { throw UpdateFailure.activeInput }
    }
    @MainActor static func handoff(package: URL, release: UpdateRelease) throws {
        try requireOtherInputSource()
        guard !FileManager.default.fileExists(atPath: personalInstallation.path) else { throw UpdateFailure.personalInstallation }
        let receipt = package.deletingLastPathComponent().appendingPathComponent("release.json")
        try JSONEncoder().encode(release).write(to: receipt, options: .atomic)
        let helper = Process()
        helper.executableURL = Bundle.main.executableURL
        helper.arguments = ["--update-installer", String(getpid()), package.path, receipt.path]
        try helper.run()
        NSApp.terminate(nil)
    }
    // Spawn the same signed executable directly, before IMK initialization. It waits
    // for its parent to exit, validates again, then execs open so Installer's
    // preinstall never sees this handoff process named ArmKeyKey.
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
            try requireOtherInputSource()
            guard !FileManager.default.fileExists(atPath: personalInstallation.path) else { throw UpdateFailure.personalInstallation }
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

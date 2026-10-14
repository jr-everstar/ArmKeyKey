import Foundation
@main struct InstallationPathTests {
    @MainActor static func main() throws {
        assert(FirstLoginSetup.shouldShow(completed: false, alreadyEnabled: false))
        assert(!FirstLoginSetup.shouldShow(completed: true, alreadyEnabled: false))
        assert(!FirstLoginSetup.shouldShow(completed: false, alreadyEnabled: true))
        assert(!Installation.hasEnabledSource())
        // Command-line test hosts have no bundle identifier; discovery must not crash.
        assert(Installation.registeredSources().isEmpty)
        let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: "Resources/Info.plist")), format: nil) as! [String: Any]
        assert(info["TISIntendedLanguage"] as? String == "zh-Hant")
        let project = try String(contentsOfFile: "ArmKeyKey.xcodeproj/project.pbxproj", encoding: .utf8)
        assert(project.contains("everstar.inputmethod.armkeykey.mac"), "Input method bundle identifiers require the .inputmethod. component")
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: base) }
        let home = base.appendingPathComponent("home")
        let shared = base.appendingPathComponent("shared/ArmKeyKey.app")
        let local = home.appendingPathComponent("Library/Input Methods/ArmKeyKey.app")
        let download = base.appendingPathComponent("Downloads/ArmKeyKey.app")
        assert(Installation.resolveDestination(current: download, home: home, shared: shared).path == local.path)
        try fm.createDirectory(at: shared, withIntermediateDirectories: true)
        assert(Installation.resolveDestination(current: download, home: home, shared: shared).path == shared.path)
        assert(Installation.resolveDestination(current: shared, home: home, shared: shared).path == shared.path)
        assert(Installation.resolveDestination(current: local, home: home, shared: shared).path == local.path)
        print("PASS downloaded ZIP, shared pkg installation and existing per-user installation routing")
    }
}

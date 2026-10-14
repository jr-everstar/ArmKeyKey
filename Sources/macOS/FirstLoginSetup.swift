import AppKit

/// A short-lived login helper; it exits before creating an InputMethodKit server.
@MainActor
enum FirstLoginSetup {
    static let completedKey = "firstLoginSetupCompleted"
    static let keyboardSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!

    static func shouldShow(completed: Bool, alreadyEnabled: Bool) -> Bool {
        !completed && !alreadyEnabled
    }

    static func runIfRequested(openSettings: @escaping @MainActor () -> Bool = { NSWorkspace.shared.open(keyboardSettingsURL) }) {
        guard CommandLine.arguments.contains("--first-login-setup") else { return }
        let defaults = UserDefaults.standard
        record("Helper invoked: build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "test")")
        let completed = defaults.bool(forKey: completedKey)
        let enabled = Installation.hasEnabledSource()
        guard shouldShow(completed: completed, alreadyEnabled: enabled) else {
            defaults.set(true, forKey: completedKey)
            defaults.synchronize() // Persist before this short-lived helper exits.
            record("Skipped: completed=\(completed), alreadyEnabled=\(enabled)")
            exit(0)
        }
        record("Starting setup application")
        let app = NSApplication.shared
        let delegate = SetupDelegate(openSettings: openSettings)
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
        exit(0)
    }

    private final class SetupDelegate: NSObject, NSApplicationDelegate {
        let openSettings: @MainActor () -> Bool
        init(openSettings: @escaping @MainActor () -> Bool) { self.openSettings = openSettings }

        func applicationDidFinishLaunching(_ notification: Notification) {
            // Let AppKit complete launch and process pending login events first.
            DispatchQueue.main.async { FirstLoginSetup.presentGuide(openSettings: self.openSettings) }
        }
    }

    private static func record(_ message: String) {
        NSLog("ArmKeyKey first-login setup: %@", message)
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/ArmKeyKey", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("first-login-setup.log")
            // Keep a small, local diagnostic record containing setup state only.
            var text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if text.utf8.count > 8192 { text = "" }
            text += "\(Date().ISO8601Format()) \(message)\n"
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch { NSLog("Unable to write first-login setup log: %@", error.localizedDescription) }
    }

    private static func presentGuide(openSettings: @MainActor () -> Bool) {
        let defaults = UserDefaults.standard
        let app = NSApplication.shared
        record("Application finished launching; presenting guide")
        // Registration alone never enables or selects an input source for the user.
        try? Installation.register()
        let opened = openSettings()
        record("Keyboard Settings open request: \(opened)")
        let guide = NSAlert()
        guide.messageText = "歡迎使用 ArmKeyKey"
        guide.informativeText = """
        請在「系統設定 → 鍵盤」完成以下步驟：

        1. 在「文字輸入」按「編輯⋯」，再按「＋」。
        2. 選擇「中文（繁體）」→「ArmKeyKey」→「加入」，再按「完成」。
        3. 在螢幕右上角的輸入選單選擇「ArmKeyKey」，即可開始打字。

        若找不到輸入選單，可在文字輸入設定開啟「在選單列中顯示輸入選單」。
        之後亦可在 ArmKeyKey 設定的「安裝與使用」頁重新開啟鍵盤設定。
        """
        guide.window.level = .floating
        guide.addButton(withTitle: opened ? "前往鍵盤設定" : "重試開啟鍵盤設定")
        guide.addButton(withTitle: "稍後自行設定")
        app.activate(ignoringOtherApps: true)
        let response = guide.runModal()
        defaults.set(true, forKey: completedKey)
        defaults.synchronize()
        record("Guide acknowledged")
        if response == .alertFirstButtonReturn { _ = openSettings() }
        app.terminate(nil)
    }
}

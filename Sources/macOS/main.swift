import AppKit
import InputMethodKit
import CoreText

UpdateInstaller.runHandoffIfRequested()

// App-only language override; does not change the user's system language.
var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
arguments["AppleLanguages"] = ["zh-Hant"]
UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
if CommandLine.arguments.contains("--register-input-source") {
    do {
        try Installation.register()
        let sources = Installation.registeredSources()
        print("ArmKeyKey：註冊成功，找到 \(sources.count) 個輸入來源（中文／繁體）。")
        exit(sources.isEmpty ? 1 : 0)
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
}
// Register only for this process; no installation into the user’s Fonts folder.
if let fontURL = Bundle.main.url(forResource: "NotoSansTC-VariableFont_wght", withExtension: "ttf") {
    var fontError: Unmanaged<CFError>?
    if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &fontError),
       let error = fontError?.takeRetainedValue(),
       CFErrorGetCode(error) != CTFontManagerError.alreadyRegistered.rawValue {
        NSLog("Unable to load bundled candidate font: %@", error as Error as NSError)
    }
} else {
    NSLog("Bundled Noto Sans TC font is missing; using an available fallback.")
}
let app = NSApplication.shared
let defaults = UserDefaults.standard
defaults.register(defaults: ["candidateStyle": "yahoo", "candidateFontSize": 17.0, "candidateScale": 1.0, "mode": "cangjie", "cangjieLearning": true, "simplexLearning": false, "extendedCharacters": false, "associatedPhrases": true, "phraseModifier": 8, "simplifiedOutput": false, "fullWidthOutput": false])
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { AKSettings.show(); return true }
    func applicationDidFinishLaunching(_ notification: Notification) {
        UpdateManager.shared.start()
        if CommandLine.arguments.contains("--settings") || !UserDefaults.standard.bool(forKey: "onboardingShown") { AKSettings.show() }
    }
}
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
let connectionName = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as! String
let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier!)
app.run()

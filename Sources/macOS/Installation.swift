import Foundation
import Carbon

enum Installation {
    static var destination: URL {
        resolveDestination(current: Bundle.main.bundleURL,
                           home: FileManager.default.homeDirectoryForCurrentUser,
                           shared: URL(fileURLWithPath: "/Library/Input Methods/ArmKeyKey.app"))
    }
    // Prefer the running installation, then an existing shared installation.
    // A downloaded ZIP continues to install into the current user's Library.
    static func resolveDestination(current: URL, home: URL, shared: URL) -> URL {
        let local = home.appendingPathComponent("Library/Input Methods/ArmKeyKey.app", isDirectory: true)
        let running = current.resolvingSymlinksInPath()
        if running == shared.resolvingSymlinksInPath() { return shared }
        if running == local.resolvingSymlinksInPath() { return local }
        if FileManager.default.fileExists(atPath: shared.path) { return shared }
        return local
    }
    static func install() throws {
        let source = Bundle.main.bundleURL.resolvingSymlinksInPath()
        let target = destination.resolvingSymlinksInPath()
        if source != target {
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: target.path) {
                guard Bundle(url: target)?.object(forInfoDictionaryKey: "CFBundleVersion") as? String == Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
                    throw NSError(domain: "ArmKeyKey", code: 1, userInfo: [NSLocalizedDescriptionKey: "已有其他版本。請先切換至其他輸入法，將資源庫 Input Methods 中的舊版 ArmKeyKey 移到垃圾桶，再重新安裝。個人選字資料會保留。"])
                }
            } else {
                try FileManager.default.copyItem(at: source, to: target)
            }
        }
        try register()
        let sources = registeredSources()
        guard !sources.isEmpty else { throw NSError(domain: "ArmKeyKey", code: 3, userInfo: [NSLocalizedDescriptionKey: "已註冊，請登出後重新登入以更新輸入來源清單。"] ) }
        for source in sources {
            let result = TISEnableInputSource(source)
            guard result == noErr else { throw NSError(domain: "ArmKeyKey", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "已安裝，但加入輸入來源失敗（\(result)）。請登出後重新登入，再到「中文（繁體）」加入 ArmKeyKey。"] ) }
        }
    }
    static func register() throws {
        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw NSError(domain: "ArmKeyKey", code: 2, userInfo: [NSLocalizedDescriptionKey: "尚未安裝 ArmKeyKey，請先按「安裝並註冊輸入法」。"])
        }
        let result = TISRegisterInputSource(destination as CFURL)
        guard result == noErr else {
            throw NSError(domain: "ArmKeyKey", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "輸入法註冊失敗（\(result)）。請登出後重新登入，再到「中文（繁體）」加入 ArmKeyKey。"])
        }
    }
    static func hasEnabledSource() -> Bool {
        guard let identifier = Bundle.main.bundleIdentifier else { return false }
        let filter = [kTISPropertyInputSourceID as String: identifier,
                      kTISPropertyInputSourceIsEnabled as String: true] as CFDictionary
        guard let result = TISCreateInputSourceList(filter, false) else { return false }
        return CFArrayGetCount(result.takeRetainedValue()) > 0
    }
    static func registeredSources() -> [TISInputSource] {
        guard let identifier = Bundle.main.bundleIdentifier else { return [] }
        let filter = [kTISPropertyInputSourceID as String: identifier] as CFDictionary
        // TIS can return nil when registration has not produced a source.
        guard let result = TISCreateInputSourceList(filter, true) else { return [] }
        return result.takeRetainedValue() as? [TISInputSource] ?? []
    }
}

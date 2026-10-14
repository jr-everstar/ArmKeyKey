import AppKit

// Only update-click navigation is stubbed; mode feedback uses the production panel.
@MainActor final class AKSettings {
    static func checkUpdates() {}
}

@main struct FeatureNotificationTests {
    @MainActor static func main() async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let wasActive = app.isActive
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        func require(_ condition: Bool, _ message: String) {
            if !condition { fatalError(message) }
        }
        func panels() -> [NSWindow] {
            app.windows.filter { $0.identifier?.rawValue == "ArmKeyKey.feature" }
        }
        AKFeatureNotifications.showFeature("unknown", enabled: true)
        require(panels().isEmpty, "Unknown keys must not show a panel")
        AKFeatureNotifications.showFeature("simplifiedOutput", enabled: true)
        let panel = panels().first!
        func body() -> String { (panel.contentView?.viewWithTag(1) as! NSTextField).stringValue }
        require(panel.isVisible && body() == "簡體輸出已開啟", "Show simplified state immediately without notification authorization")
        require(!panel.canBecomeKey && !panel.canBecomeMain && panel.ignoresMouseEvents, "Do not intercept typing or clicks")
        require(!panel.isKeyWindow && app.isActive == wasActive, "Do not activate input method")
        require(NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmost, "Keep host app focused")
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
        require(abs(panel.frame.maxX - (screen.visibleFrame.maxX - 16)) < 1 && abs(panel.frame.maxY - (screen.visibleFrame.maxY - 16)) < 1, "Position at upper right of pointer screen")
        require(panel.collectionBehavior.contains(.canJoinAllSpaces) && panel.collectionBehavior.contains(.fullScreenAuxiliary), "Support Spaces and fullscreen")
        try await Task.sleep(for: .milliseconds(1200))
        AKFeatureNotifications.showFeature("simplifiedOutput", enabled: false)
        require(body() == "簡體輸出已關閉，已切換至繁體", "Show traditional state")
        AKFeatureNotifications.showFeature("fullWidthOutput", enabled: true)
        require(body() == "全碼文字已開啟（全形）", "Show fullwidth state")
        AKFeatureNotifications.showFeature("fullWidthOutput", enabled: false)
        require(body() == "全碼文字已關閉（半形）" && panels().count == 1, "Reuse panel with latest state")
        AKFeatureNotifications.showFeature("associatedPhrases", enabled: true)
        require(body() == "聯想詞已開啟", "Show phrase enabled state")
        AKFeatureNotifications.showFeature("associatedPhrases", enabled: false)
        require(body() == "聯想詞已關閉", "Show phrase disabled state")
        try await Task.sleep(for: .milliseconds(1100))
        require(panel.isVisible, "Canceled earlier dismissal must not hide newer feedback")
        try await Task.sleep(for: .milliseconds(1100))
        require(!panel.isVisible, "Dismiss after latest display expires")
        print("PASS production feature panel: state, placement, focus, reuse and dismissal")
    }
}

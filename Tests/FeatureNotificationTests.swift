import AppKit

// Only update-click navigation is stubbed; mode feedback uses the production panel.
@MainActor final class AKSettings {
    static func checkUpdates() {}
}

@main struct FeatureNotificationTests {
    @MainActor static func main() async throws {
        // The standalone test executable has no resource bundle; use the shipped icon.
        let appIcon = NSImage(contentsOfFile: "Resources/ArmKeyKey.icns")!
        appIcon.setName("ArmKeyKey")
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        let appearanceKeys = ["candidateStyle", "candidateBackground", "candidateHighlight", "candidateText", "candidateSelectedText", "candidateAccent", "candidateFontSize", "candidateScale"]
        let saved = Dictionary(uniqueKeysWithValues: appearanceKeys.map { ($0, defaults.object(forKey: $0)) })
        defer {
            for key in appearanceKeys {
                if let value = saved[key] ?? nil { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        for key in appearanceKeys { defaults.removeObject(forKey: key) }
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
        func rgb(_ color: NSColor?) -> String {
            guard let c = color?.usingColorSpace(.sRGB) else { return "missing" }
            return String(format: "%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
        }
        func checkPalette(_ background: String, _ highlight: String, _ text: String, _ selected: String, _ accent: String) {
            let view = panel.contentView!
            let label = view.viewWithTag(1) as! NSTextField
            let icon = view.viewWithTag(3) as! NSImageView
            require(icon.image === appIcon && icon.frame.width > 0, "Show bundled ArmKeyKey app icon")
            require(icon.frame.maxX < label.superview!.frame.minX, "Icon and status text do not overlap")
            require(rgb(NSColor(cgColor: view.layer!.backgroundColor!)) == background, "Candidate background palette")
            require(rgb(NSColor(cgColor: label.superview!.layer!.backgroundColor!)) == highlight, "Candidate selection palette")
            require(rgb(label.textColor) == selected, "Candidate selected text palette")
            require(rgb((view.viewWithTag(2) as! NSTextField).textColor) == text, "Candidate normal text palette")
            require(rgb(NSColor(cgColor: view.layer!.borderColor!)) == accent, "Candidate border palette")
        }
        func snapshot(_ name: String) {
            guard CommandLine.arguments.count > 1 else { return }
            let view = panel.contentView!
            view.layoutSubtreeIfNeeded()
            view.display()
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(name + ".png"))
        }
        AKFeatureNotifications.showFeature("simplifiedOutput", enabled: false)
        checkPalette("000000", "7A007A", "FFFFFF", "FFFFFF", "CCCCCC")
        snapshot("feedback-yahoo")
        let defaultHeight = panel.frame.height
        defaults.set("everstar", forKey: "candidateStyle")
        AKFeatureNotifications.showFeature("simplifiedOutput", enabled: false)
        checkPalette("4D4D4D", "00D7E6", "FFFFFF", "4D4D4D", "00D7E6")
        snapshot("feedback-armkeykey")
        for (key, value) in zip(appearanceKeys[1...5], ["102030", "204060", "EEEEEE", "FFFF00", "AABBCC"]) { defaults.set(value, forKey: key) }
        defaults.set(28, forKey: "candidateFontSize")
        defaults.set(1.6, forKey: "candidateScale")
        AKFeatureNotifications.showFeature("simplifiedOutput", enabled: false)
        checkPalette("102030", "204060", "EEEEEE", "FFFF00", "AABBCC")
        require(panel.frame.height > defaultHeight && panel.frame.width <= screen.visibleFrame.width - 32, "Font and scale fit screen")
        let label = panel.contentView!.viewWithTag(1) as! NSTextField
        require(abs(label.font!.pointSize - 44.8) < 0.01, "Candidate font size and scale applied")
        require(label.frame.height >= label.cell!.cellSize(forBounds: label.bounds).height.rounded(.up), "Message is not clipped at maximum size")
        require(panels().count == 1 && !panel.isKeyWindow && NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmost, "Theme refresh reuses panel without stealing focus")
        snapshot("feedback-custom-large")
        defaults.set("invalid", forKey: "candidateBackground")
        AKFeatureNotifications.showFeature("associatedPhrases", enabled: true)
        require(rgb(NSColor(cgColor: panel.contentView!.layer!.backgroundColor!)) == "4D4D4D", "Malformed custom color falls back to selected style")
        print("PASS production feature panel: state, placement, focus, reuse, dismissal, candidate themes and custom appearance")
    }
}

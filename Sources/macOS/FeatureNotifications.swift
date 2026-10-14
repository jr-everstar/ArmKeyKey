import AppKit
import UserNotifications

// Mode feedback must be immediate even when Notification Center is unavailable.
// This panel never becomes key, activates the app, or includes typed content.
@MainActor
private final class FeaturePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
@objc final class AKFeatureNotifications: NSObject, UNUserNotificationCenterDelegate {
    private static let shared = AKFeatureNotifications()
    static func configure() { UNUserNotificationCenter.current().delegate = shared }
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?

    @objc static func showFeature(_ key: String, enabled: Bool) {
        let message: String
        switch key {
        case "simplifiedOutput": message = enabled ? "簡體輸出已開啟" : "簡體輸出已關閉，已切換至繁體"
        case "fullWidthOutput": message = enabled ? "全碼文字已開啟（全形）" : "全碼文字已關閉（半形）"
        default: return
        }
        shared.show(message)
    }

    private func show(_ message: String) {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        dismissal?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let body = panel.contentView?.viewWithTag(1) as? NSTextField
        body?.stringValue = message
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.maxX - panel.frame.width - 16,
                                     y: visible.maxY - panel.frame.height - 16))
        panel.orderFrontRegardless()
        dismissal = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(2)) }
            catch { return }
            self?.panel?.orderOut(nil)
            self?.dismissal = nil
        }
    }

    private func makePanel() -> NSPanel {
        let panel = FeaturePanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 84),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.identifier = NSUserInterfaceItemIdentifier("ArmKeyKey.feature")
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 340, height: 84))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        background.layer?.masksToBounds = true
        let title = NSTextField(labelWithString: "ArmKeyKey")
        title.font = .boldSystemFont(ofSize: 13)
        title.frame = NSRect(x: 20, y: 49, width: 300, height: 18)
        let body = NSTextField(labelWithString: "")
        body.tag = 1
        body.font = .systemFont(ofSize: 14)
        body.frame = NSRect(x: 20, y: 21, width: 300, height: 20)
        background.addSubview(title)
        background.addSubview(body)
        panel.contentView = background
        return panel
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let isUpdate = response.notification.request.identifier == "ArmKeyKey.update"
        Task { @MainActor in
            if isUpdate { AKSettings.checkUpdates() }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}

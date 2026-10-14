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
        case "associatedPhrases": message = enabled ? "聯想詞已開啟" : "聯想詞已關閉"
        default: return
        }
        shared.show(message)
    }

    private func show(_ message: String) {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        dismissal?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let visible = screen.visibleFrame
        applyAppearance(to: panel, message: message, maximumWidth: visible.width - 32)
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
        return panel
    }

    // Read the same preferences and palette as the candidate list on every show,
    // so an existing feedback window also reflects appearance changes immediately.
    private func applyAppearance(to panel: NSPanel, message: String, maximumWidth: CGFloat) {
        let defaults = UserDefaults.standard
        let everstar = defaults.string(forKey: "candidateStyle") == "everstar"
        func color(_ key: String, _ fallback: String) -> NSColor {
            let saved = defaults.string(forKey: key) ?? ""
            let hex = saved.count == 6 ? saved : fallback
            let rgb = UInt32(hex, radix: 16) ?? UInt32(fallback, radix: 16)!
            return NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                           green: CGFloat((rgb >> 8) & 255) / 255,
                           blue: CGFloat(rgb & 255) / 255, alpha: 1)
        }
        let requestedSize = defaults.double(forKey: "candidateFontSize")
        let size = requestedSize.isFinite && requestedSize > 0 ? min(28, max(12, requestedSize)) : 17
        let requestedScale = defaults.double(forKey: "candidateScale")
        let scale = requestedScale.isFinite && requestedScale > 0 ? min(1.6, max(0.8, requestedScale)) : 1
        let base = NSFont(name: "NotoSansTC-Regular", size: size * scale)
            ?? NSFont(name: "NotoSansTC-Thin_Regular", size: size * scale)
            ?? NSFont.systemFont(ofSize: size * scale)
        let descriptor = base.fontDescriptor.addingAttributes([
            .cascadeList: [NSFontDescriptor(name: "PingFangTC-Regular", size: size * scale)]
        ])
        let font = NSFont(descriptor: descriptor, size: size * scale) ?? base
        let padding = 14 * scale
        let iconSize = 40 * scale
        let textX = padding + iconSize + 12 * scale
        let width = min(maximumWidth, max(340 * scale,
            (message as NSString).size(withAttributes: [.font: font]).width + textX + padding + 4))
        let body = NSTextField(wrappingLabelWithString: message)
        body.tag = 1
        body.font = font
        body.textColor = color("candidateSelectedText", everstar ? "4D4D4D" : "FFFFFF")
        let textWidth = max(1, width - textX - padding)
        let textHeight = ceil(body.cell!.cellSize(forBounds: NSRect(x: 0, y: 0, width: textWidth, height: 1000)).height)
        let rowHeight = max(25 * scale, textHeight + 8 * scale)
        let titleHeight = 18 * scale
        let height = max(iconSize + padding * 2, titleHeight + 4 * scale + rowHeight + padding * 2)
        let background = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.wantsLayer = true
        background.layer?.backgroundColor = color("candidateBackground", everstar ? "4D4D4D" : "000000").cgColor
        background.layer?.cornerRadius = 11 * scale
        background.layer?.masksToBounds = true
        let row = NSView(frame: NSRect(x: textX - 6 * scale, y: padding, width: textWidth + 12 * scale, height: rowHeight))
        row.wantsLayer = true
        row.layer?.backgroundColor = color("candidateHighlight", everstar ? "00D7E6" : "7A007A").cgColor
        row.layer?.cornerRadius = 5 * scale
        body.frame = NSRect(x: 6 * scale, y: (rowHeight - textHeight) / 2, width: textWidth, height: textHeight)
        row.addSubview(body)
        background.addSubview(row)
        let title = NSTextField(labelWithString: "ArmKeyKey")
        title.tag = 2
        title.font = .boldSystemFont(ofSize: 13 * scale)
        title.textColor = color("candidateText", "FFFFFF")
        title.frame = NSRect(x: textX, y: padding + rowHeight + 4 * scale, width: textWidth, height: titleHeight)
        background.addSubview(title)
        let icon = NSImageView(frame: NSRect(x: padding, y: (height - iconSize) / 2, width: iconSize, height: iconSize))
        icon.tag = 3
        icon.image = NSImage(named: "ArmKeyKey") ?? NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityLabel("ArmKeyKey")
        background.addSubview(icon)
        background.layer?.borderWidth = 1
        background.layer?.borderColor = color("candidateAccent", everstar ? "00D7E6" : "CCCCCC").cgColor
        panel.setContentSize(NSSize(width: width, height: height))
        panel.contentView = background
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

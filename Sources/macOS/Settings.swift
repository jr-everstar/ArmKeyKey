import SwiftUI
import AppKit
import SQLite3
import UniformTypeIdentifiers
import UserNotifications

// Notification content contains mode state only, never anything the user types.
@MainActor
@objc final class AKFeatureNotifications: NSObject, UNUserNotificationCenterDelegate {
    private static let shared = AKFeatureNotifications()
    private var pending: [String: String] = [:]
    private var delivering = false

    @objc static func showFeature(_ key: String, enabled: Bool) {
        let message: String
        switch key {
        case "simplifiedOutput": message = enabled ? "簡體輸出已開啟" : "簡體輸出已關閉，已切換至繁體"
        case "fullWidthOutput": message = enabled ? "全碼文字已開啟（全形）" : "全碼文字已關閉（半形）"
        default: return
        }
        shared.pending[key] = message
        shared.deliver()
    }

    private func deliver() {
        guard !delivering else { return }
        delivering = true
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        Task { @MainActor in
            defer { delivering = false }
            var status = await center.notificationSettings().authorizationStatus
            if status == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert])
                status = await center.notificationSettings().authorizationStatus
            }
            guard status == .authorized || status == .provisional else {
                pending.removeAll()
                return
            }
            while let (key, message) = pending.first {
                pending.removeValue(forKey: key)
                let content = UNMutableNotificationContent()
                content.title = "ArmKeyKey"
                content.body = message
                let identifier = "ArmKeyKey.feature." + key
                center.removeDeliveredNotifications(withIdentifiers: [identifier])
                try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}

private func tr(_ key: String) -> String { NSLocalizedString(key, comment: "") }
private final class SettingsNavigation: ObservableObject {
    @Published var selection = "input"
}
@MainActor
@objc final class AKSettings: NSObject {
    private static var window: NSWindow?
    private static let navigation = SettingsNavigation()
    @objc static func show() { open("input") }
    @objc static func showAbout() { open("about") }
    @objc static func showLicenses() { open("license-armkeykey") }
    private static func open(_ page: String) {
        UserDefaults.standard.set(true, forKey: "onboardingShown")
        navigation.selection = page
        if window == nil {
            let created = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(navigation: navigation)))
            created.title = "ArmKeyKey 設定"
            created.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            created.setContentSize(NSSize(width: 960, height: 740))
            created.minSize = NSSize(width: 820, height: 600)
            created.center()
            created.isReleasedWhenClosed = false
            window = created
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
private struct SettingsView: View {
    @ObservedObject var navigation: SettingsNavigation
    private let accent = Color(red: 0.05, green: 0.48, blue: 0.64)
    @AppStorage("candidateStyle") private var candidateStyle = "yahoo"
    @AppStorage("candidateBackground") private var candidateBackground = ""
    @AppStorage("candidateHighlight") private var candidateHighlight = ""
    @AppStorage("candidateText") private var candidateText = ""
    @AppStorage("candidateSelectedText") private var candidateSelectedText = ""
    @AppStorage("candidateAccent") private var candidateAccent = ""
    @AppStorage("candidateFontSize") private var candidateFontSize = 17.0
    @AppStorage("candidateScale") private var candidateScale = 1.0
    private var isArmPreset: Bool { candidateStyle == "everstar" }
    private func appearanceColor(_ hex: String, fallback: String) -> Color {
        let value = UInt32(hex.count == 6 ? hex : fallback, radix: 16) ?? UInt32(fallback, radix: 16)!
        return Color(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    private func colorBinding(_ value: Binding<String>, fallback: String) -> Binding<Color> {
        Binding(get: { appearanceColor(value.wrappedValue, fallback: fallback) }, set: { color in
            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            value.wrappedValue = String(format: "%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
        })
    }
    private func resetAppearance() {
        candidateBackground = ""; candidateHighlight = ""; candidateText = ""
        candidateSelectedText = ""; candidateAccent = ""
        candidateFontSize = 17; candidateScale = 1
    }
    private var customAppearance: Bool {
        ![candidateBackground, candidateHighlight, candidateText, candidateSelectedText, candidateAccent].allSatisfy { $0.isEmpty } || candidateFontSize != 17 || candidateScale != 1
    }
    private var appearancePreview: some View {
        let bg = appearanceColor(candidateBackground, fallback: isArmPreset ? "4D4D4D" : "000000")
        let highlight = appearanceColor(candidateHighlight, fallback: isArmPreset ? "00D7E6" : "7A007A")
        let text = appearanceColor(candidateText, fallback: "FFFFFF")
        let selected = appearanceColor(candidateSelectedText, fallback: isArmPreset ? "4D4D4D" : "FFFFFF")
        let accent = appearanceColor(candidateAccent, fallback: isArmPreset ? "00D7E6" : "CCCCCC")
        return VStack(spacing: 0) {
            HStack { Text("▲"); Spacer() }.font(.system(size: 10)).foregroundStyle(accent).padding(.horizontal, 9).frame(height: 18)
            ForEach(Array(["鍵", "盤", "輸入"].enumerated()), id: \.offset) { index, word in
                HStack(spacing: 5) {
                    Text("\(index + 1)").font(.system(size: 11)).foregroundStyle(text).frame(width: 16, height: 16).background(bg, in: Circle())
                    Text(word).font(.custom("NotoSansTC-Regular", size: candidateFontSize)).foregroundStyle(index == 0 ? selected : text)
                    Spacer(minLength: 8)
                }.padding(.leading, 3).frame(height: max(25, candidateFontSize + 8)).background(index == 0 ? highlight : bg)
            }
            HStack { Text("▼"); Spacer(); Text("1/3") }.font(.system(size: 10)).foregroundStyle(accent).padding(.horizontal, 9).frame(height: 22)
        }.frame(width: max(88, candidateFontSize * 2 + 36)).background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(accent, lineWidth: 1))
            .scaleEffect(candidateScale, anchor: .topLeading)
            .frame(width: max(88, candidateFontSize * 2 + 36) * candidateScale, height: (3 * max(25, candidateFontSize + 8) + 40) * candidateScale, alignment: .topLeading)
            .accessibilityLabel("選字外觀預覽")
    }
    @AppStorage("mode") private var mode = "cangjie"
    @AppStorage("cangjieLearning") private var cangjieLearning = true
    @AppStorage("simplexLearning") private var simplexLearning = false
    @AppStorage("extendedCharacters") private var extendedCharacters = false
    @AppStorage("associatedPhrases") private var associatedPhrases = true
    @AppStorage("phraseModifier") private var phraseModifier = 8
    private var phraseKeyPrefix: String {
        switch phraseModifier { case 4: return "Control＋"; case 2: return "Option＋"; case 16: return "Command＋"; case 0: return ""; default: return "Shift＋" }
    }
    @AppStorage("simplifiedOutput") private var simplifiedOutput = false
    @AppStorage("fullWidthOutput") private var fullWidthOutput = false
    @State private var status = ""
    @State private var confirmReset = false
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(nsImage: NSImage(named: "ArmKeyKey") ?? NSApp.applicationIconImage)
                        .resizable().scaledToFit().frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ArmKeyKey").font(.headline)
                        Text("熟悉的輸入體驗").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 18).padding(.top, 22)
                List(selection: $navigation.selection) {
                    Section("偏好設定") {
                        sidebar("輸入與輸出", "keyboard", "input")
                        sidebar("選字與外觀", "paintpalette", "appearance")
                        sidebar("個人選字資料", "externaldrive", "learning")
                        sidebar("安裝與使用", "arrow.down.app", "setup")
                    }
                    Section("關於") { sidebar("關於 ArmKeyKey", "info.circle", "about") }
                    Section("版權資訊") {
                        ForEach(LicenseEntry.entries) { item in
                            sidebar(item.name, item.symbol, "license-" + item.id)
                        }
                    }
                }.listStyle(.sidebar)
                Text("版本 \(version) · jr-everstar").font(.caption).foregroundStyle(.secondary).padding(20)
            }.frame(width: 232).background(.regularMaterial)
            Divider()
            if let entry = LicenseEntry.entries.first(where: { "license-" + $0.id == navigation.selection }) {
                LicenseDetailView(entry: entry)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        settingsContent
                        if !status.isEmpty { Text(status).font(.callout).textSelection(.enabled) }
                    }.padding(30).frame(maxWidth: 850, alignment: .leading).frame(maxWidth: .infinity)
                }.id(navigation.selection).background(Color(nsColor: .windowBackgroundColor))
            }
        }.tint(accent)
        .onChange(of: phraseModifier) { LearningStore.changed() }
        .onChange(of: associatedPhrases) { LearningStore.changed() }
        .onChange(of: mode) { LearningStore.changed() }
        .onChange(of: cangjieLearning) { LearningStore.changed() }
        .onChange(of: extendedCharacters) { LearningStore.changed() }
        .onChange(of: simplexLearning) { LearningStore.changed() }
        .alert("重設個人選字順序？", isPresented: $confirmReset) {
            Button("取消", role: .cancel) {}
            Button("重設", role: .destructive) { perform { try LearningStore.shared.replace(JSONEncoder().encode(Backup(format: 1, entries: []))) } }
        } message: { Text("這會移除兩種輸入法記住的選字偏好。如需保留，請先匯出備份。") }
    }
    private func sidebar(_ title: String, _ symbol: String, _ tag: String) -> some View {
        Label {
            Text(title)
        } icon: {
            if tag == "license-armkeykey" {
                Image(nsImage: NSImage(named: "ArmKeyKey") ?? NSApp.applicationIconImage)
                    .resizable().interpolation(.high).scaledToFit().frame(width: 18, height: 18)
            } else {
                Image(systemName: symbol)
            }
        }.font(.system(size: 13, weight: .medium)).padding(.vertical, 6).tag(tag)
    }
    private func hero(_ title: String, _ subtitle: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: symbol).font(.system(size: 27, weight: .light)).foregroundStyle(accent)
            Text(title).font(.system(size: 30, weight: .bold, design: .rounded))
            Text(subtitle).font(.system(size: 14)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(25)
            .background(LinearGradient(colors: [accent.opacity(0.09), Color(nsColor: .controlBackgroundColor)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
    }
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 14, weight: .semibold))
            Divider()
            content()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.07)))
    }
    private func hint(_ text: String) -> some View { Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
    @ViewBuilder private var settingsContent: some View {
        switch navigation.selection {
        case "appearance":
            hero("選字與外觀", "調整選字風格，讓輸入更合心意。", "paintpalette")
            card("選字視窗") {
                Picker("外觀預設", selection: Binding(get: { candidateStyle }, set: { candidateStyle = $0; resetAppearance() })) {
                    Text("Yahoo KeyKey（預設）").tag("yahoo")
                    Text("ArmKeyKey").tag("everstar")
                }.pickerStyle(.segmented)
                HStack(alignment: .top, spacing: 28) {
                    appearancePreview
                    VStack(alignment: .leading, spacing: 12) {
                        Text(customAppearance ? "自訂外觀" : "預設外觀").font(.headline)
                        hint("選擇 preset 會套用整套配色及大小。你可以再按喜好微調，設定會自動儲存，下次顯示選字窗時生效。")
                        Button("還原目前 preset", action: resetAppearance)
                    }
                }.padding(.vertical, 8)
                ColorPicker("背景顏色", selection: colorBinding($candidateBackground, fallback: isArmPreset ? "4D4D4D" : "000000"), supportsOpacity: false)
                ColorPicker("選中背景（Highlight）", selection: colorBinding($candidateHighlight, fallback: isArmPreset ? "00D7E6" : "7A007A"), supportsOpacity: false)
                ColorPicker("文字顏色", selection: colorBinding($candidateText, fallback: "FFFFFF"), supportsOpacity: false)
                ColorPicker("選中文字顏色", selection: colorBinding($candidateSelectedText, fallback: isArmPreset ? "4D4D4D" : "FFFFFF"), supportsOpacity: false)
                ColorPicker("邊框與頁碼顏色", selection: colorBinding($candidateAccent, fallback: isArmPreset ? "00D7E6" : "CCCCCC"), supportsOpacity: false)
                HStack {
                    Text("選字列表大小")
                    Slider(value: $candidateScale, in: 0.8...1.6, step: 0.05)
                    Text("\(Int((candidateScale * 100).rounded()))%").monospacedDigit().frame(width: 48)
                }
                HStack {
                    Text("選字字體大小")
                    Slider(value: $candidateFontSize, in: 12...28, step: 1)
                    Text("\(Int(candidateFontSize)) pt").monospacedDigit().frame(width: 48)
                }
                hint("列表大小會縮放整個選字窗；字體大小只調整候選文字，行高會自動配合。")
                Divider()
                Toggle("顯示完整擴充字集", isOn: $extendedCharacters)
                hint("倉頡／速成預設使用相容字集。開啟擴充字集會增加罕用字及選字頁數。")
            }
            card("聯想詞") {
                Toggle("選字後顯示聯想詞", isOn: $associatedPhrases)
                Picker("聯想詞修飾鍵", selection: $phraseModifier) {
                    Text("Shift（預設）").tag(8); Text("Control").tag(4); Text("Option").tag(2)
                    Text("Command").tag(16); Text("無需修飾鍵").tag(0)
                }.disabled(!associatedPhrases)
                hint("例如選「我」後可選「我們」。\(phraseKeyPrefix)1–9 選詞，\(phraseKeyPrefix)空白鍵下一頁；繼續輸入或按 Esc 收起。")
            }
        case "learning":
            hero("個人選字資料", "記住你的選擇，資料只留在這部 Mac。", "externaldrive")
            card("學習偏好") {
                Toggle("記住倉頡選字順序", isOn: $cangjieLearning)
                Toggle("記住速成選字順序", isOn: $simplexLearning)
                hint("根據你明確選取的候選字，調整日後的選字順序。")
            }
            card("備份與還原") {
                hint("匯出備份可以保留個人選字順序。匯入會取代倉頡與速成目前的學習資料。")
                HStack { Button("匯出⋯", action: exportBackup); Button("匯入⋯", action: importBackup); Spacer(); Button("重設⋯", role: .destructive) { confirmReset = true } }
            }
            hint("不需要帳號、不連線，也不記錄輸入內容。")
        case "setup":
            hero("安裝與使用", "幾個簡單步驟，開始使用 ArmKeyKey。", "arrow.down.app")
            card("加入輸入來源") {
                hint("按下方按鈕安裝並加入輸入來源，然後從選單列選擇 ArmKeyKey。手動加入時，請在鍵盤設定選擇「中文（繁體）」。若清單尚未更新，請登出後重新登入。")
                Button("安裝並加入輸入來源") {
                    do { try Installation.install(); status = "已安裝並送出加入要求。若選單尚未顯示 ArmKeyKey，請登出後重新登入。" }
                    catch { status = error.localizedDescription }
                }.buttonStyle(.borderedProminent)
                Button("開啟鍵盤設定") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!) }
            }
            card("常用操作") {
                hint("使用 1–9 選字，空白鍵翻頁。按 Esc 取消本次組字。")
                hint("Control＋Command＋G 切換繁／簡。Shift＋Command＋空白鍵 切換全形／半形。")
            }
        case "about":
            hero("關於 ArmKeyKey", "熟悉的輸入體驗，全新的 Mac。", "info.circle")
            card("ArmKeyKey") {
                HStack(spacing: 18) {
                    Image(nsImage: NSImage(named: "ArmKeyKey") ?? NSApp.applicationIconImage).resizable().scaledToFit().frame(width: 76, height: 76)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("版本 \(version)").font(.title3.bold())
                        Text("倉頡、速成與廣東話拼音（粵拼）").foregroundStyle(.secondary)
                        Text("© 2026 jr-everstar").textSelection(.enabled)
                    }
                }
                Divider()
                hint("為 Apple Silicon Mac 打造的原生輸入法，結合熟悉的選字方式與現代 macOS 介面。")
            }
            card("開源與致謝") {
                hint("ArmKeyKey 原創部分採用 BSD 3-Clause，並使用 OpenVanilla、YahooKeyKey 及 Rime Cantonese 等開源成果。感謝所有貢獻者。")
                Button("查看版權資訊") { navigation.selection = "license-armkeykey" }
            }
        default:
            hero("輸入與輸出", "選擇輸入方式與文字格式。", "keyboard")
            card("輸入方式") {
                Picker("輸入法", selection: $mode) { Text("倉頡").tag("cangjie"); Text("速成").tag("simplex"); Text("廣東話拼音（粵拼）").tag("jyutping") }
                if mode == "jyutping" { hint("輸入 neihou 或 nei5hou2，按空白鍵開選字，再按 1–9 選字。可用 ' 分隔音節；聲調須全部輸入或全部省略。") }
                else { hint("使用 1–9 選字。空白鍵與方向鍵保留原輸入法的操作方式。") }
            }
            card("文字格式") {
                Toggle("繁體中文轉換為簡体", isOn: $simplifiedOutput)
                hint("Control＋Command＋G 切換繁／簡；套用至候選字、聯想詞及新輸入的文字。")
                Divider()
                Toggle("全碼文字（全形）", isOn: $fullWidthOutput)
                hint("Shift＋Command＋空白鍵 切換全形／半形，例如 ABC 123 → ＡＢＣ　１２３。")
                hint("快捷鍵切換後會顯示本機通知。請在 macOS「系統設定 → 通知 → ArmKeyKey」允許通知及橫額。")
            }
        }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); status = tr("完成。") } catch { status = tr("操作失敗，請檢查檔案後再試一次。備份必須是 ArmKeyKey JSON 檔案。") }
    }
    private func exportBackup() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.title = "匯出選字備份"; panel.prompt = "儲存"; panel.nameFieldStringValue = "ArmKeyKey-選字備份.json"
        if panel.runModal() == .OK, let url = panel.url { perform { try LearningStore.shared.exportData().write(to: url, options: .atomic) } }
    }
    private func importBackup() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.title = "匯入選字備份"; panel.prompt = "開啟"; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let alert = NSAlert(); alert.messageText = tr("取代個人選字順序？"); alert.informativeText = tr("匯入會取代兩種輸入法的選字偏好，請先匯出備份。"); alert.addButton(withTitle: tr("匯入⋯")); alert.addButton(withTitle: tr("取消"))
            if alert.runModal() == .alertFirstButtonReturn { perform { try LearningStore.shared.replace(Data(contentsOf: url)) } }
        }
    }
}

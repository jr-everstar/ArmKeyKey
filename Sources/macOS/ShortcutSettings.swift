import SwiftUI
import AppKit

struct ShortcutSettings: View {
    @State private var recording: String?
    @State private var revision = 0
    private let actions = [("simplifiedOutput", "繁體／簡體"), ("fullWidthOutput", "半形／全形"), ("associatedPhrases", "聯想詞開關")]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(actions, id: \.0) { action, title in
                HStack {
                    Text(title)
                    Spacer()
                    Text(AKShortcuts.display(forAction: action)).monospaced().id("\(action)-\(revision)")
                    Button("修改…") { recording = action }
                        .accessibilityLabel("修改\(title)快捷鍵")
                    Button("清除") { AKShortcuts.clearAction(action); revision += 1 }
                        .accessibilityLabel("清除\(title)快捷鍵")
                }
            }
            Button("還原所有快捷鍵預設") { AKShortcuts.restoreDefaults(); revision += 1 }
            Text("只在使用 ArmKeyKey 輸入時生效。聯想詞開關預設無快捷鍵，與選詞用的修飾鍵分開設定。鍵位按 ANSI 鍵盤位置記錄；macOS 或其他 App 已佔用的快捷鍵可能無法送達輸入法。")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sheet(isPresented: Binding(get: { recording != nil }, set: { if !$0 { recording = nil } })) {
            if let action = recording {
                ShortcutRecorder(action: action, title: actions.first { $0.0 == action }!.1) {
                    recording = nil; revision += 1
                }
            }
        }
    }
}

private struct ShortcutRecorder: View {
    let action: String
    let title: String
    let finished: () -> Void
    @State private var monitor: Any?
    @State private var message = "按下新組合：Control 或 Command，加英文字母、數字、標點或空白鍵。可加 Shift 或 Option。"
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("設定\(title)快捷鍵").font(.headline)
            Text(message).fixedSize(horizontal: false, vertical: true)
            Text("按 Esc 取消；成功記錄後即時儲存。").foregroundStyle(.secondary)
            HStack { Spacer(); Button("取消", action: finished) }
        }.padding(24).frame(width: 440)
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard NSApp.keyWindow?.isSheet == true else { return event }
                    if event.keyCode == 53 { finished(); return nil }
                    if event.isARepeat { return nil }
                    if let error = AKShortcuts.setAction(action, keyCode: Int(event.keyCode), modifiers: event.modifierFlags.rawValue) {
                        message = error
                    } else { finished() }
                    return nil
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}

import AppKit
import SwiftUI
import UserNotifications

@MainActor final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    @Published var release: UpdateRelease?
    @Published var status = "尚未檢查更新。"
    @Published var busy = false
    @Published var progress: Double?
    @Published var package: URL?
    private var operation: Task<Void, Never>?
    private var downloadID: UUID?
    private var timer: Timer?
    private let defaults = UserDefaults.standard
    var currentBuild: Int { Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? Int.max }
    var systemVersion: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }
    func start() {
        defaults.register(defaults: ["automaticallyCheckUpdates": true])
        AKFeatureNotifications.configure()
        check(manual: false)
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in self.check(manual: false) }
        }
    }
    func check(manual: Bool) {
        guard !busy else { return }
        if !manual && !UpdateSchedule.due(enabled: defaults.bool(forKey: "automaticallyCheckUpdates"),
                                         lastAttempt: defaults.object(forKey: "updateLastAttempt") as? Date, now: Date()) { return }
        defaults.set(Date(), forKey: "updateLastAttempt")
        busy = true; status = "正在檢查更新⋯"
        operation = Task {
            defer { busy = false; operation = nil }
            do {
                let feed = try await UpdateTransport.feed()
                try Task.checkCancellation()
                let candidate = feed.newest(currentBuild: currentBuild, system: systemVersion)
                if candidate != release { clearPackage() }
                release = candidate
                defaults.set(Date(), forKey: "updateLastSuccess")
                guard let candidate else {
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["ArmKeyKey.update"])
                    status = "目前沒有適用於這部 Mac 的較新版本。"; return
                }
                status = "有新版本 \(candidate.version)（build \(candidate.build)）。"
                if UpdateSchedule.shouldNotify(manual: manual, enabled: defaults.bool(forKey: "automaticallyCheckUpdates"),
                                               build: candidate.build, skipped: defaults.integer(forKey: "updateSkippedBuild"),
                                               notified: defaults.integer(forKey: "updateNotifiedBuild")) {
                    let center = UNUserNotificationCenter.current()
                    let authorization = await center.notificationSettings().authorizationStatus
                    if (authorization == .authorized || authorization == .provisional), defaults.bool(forKey: "automaticallyCheckUpdates") {
                        let content = UNMutableNotificationContent()
                        content.title = "ArmKeyKey 有新版本"
                        content.body = "\(candidate.version) 已推出。按此查看更新內容；由你決定是否下載。"
                        do {
                            try await center.add(UNNotificationRequest(identifier: "ArmKeyKey.update", content: content, trigger: nil))
                            defaults.set(candidate.build, forKey: "updateNotifiedBuild")
                        } catch { /* Keep the update available even if notifications fail. */ }
                    }
                }
            } catch is CancellationError { status = "已取消。" }
            catch { status = "檢查更新失敗，請稍後重試。" }
        }
    }
    func skip() {
        if let release { defaults.set(release.build, forKey: "updateSkippedBuild") }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["ArmKeyKey.update"])
        status = "已略過此版本的自動通知；仍可手動下載。"
    }
    func cancel() { status = "正在取消⋯"; operation?.cancel() }
    private func clearPackage() {
        if let package { try? FileManager.default.removeItem(at: package.deletingLastPathComponent()) }
        package = nil
    }
    func download() {
        guard !busy, let release else { return }
        busy = true; progress = 0; status = "正在下載 \(release.version)⋯"; clearPackage()
        let identifier = UUID(); downloadID = identifier
        operation = Task {
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ArmKeyKey/Updates/" + UUID().uuidString)
            var keep = false
            defer {
                busy = false; progress = nil; operation = nil; downloadID = nil
                if !keep { try? FileManager.default.removeItem(at: directory) }
            }
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let file = directory.appendingPathComponent("ArmKeyKey-\(release.version)-build\(release.build).pkg")
                try await UpdateTransport.download(release, to: file) { value in
                    Task { @MainActor in
                        if self.downloadID == identifier { self.progress = value }
                    }
                }
                try Task.checkCancellation()
                status = "正在驗證安裝包簽署及公證⋯"
                try await Task.detached { try UpdateInstaller.validate(file, release: release) }.value
                try Task.checkCancellation()
                package = file; keep = true
                status = "下載及驗證完成。請先儲存工作，再準備安裝。"
            } catch is CancellationError { status = "已取消下載。" }
            catch { status = error is UpdateFailure ? error.localizedDescription : "下載失敗，請重試。" }
        }
    }
    func install() {
        guard !busy, let release, let package else { return }
        do {
            try UpdateInstaller.requireOtherInputSource()
            try UpdateInstaller.handoff(package: package, release: release)
        } catch { status = error.localizedDescription }
    }
    func quitForManualInstall() {
        do { try UpdateInstaller.requireOtherInputSource(); NSApp.terminate(nil) }
        catch { status = error.localizedDescription }
    }
    func requestNotifications() {
        Task {
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert])
            let auth = await center.notificationSettings().authorizationStatus
            status = auth == .authorized ? "更新通知已允許。" : "未允許通知；仍可手動檢查更新。可在系統設定的通知頁啟用。"
        }
    }
}

struct UpdatesView: View {
    @ObservedObject private var updater = UpdateManager.shared
    @AppStorage("automaticallyCheckUpdates") private var automatic = true
    @State private var confirmInstall = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("軟件更新").font(.system(size: 30, weight: .bold, design: .rounded))
            Text("現有版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") · build \(updater.currentBuild)")
                .foregroundStyle(.secondary)
            Toggle("自動檢查更新", isOn: $automatic)
            Text("App 運行時每日最多檢查一次。有新版時顯示通知，由你決定是否下載及安裝。")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("檢查更新") { updater.check(manual: true) }.disabled(updater.busy)
                Button("允許更新通知") { updater.requestNotifications() }
            }
            if let last = UserDefaults.standard.object(forKey: "updateLastSuccess") as? Date {
                Text("上次成功檢查：\(last.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
            }
            Text(updater.status).textSelection(.enabled).accessibilityIdentifier("update-status")
            if let progress = updater.progress {
                ProgressView(value: progress)
                Button("取消下載") { updater.cancel() }
            }
            if let release = updater.release {
                Divider()
                Text("\(release.version) · build \(release.build)").font(.title2.bold())
                Text(release.notes).textSelection(.enabled)
                Text("需要 macOS \(release.minimumSystemVersion) 或以上 · \(ByteCountFormatter.string(fromByteCount: release.package.size, countStyle: .file))")
                    .font(.caption).foregroundStyle(.secondary)
                if let package = updater.package {
                    Text("安裝會退出 ArmKeyKey，需要管理員授權，完成後需登出再登入。其他帳戶若仍在使用，安裝程式會要求先退出。")
                    Button("準備安裝⋯") { confirmInstall = true }.buttonStyle(.borderedProminent).disabled(updater.busy)
                    Button("在 Finder 顯示安裝包") { NSWorkspace.shared.activateFileViewerSelecting([package]) }
                    if FileManager.default.fileExists(atPath: UpdateInstaller.personalInstallation.path) {
                        Text("安裝程式會自動備份並移走舊個人版 App，保留學習資料及設定。").foregroundStyle(.secondary)
                        Button("顯示個人安裝位置") { NSWorkspace.shared.activateFileViewerSelecting([UpdateInstaller.personalInstallation]) }
                        Button("退出 ArmKeyKey，稍後手動安裝") { updater.quitForManualInstall() }
                    }
                } else {
                    HStack {
                        Button("下載更新") { updater.download() }.buttonStyle(.borderedProminent).disabled(updater.busy)
                        Button("略過此版本提醒") { updater.skip() }.disabled(updater.busy)
                    }
                }
            }
            Divider()
            Text("檢查更新會連接 GitHub。輸入內容及個人選字資料不會上傳。網絡失敗不影響打字。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: automatic) { if automatic { updater.check(manual: false) } }
        .confirmationDialog("開始安裝更新？", isPresented: $confirmInstall) {
            Button("退出 ArmKeyKey 並開啟安裝程式") { updater.install() }
            Button("取消", role: .cancel) {}
        } message: { Text("請先儲存其他 App 的工作，並從選單列切換至其他輸入法。安裝完成後需要登出。") }
    }
}

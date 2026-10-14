# 開發指南

每次準備或發佈新版本，必須完成 [發版 checklist](ReleaseChecklist.md)，並由
[範本](Releases/TEMPLATE.md) 建立逐版本 publication record，涵蓋文件、GitHub Release、
GitHub Pages／stable feed 同獨立 Homebrew tap；未完成項目須明確記錄。

ArmKeyKey 以 C++20 引擎配合原生 macOS 介面，支援 Apple Silicon、macOS 26 或以上。目前功能及專案介紹見 [README](../README.md)，歷史版本改動見 [CHANGELOG](../CHANGELOG.md)。

## Build and test

需要 Xcode（macOS 26 或更新嘅 SDK）、命令列工具及 Python 3。喺 repository 根目錄執行：

```sh
Scripts/test.sh
Scripts/build.sh
open build/Build/Products/Release/ArmKeyKey.app --args --settings
```

亦可開啟 `ArmKeyKey.xcodeproj`。產生專案嘅來源係 `Scripts/generate_project.py`；修改專案設定時應同步修改產生器。只建置 arm64，Bundle ID 為 `everstar.inputmethod.armkeykey.mac`。

字典來源及獨立舊引擎測試基準已固定喺 repo，唔需要外部 YahooKeyKey 壓縮檔。原生控制器測試需要已登入嘅 macOS 圖形工作階段；使用 mock text client，唔會切換系統輸入來源，亦唔代表已完成真實跨 App 測試。

`Scripts/test.sh` 檢查來源 checksum、第三方聲明、字典 schema／metadata／全部資料及排序、同一 SQLite runtime 內重建嘅 byte 一致性、引擎 sanitizer 測試、舊引擎對照、學習資料備份及回滾、字集篩選、聯想詞、粵拼及安裝路徑。唔同 SQLite runtime 嘅檔案 header 可以唔同，所以跨 runtime 比較資料內容而非整個檔案嘅 bytes。

`Scripts/check-legacy-inputs.py` 會按 `Vendor/legacy-inputs-manifest.json` 核對 37 個來源檔案；唔好為咗令測試通過而直接重設基準 checksum。粵拼來源由 `Vendor/RimeCantonese/manifest.json` 固定，建置離線產生資料庫；只有明確執行 `Scripts/fetch-cantonese.py` 先會下載來源。

## Local installation

自行建置嘅 App 以 ad-hoc 簽署供本機測試。開啟 App 按「安裝並加入輸入來源」，或執行 `Scripts/install-local.sh`，會安裝至 `~/Library/Input Methods/ArmKeyKey.app`，唔需要管理員權限，亦唔會覆蓋已有版本。

到「系統設定 → 鍵盤 → 文字輸入 → 編輯 → ＋ → 繁體中文」加入 ArmKeyKey；如未出現，登出再登入。註冊 API 成功唔代表系統已啟用輸入來源，仍需喺設定加入。

更新本機開發版本：先選另一個輸入來源、關閉 ArmKeyKey 設定，將舊 App 移至垃圾桶，再執行安裝腳本及登出／登入。移除時亦先切換輸入來源，再從鍵盤設定移除 ArmKeyKey 及刪除 App。

學習資料留喺 `~/Library/Application Support/ArmKeyKey`，移除 App 唔會自動刪除。可喺設定匯出備份或重設；格式 2 匯入會取代三代、五代、速成及智慧注音嘅學習資料；格式 1 只取代三代與速成，保留新模式記錄，請先備份。匯入會驗證格式、數量、重複項目及字典成員，並以 SQLite transaction 處理，失敗會回滾。

PKG 安裝至共用嘅 `/Library/Input Methods/ArmKeyKey.app`，與本機開發安裝路徑不同。請跟[安裝包說明](Distribution.md#signed-pkg-installer)，避免同時保留兩份安裝。

## Architecture

- `Sources/Engine`：沿用嘅 C++ generic engine、選字狀態機、按鍵事件及狀態快照。
- `Sources/macOS`：Objective-C++ InputMethodKit controller、AppKit 非啟用式選字窗及 SwiftUI 設定。每個 controller 有獨立組字狀態。
- `Resources`：字典、字型及授權聲明；字典以明確序號保留選字順序，個人學習資料另外儲存。
- `Tests/Fixtures/LegacyEngine`：獨立編譯嘅原始舊引擎，用作行為對照。
- `site/`：網站及更新 feed，由 GitHub Pages workflow 部署。0.8.0 起由 App 內更新器讀取 stable feed。

設定及輸入選單採用繁體中文。候選字型使用隨 App 附帶嘅 Noto Sans TC，未涵蓋字元交由系統後備字型處理。輸入模式行為及限制見[相容性說明](Compatibility.md)。

## Repository hygiene

Repository 根目錄係包含 `ArmKeyKey.xcodeproj` 嘅目錄。原始舊版壓縮檔如需保留，應放喺 Git 之外。`Resources` 嘅 SQLite 檔案係字典，唔係個人學習記錄。

本機發佈備忘及設定放 `.local/`，憑證放 Keychain，學習匯出放 `.local/` 或 `learning-exports/`。唔好將個人 Application Support 資料、簽署金鑰、安裝包或 build 產物加入 Git。

提交前執行 `python3 Scripts/check-public-files.py`，並檢查 `git status --short` 及 staged diff。掃描器係輔助檢查，唔保證識別所有敏感資料；`.gitignore` 亦唔會移除已提交嘅檔案。

## Release tooling

`python3 Scripts/publish-release.py --help` 說明本機 PKG 驗證及發佈流程。預設只作預覽／驗證；`--publish` 上傳已驗證安裝包並預設建立 stable-feed PR；獲 maintainer 授權可加 `--feed-mode direct` 直接更新 main。`--build` 配合 `--publish` 執行建置、簽署及公證流程。前置條件、驗收清單及重試方式見[發佈指南](Distribution.md#local-release-command)。

## Update architecture

`UpdateManifest.swift` validates feed entries and update policy; `UpdateTransport.swift` handles bounded, cancellable network requests; `UpdateInstaller.swift` verifies packages and implements the parent-exit handoff; `Updates.swift` owns state, notifications and the settings page. `main.swift` handles installer handoff before initializing InputMethodKit. `Scripts/test.sh` includes offline updater tests.

## Contribution and release workflow

Contributors branch from current `main` with a feature name such as `feature/soft-updates`, commit the implementation and relevant tests, then open a PR. Feature PRs do not choose the next release number or announce a release. The maintainer reviews and merges, then prepares a separate version/documentation commit and release PR.

For 0.9.1, release preparation sets version 0.9.1/build 18 and fixes installation when the input method relaunches in the background. Publish from the clean pushed source commit, verify the new signed/notarized PKG, then update the feed, website and dedicated Homebrew tap with its final checksum. Historical 0.8.0 acceptance remains unchanged; record new checks and remaining manual-test limitations separately. No PKG, signing key or local settings file belongs in Git.

## 0.9.0 input architecture

The mode enum explicitly selects Generic (Cangjie 3/5 or Simplex), Jyutping, or the new Zhuyin adapter. `ZhuyinEngine.hpp` uses the pinned McBopomofo Mandarin parser and Gramambular2 ReadingGrid, backed by a read-only `Mandarin.sqlite3`. The adapter implements key handling and a separate SQLite learning store. Production and tests compile as C++20.

`Scripts/build-new-inputs.py` verifies both new vendor manifests before building. It adds the Hong Kong Cangjie table to the freshly generated legacy dictionary and runs the required upstream Python compilers in a temporary copy, never editing vendor inputs. Normal builds need no downloads or Python third-party packages. Unsupported non-aligned phonetic mappings are reported individually; macros are not exposed.

Composition selection ranges are UTF-8 byte offsets in engine state and explicitly converted to UTF-16 for InputMethodKit. ReadingGrid indices are syllable positions; imported Mandarin values must have one Unicode scalar per syllable. Smart learning applies a bounded score bonus only to existing reading/value entries and records explicit overrides surviving the final committed walk. It does not implement McBopomofo's context override model or its user-phrase editor.

Run `Scripts/test.sh` for the old-engine differential tests plus new-mode, backup-v2, UTF-16 controller and reproducible-data tests. The legacy fixtures remain untouched. The 0.9.0 maintainer workflow directly merges `feature/0.9.0-input-methods` into main, without a PR, as explicitly requested. The follow-up installer hotfix uses `feature/installer-relaunch-fix` and version 0.9.1/build 18.

## 0.9.2 shortcut feedback

`FeatureNotifications.swift` displays mode changes in a nonactivating AppKit panel at the upper right of the pointer's screen. Mode feedback does not request or depend on Notification Center authorization. The shared delegate still handles update notifications. Repeated toggles reuse one panel and restart its two-second dismissal task.

`Scripts/test-native.sh` runs both controller shortcut tests and the production Swift panel tests (state text, screen placement, focus preservation, reuse, and cancellation of an earlier dismissal). It requires a logged-in graphical session. Real input-source switching across apps, multiple displays and full-screen Spaces still needs manual acceptance.

`FirstLoginSetup.swift` is the short-lived first-login helper path. Installer tests cover fresh installs, upgrades, receipts, personal migration, stale pending markers and symlink rejection. A real fresh-account logout/login remains a manual acceptance check; automated tests do not log out the developer.

The first-login native regression test runs the real AppKit application loop and modal guide with stubbed registration/Settings opening, then checks persisted completion in a disposable home. Do not show the guide from top-level main before `applicationDidFinishLaunching`. Installer classification no longer relies on a receipt alone; build 20 repairs the missing-agent build 19 test case.

## 0.9.2 release workflow

Version 0.9.2/build 20 includes shortcut feedback and first-install guidance. The maintainer explicitly authorized commits/merges/pushes to both repositories’ main branches and the publisher’s `--feed-mode direct` for this release. See [publication record](Releases/0.9.2-publication.md) for source, signing, CI, feed/site and tap evidence. Earlier version-specific sections remain historical.


## v0.10.0 configurable shortcuts

`AKShortcuts` owns default bindings, physical-key matching, validation and local UserDefaults storage (`shortcut.simplifiedOutput`, `shortcut.fullWidthOutput`, `shortcut.associatedPhrases`). Absent keys use defaults; empty or malformed dictionaries disable a shortcut. `ShortcutSettings` records local key events only while its sheet is open, consumes the captured event, and removes its monitor on dismissal. Require Control or Command to avoid intercepting ordinary input. Duplicate bindings are rejected before saving.

The input controller reads settings on every event, ignores auto-repeat toggles and displays the current binding in its menu. Menu rows deliberately have no key equivalents: registering those would add a layout-dependent second shortcut dispatcher. Menu clicks and keyboard output toggles share feedback; the phrase toggle uses the existing commit/rebuild and dataGeneration invalidation path so other controllers reload. No global event monitor or Accessibility permission is used.

## v0.10.1 enhancement: update input-source preparation (unreleased)

`UpdateInputSourcePreparation` isolates selection policy from Carbon calls so updater tests can check enabled/selectable keyboard filtering, preferred/fallback choice, preserving an existing other source, missing sources, selection failure and post-selection verification without switching the real desktop. `UpdateInstaller` reads live TIS state and switches only in the confirmed handoff path. UpdatesView explains the target/source transition before confirmation. Target is 0.10.1/build 22; immutable 0.10.0/build 21 is unchanged.

Validation: updater regression fixtures and complete app build passed; diff check passed. Real installed-input-method/Installer handoff, cancellation and failure UI still require manual acceptance on a test account. No active-account input-source switch, installation or logout was performed during development.

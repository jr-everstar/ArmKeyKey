# ArmKeyKey

Native Apple Silicon input method for macOS 26 and later. Cangjie and Simplex preserve the YahooKeyKey/OpenVanilla table order and typing engine. Smart Zhuyin is deferred pending dictionary data and licensing.

**Status: local development build, not cleared for public distribution.** Build and tests use pinned inputs within this repository. See [verification and release status](Documentation/Verification.md).

目前版本：**0.7.2（build 14）**。更新紀錄見 [Changelog](CHANGELOG.md)。

## Build and test

Requires Xcode with the macOS 26 or newer SDK, its command-line tools, and Python 3. All dictionary inputs and the independent legacy test baseline are pinned inside this repository. A fresh clone can build and test without the original YahooKeyKey archive or network downloads. Native controller tests require a logged-in macOS graphical session.

```sh
cd ArmKeyKey
Scripts/test.sh
Scripts/build.sh
open build/Build/Products/Release/ArmKeyKey.app --args --settings
```

You can also open `ArmKeyKey.xcodeproj`. The generated project is checked in; `Scripts/generate_project.py` is its source of truth. Builds are arm64 only, with macOS 26.0 minimum. The bundle identifier is `everstar.inputmethod.armkeykey.mac`.

## Repository hygiene

The repository root is this directory (containing `ArmKeyKey.xcodeproj`), not its parent. An original legacy archive, if retained locally, belongs outside Git and is no longer a build/test dependency. Source, tests, design inputs, bundled dictionary databases, fonts and required license notices belong in the source tree. The databases under `Resources` contain dictionary data, not personal learning records.

Keep machine-specific release notes and settings in `.local/`, credentials in Keychain, and learning exports in `.local/` or `learning-exports/`. Never copy personal Application Support data into source folders. Build output, old app backups, logs, signing keys, certificates and installer packages are ignored. Signed installers belong in GitHub Releases after release checks pass.

Before staging or committing, run `python3 Scripts/check-public-files.py` and review `git status --short` and the staged diff. The checker scans tracked and untracked non-ignored files, reports paths rather than secret values, and fails if an ignored file was force-added. It is a heuristic check, not a guarantee that every possible secret or personal record is detected. `.gitignore` does not remove files already committed to history.

## Local installation

Open the app and click **安裝並加入輸入來源**, or run `Scripts/install-local.sh` after building. This copies the app to `~/Library/Input Methods/ArmKeyKey.app` without root privileges and refuses to overwrite an existing installation. The setup button copies the app to the supported location, calls TISRegisterInputSource and requests enablement. This does not change the currently selected input source. If system caches do not expose the new source immediately, log out and back in. Add ArmKeyKey under System Settings → Keyboard → Text Input → Edit → + (Traditional Chinese). Log out and back in if it is not listed. Choose Cangjie or Simplex in ArmKeyKey’s input menu or settings.

Local builds are ad-hoc signed for testing; they are not notarized public releases. Do not disable Gatekeeper or other macOS protections to install them.

To update: select another input source, close ArmKeyKey settings, move the existing app to Trash, run the install script, and log out/back in. To remove: select another input source, remove ArmKeyKey from Keyboard settings, and move the app to Trash. Learning remains in `~/Library/Application Support/ArmKeyKey`; reset it through settings if desired.

## Behavior

- Cangjie: five radicals maximum; conversion on Space/Return or an end key; frequency learning on by default.
- Simplex: automatic composition at two radicals; frequency learning off by default.
- A compatible character set is the default; enable 「顯示完整擴充字集」 to include supplementary-plane and private-use entries. The full dictionary is retained and relative candidate order is unchanged.
- Selection keys 1–9, original paging/highlight controls, punctuation and supported Cangjie wildcards.
- Learning records only explicitly selected non-first candidates, following the original engine.
- Settings, onboarding, and candidate controls use Traditional Chinese, regardless of the system language. Original third-party license notices retain their original wording.
- Export/import JSON replaces learned ordering for both modes. Export a backup before import/reset. Imports validate format, limits, duplicates, and membership in the bundled dictionary. Both modes are replaced in one SQLite transaction; failed imports roll back.

## Architecture

`Sources/Engine` adapts the retained C++ generic engine and candidate state machine into key events and state snapshots. `Sources/macOS` provides an Objective-C++ InputMethodKit controller, a nonactivating AppKit candidate panel, and SwiftUI settings. Each input controller owns its composition state. SQLite uses explicit dictionary sequence numbers; learning stays in per-mode local databases. No legacy plugin loader, network service, updater, or proprietary database extension is included.

The dictionary builder uses the original parser, including stable ordering among duplicate codes. `Scripts/test.sh` rebuilds the dictionary, compares all schema/metadata/rows and ordering against the bundled copy, verifies repeated builds byte for byte within the same SQLite runtime, checks all exact lookups, tests behavior under sanitizers, and compares traces against an independently compiled untouched source engine in `Tests/Fixtures/LegacyEngine`. `Vendor/LegacyTables` contains the two required original CIN inputs. `Scripts/check-legacy-inputs.py` verifies all 37 files against `Vendor/legacy-inputs-manifest.json` before building or testing; do not regenerate baseline checksums merely to make a failing test pass. This validates source behavior, not a historical installed app.

See [compatibility changes](Documentation/Compatibility.md), [privacy](Documentation/Privacy.md), [license audit](Documentation/LicenseAudit.md), and [distribution](Documentation/Distribution.md).

### 選字窗與聯想詞（0.4.0）

選字窗採用黑底直排、白字、紫色反白、上下翻頁箭頭及頁數。預設開啟「選字後顯示聯想詞」：例如選「我」後可選「我們」，只補上「們」。預設 Shift＋1–9 選詞、Shift＋空白鍵下一頁、Esc 收起；「聯想詞修飾鍵」可改為 Control、Option、Command 或「無需修飾鍵」，同時套用至選詞及空白鍵翻頁；繼續打字會直接開始下一個字。可在輸入法選單的「聯想字」或設定切換；選單剔號代表開啟，兩處共用並自動儲存同一設定。聯想詞目前是獨立編寫的常用詞初始詞庫，並非完整 YahooKeyKey 詞庫；速成原有排序及預設關閉的學習設定不變。

### 選字窗外觀設定（0.7.0）

在設定的「選字與外觀」可選 Yahoo KeyKey（預設）與 ArmKeyKey 兩個 preset。ArmKeyKey 使用深灰背景、青藍反白、17pt 候選字及 25pt 行高。可自訂背景、反白、一般文字、選中文字、邊框與頁碼顏色，列表縮放 80–160%，候選字體 12–28pt（行高自動配合）。設定頁提供即時示意預覽，修改自動儲存，下次顯示候選窗時套用，包括聯想詞。切換 preset 或按「還原目前 preset」會重設外觀調整。

### 廣東話拼音與擴充聯想詞（0.5.0）

在設定或 ArmKeyKey 輸入法選單選「廣東話拼音（粵拼）」。輸入 `neihou` 或 `nei5hou2`，按空白鍵，再按數字選「你好」。`ngo5dei6` 可選「我哋」。可用單引號分隔音節；聲調須全部輸入或全部省略。選字頁以空白鍵翻頁、Return 確認、Esc 取消、退格返回修改。此版是整詞查找，尚未提供整句自動組詞或模糊音。

所有模式的聯想詞已擴充至約 10.2 萬個字詞，使用 Rime Cantonese 的詞頻排序，全程離線。「我」目前有 348 個聯想詞。詞庫來源、固定版本、修改說明及 CC BY 4.0 授權隨程式附上。倉頡／速成原本的選字順序不變。

建置會離線核對 `Vendor/RimeCantonese/manifest.json` 並產生 `Resources/Cantonese.sqlite3`。只有明確執行 `Scripts/fetch-cantonese.py` 才會下載固定版本來源，程式執行時不會下載資料。

## License and third-party components

Original ArmKeyKey contributions are licensed under [BSD 3-Clause](LICENSE), copyright © 2026 jr-everstar. Third-party code and data retain their respective licenses. See the [dependency inventory](Documentation/Dependencies.md) and [bundled notices](Resources/ThirdPartyNotices.txt). The unified settings sidebar includes input/output, appearance, learning data, installation, About and copyright pages. The input menu provides「ArmKeyKey 設定⋯」、「關於 ArmKeyKey…」and「版權資訊…」entries; About and copyright open the matching page in the same window. License pages include component credits, full selectable terms and copy controls.

This implementation directly reuses OpenVanilla/PlainVanilla code from the YahooKeyKey source distribution; it is not a wholly clean-room rewrite. Historical Cangjie/Simplex table redistribution rights remain unresolved, so the project code license does not clear the current app for public distribution.

### 繁簡與全碼文字（0.6.0）

- Control＋Command＋G：切換繁體／簡體輸出，預設繁體。候選字、聯想詞及送出的文字會同步轉換；字典及學習仍保留原本字形。
- Shift＋Command＋空白鍵：切換半形／全形，預設半形。英文字母、數字、ASCII 標點及空格會轉為全形，例如 ABC 123 → ＡＢＣ　１２３；倉頡、速成及粵拼的組字和選字鍵照常使用。
- 兩項亦可在輸入法選單或設定切換，並自動儲存。快捷鍵只在 ArmKeyKey 啟用時生效，切換不會改動文件內既有文字。繁簡轉換使用 macOS 內建轉換，並非逐地區用語翻譯。

快捷鍵切換繁簡／全形後會發送本機通知，顯示功能開關及目前模式。首次使用會要求通知權限；通知是否顯示橫額由 macOS 通知設定及專注模式控制。通知不包含輸入內容。

### 內嵌候選字型（0.6.0）

候選字使用隨 App 附帶的 Noto Sans TC（SIL OFL 1.1），啟動時僅供 App 程序載入，無需另外安裝。字型及完整授權隨 App 打包，設定的版權頁提供來源與條款。此字型不涵蓋所有擴充漢字，未涵蓋字元優先逐字使用 macOS 內置 PingFang TC，再由系統選擇其他後備字型；PingFang TC 不隨 App 打包。

## 打包與 Apple 公證備忘

目前開發 Mac 的公證 Keychain profile 為 **`ArmKeyKey-Notarization`**（不是密碼）。重新打包前請參閱 [公證設定、用途及操作備忘](Documentation/Distribution.md)。安裝用戶及第二部測試 Mac 不需要設定這個 profile。

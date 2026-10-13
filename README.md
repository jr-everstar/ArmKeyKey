<p align="center">
  <img src="Design/armkeykey-logo-final.png" alt="ArmKeyKey" width="460">
</p>

<h3 align="center">用慣嘅倉頡、速成，繼續打落去。</h3>
<p align="center">香港團隊製作・倉頡／速成為主，配上廣東話拼音・原生 Apple Silicon</p>
<p align="center">
  <a href="https://jr-everstar.github.io/ArmKeyKey/">網站</a> ·
  <a href="https://github.com/jr-everstar/ArmKeyKey/issues">回報問題／傾功能</a> ·
  <a href="CHANGELOG.md">更新紀錄</a> ·
  <a href="Documentation/Development.md">開發指南</a>
</p>

## 點解會有 ArmKeyKey？

起因好簡單：升級咗 macOS，發現用咗咁多年嘅 Yahoo KeyKey 終於用唔到。

對我哋嚟講，輸入法係每日返工、覆訊息、寫嘢都會用到嘅工具。字根點打、候選字排第幾、手指幾時按落去，早就變成習慣。換部機、升級個系統之後，要連打字習慣都重新適應，總係有啲唔甘心。於是我哋就自己動手，整咗 ArmKeyKey。

我哋係香港團隊，所以由香港人常用嘅**倉頡同速成**開始，盡量保留 Yahoo KeyKey 熟悉嘅選字順序同操作手感，再配上**廣東話拼音（粵拼）**。識拆字就拆字，一時唔記得點拆，或者想打句「我哋」，就用廣東話打返出嚟。

最初只係 internal use，解決團隊自己每日打字嘅需要。一路用、一路執，到而家覺得已經成熟到值得拎出嚟同大家分享，所以將 repo 公開。希望同樣掛住 Yahoo KeyKey、關心香港人打字習慣，或者純粹鍾意改嘢嘅朋友，可以一齊試、一齊改、一齊玩。

## 而家有啲咩？

| 輸入方式 | 用法 |
| --- | --- |
| **倉頡** | 最多五碼，保留原有字表嘅相對選字順序；預設開啟選字學習。 |
| **速成** | 首尾兩碼自動組字；預設關閉學習，保留熟悉嘅排序。 |
| **廣東話拼音** | `neihou` 或 `nei5hou2` →「你好」，`ngo5dei6` →「我哋」；聲調可以全部輸入或全部省略。 |

- **離線聯想詞**：約 10.2 萬個字詞，揀完「我」可以接住揀「我們」，只補上未打嘅部分。
- **自己調選字窗**：Yahoo KeyKey／ArmKeyKey 兩款外觀，顏色、字體大小同縮放都可以改。
- **繁簡、半形／全形切換**：分別用 `Control + Command + G` 同 `Shift + Command + Space`，亦可喺選單設定。
- **學習記錄自己保管**：支援匯出、匯入同重設；資料留喺自己部 Mac。
- **繁體中文介面**：原生 macOS 設定同選字窗，無需帳戶，唔會上傳按鍵或選字內容。

粵拼目前支援整詞查找，未有整句自動組詞或模糊音。其他行為差異見[相容性說明](Documentation/Compatibility.md)，資料處理見[私隱說明](Documentation/Privacy.md)。

## 最新版本與試用

**0.8.0（build 15） · macOS 26 或以上 · Apple Silicon（M 系列）**

今次加入 Homebrew 安裝方法。App 內「軟件更新」繼續提供：可手動檢查，亦可每日自動檢查及接收提醒。下載同安裝由你決定，唔會自動取代正在使用嘅輸入法。版本改動統一放喺 [CHANGELOG](CHANGELOG.md)。公開 repo 方便大家參與開發；安裝包發佈狀態以 [GitHub Releases](https://github.com/jr-everstar/ArmKeyKey/releases) 為準。

0.7.2 或更舊版本未有更新功能，需要先從 GitHub Releases 手動下載安裝一次。安裝前儲存工作、切換至其他輸入來源，再按 Installer 指示完成登出。

### Homebrew 安裝

已安裝 [Homebrew](https://brew.sh/) 嘅話，可以直接執行：

```sh
brew tap jr-everstar/armkeykey https://github.com/jr-everstar/ArmKeyKey.git
brew install --cask jr-everstar/armkeykey/armkeykey
```

呢個係專案自訂 tap，使用同一份已簽署及公證嘅 PKG，安裝到 `/Library/Input Methods/ArmKeyKey.app`，需要管理員密碼。安裝／升級前請儲存工作、切換輸入來源及關閉 ArmKeyKey；如有個人安裝，先移走 `~/Library/Input Methods/ArmKeyKey.app`，保留學習資料。完成後請**自行登出再登入**，再到鍵盤設定加入 ArmKeyKey。

升級：

```sh
brew update
brew upgrade --cask --greedy jr-everstar/armkeykey/armkeykey
```

移除前先切換至其他輸入來源、關閉 ArmKeyKey，並在鍵盤設定移除輸入來源，再執行 `brew uninstall --cask jr-everstar/armkeykey/armkeykey`。學習資料及個人設定會保留。詳細說明見 [Homebrew 安裝](Documentation/Distribution.md#homebrew)。

### 自行建置

想自行建置試用，需要 Xcode（macOS 26+ SDK）、命令列工具同 Python 3：

```sh
git clone https://github.com/jr-everstar/ArmKeyKey.git
cd ArmKeyKey
Scripts/build.sh
open build/Build/Products/Release/ArmKeyKey.app --args --settings
```

開啟 App 後按「安裝並加入輸入來源」，再到「系統設定 → 鍵盤 → 文字輸入 → 編輯 → ＋ → 繁體中文」加入 ArmKeyKey。如未見到，登出再登入。自行建置嘅 App 使用本機測試簽署；安裝、更新及移除方法見[開發指南](Documentation/Development.md#local-installation)。PKG 使用者請跟[安裝包說明](Documentation/Distribution.md#signed-pkg-installer)。

## 一齊改，一齊玩

歡迎開 [Issue](https://github.com/jr-everstar/ArmKeyKey/issues) 傾用法、報 bug、提功能，亦歡迎直接交 PR。倉頡／速成嘅選字手感、廣東話字詞、唔同 App 入面嘅相容性，都好需要大家日常使用嘅經驗。

回報打字問題時，講埋 macOS 同 App 版本、用緊邊個輸入模式、打咗咩字碼、預期同實際結果，會容易跟進好多。例子用測試文字就得。

改程式前可以先睇[開發指南](Documentation/Development.md)；執行 `Scripts/test.sh` 跑測試。字典同舊引擎測試基準已放喺 repo，唔使另外搵 Yahoo KeyKey 原始壓縮檔。CI 詳情見 [CI 文件](Documentation/CI.md)，打包同公證見[發佈指南](Documentation/Distribution.md)。

## 致謝與授權

多謝 Yahoo KeyKey、OpenVanilla／PlainVanilla 留低嘅程式碼同多年累積嘅輸入體驗，亦多謝 Rime Cantonese 嘅廣東話字詞資料，以及 Noto Sans TC 字型。ArmKeyKey 直接沿用當中嘅引擎同資源，再為而家嘅 Mac 繼續改落去。

ArmKeyKey 原創部分採用 [BSD 3-Clause](LICENSE)；第三方程式碼、字表同字型保留各自授權。Maintainer 已確認今次發佈嘅字表權利及私隱審核完成；確認紀錄與歷史資料見[授權審核](Documentation/LicenseAudit.md)、[第三方聲明](Resources/ThirdPartyNotices.txt)及[依賴清單](Documentation/Dependencies.md)。

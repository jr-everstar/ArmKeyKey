<p align="center">
  <img src="Design/armkeykey-logo-final.png" alt="ArmKeyKey" width="460">
</p>

<h3 align="center">用慣嘅倉頡、速成，繼續打落去。</h3>
<p align="center">香港團隊製作・倉頡三／五代、速成、粵拼、傳統／智慧注音・原生 Apple Silicon</p>
<p align="center">
  <a href="https://jr-everstar.github.io/ArmKeyKey/#start">下載 PKG</a> ·
  <a href="https://jr-everstar.github.io/ArmKeyKey/">產品網站</a> ·
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
| **倉頡三代** | 最多五碼，保留原有字表嘅相對選字順序；預設開啟選字學習。 |
| **速成** | 首尾兩碼自動組字；預設關閉學習，保留熟悉嘅排序。 |
| **廣東話拼音** | `neihou` 或 `nei5hou2` →「你好」，`ngo5dei6` →「我哋」；聲調可以全部輸入或全部省略。 |
| **倉頡五代** | Jackchows 五代補完香港版，保留香港候選排序；例如「面」`mwsl`、「非」`lmsy`、「鬼」`hui`。 |
| **傳統注音** | 標準注音鍵盤，完成音節後逐字選字，選字即上屏。 |
| **智慧注音** | 連續組句、句中移動及改字，Return 提交；可在本機記住手動選取並提交嘅字詞。 |

- **離線聯想詞**：適用於倉頡、速成及粵拼，約 10.2 萬個字詞，揀完「我」可以接住揀「我們」，只補上未打嘅部分。
- **自己調選字窗**：Yahoo KeyKey／ArmKeyKey 兩款外觀，顏色、字體大小同縮放都可以改。
- **繁簡、半形／全形切換**：預設用 `Control + Command + G` 同 `Shift + Command + Space`，可自行修改、清除或還原，亦可喺選單切換。快捷鍵切換會喺滑鼠所在螢幕右上角顯示兩秒提示，毋須系統通知權限，唔會搶走輸入焦點。
- **學習記錄自己保管**：支援匯出、匯入同重設；資料留喺自己部 Mac。
- **繁體中文介面**：原生 macOS 設定同選字窗，無需帳戶，唔會上傳按鍵或選字內容。

粵拼目前支援整詞查找，未有整句自動組詞或模糊音。其他行為差異見[相容性說明](Documentation/Compatibility.md)，資料處理見[私隱說明](Documentation/Privacy.md)。

## 注音操作

傳統及智慧注音使用標準鍵盤：`su3` → ㄋㄧˇ，`cl3` → ㄏㄠˇ。一聲用空白鍵完成，二／三／四聲及輕聲分別用 `6`／`3`／`4`／`7`。候選窗開啟後 `1–9` 先係選字鍵。

智慧注音連續輸入 `su3cl3` 可以組成「你好」；左右鍵移動游標，向下或空白鍵開啟目前位置候選，選詞後仍留喺組字區，Return 提交整段。Home／End 移至頭尾，Backspace／Delete 刪字。Esc 依序關閉候選、取消未完成音節、取消整段。`Shift+,`／`Shift+.` 輸入中文逗號／句號。

智慧選詞學習預設開啟，可獨立關閉；傳統注音維持固定排序。新版備份涵蓋三代、五代、速成及智慧注音，舊備份仍可匯入，唔會清除新模式記錄。首版未提供其他注音鍵盤或自訂詞庫編輯器；組字上限為 128 音節。詳見[相容性說明](Documentation/Compatibility.md)。

## 自訂快捷鍵與狀態提示

**v0.10.0／build 21** 新增自訂快捷鍵。在「ArmKeyKey 設定 → 輸入與輸出 → 快捷鍵」可修改繁簡、全／半形及聯想詞開關的組合；按「修改」後按下新組合，亦可清除或還原所有預設。

| 功能 | 預設快捷鍵 |
| --- | --- |
| 繁體／簡體 | Control + Command + G |
| 半形／全形 | Shift + Command + Space |
| 聯想詞開關 | 無，按需要自行設定 |

快捷鍵只在使用 ArmKeyKey 輸入時生效，須包含 Control 或 Command，可配合 Shift／Option 及英文字母、數字、標點或空白鍵。以 ANSI 實體鍵位記錄；同一組合不可分配給兩個功能。Esc 取消修改。macOS 或其他 App 佔用的組合可能無法送達輸入法。聯想詞開關與「聯想詞修飾鍵」（選詞／翻頁用途）是分開的設定。三種切換都提供右上角狀態提示，跟隨選字表的 Yahoo KeyKey／ArmKeyKey 樣式、自訂配色、字體大小及縮放；兩秒後收起，不搶輸入焦點。

## v0.10.1 Enhancement

「準備安裝」確認後會自動切換至已啟用的鍵盤來源，再退出 ArmKeyKey 並開啟安裝程式，毋須自行找快捷鍵。取消不會切換；切換失敗會顯示原因。安裝完成後仍須登出再登入。

**v0.10.1／build 22** 改善 App 內更新準備流程。從舊版 App 升級到本版仍會使用舊版更新流程，可能需要先手動切換；安裝本版後，往後更新即可使用自動切換。

## 最新版本與試用

**0.10.1（build 22） · macOS 26 或以上 · Apple Silicon（M 系列）**

[**前往網站下載 PKG 安裝包**](https://jr-everstar.github.io/ArmKeyKey/#start) · [**產品網站**](https://jr-everstar.github.io/ArmKeyKey/) · [版本說明](https://github.com/jr-everstar/ArmKeyKey/releases/tag/v0.10.1-build22)

今次改善「準備安裝」：確認後自動切換輸入來源，再開啟安裝程式。自訂快捷鍵及帶 App 圖示嘅狀態提示繼續保留。首次安裝後嘅設定引導繼續保留。六種輸入模式繼續保留，升級唔會清除學習資料。App 內「軟件更新」繼續提供：可手動檢查，亦可每日自動檢查及接收提醒。下載同安裝由你決定，唔會自動取代正在使用嘅輸入法。版本改動統一放喺 [CHANGELOG](CHANGELOG.md)。公開 repo 方便大家參與開發；安裝包發佈狀態以 [GitHub Releases](https://github.com/jr-everstar/ArmKeyKey/releases) 為準。

0.7.2 或更舊版本未有更新功能，需要先從[產品網站](https://jr-everstar.github.io/ArmKeyKey/#start)手動下載安裝一次。安裝前儲存工作、切換至其他輸入來源，再按 Installer 指示完成登出。

### PKG 安裝後，帶你完成設定

首次安裝唔止係複製 App：完成 PKG 安裝並**登出再登入**後，ArmKeyKey 會自動開啟**鍵盤設定**，同時顯示一次性的歡迎指引：

1. 喺「文字輸入」按「編輯⋯」，再按「＋」。
2. 選「中文（繁體）」→「ArmKeyKey」→「加入」，再按「完成」。
3. 從螢幕右上角輸入選單選擇 ArmKeyKey，即可開始打字。

唔需要自己搵設定入口；加入同切換仍然由你決定。每個帳戶只提示一次，已啟用 ArmKeyKey 會略過，一般升級亦唔會重複提示。之後可從 ArmKeyKey「安裝與使用」頁重新開啟鍵盤設定。曾安裝 build 19 測試包但冇見到指引，可直接升級 build 20 修復，毋須先移除。

### Homebrew 安裝

已安裝 [Homebrew](https://brew.sh/) 嘅話，可以直接執行：

```sh
brew install --cask jr-everstar/armkeykey/armkeykey
```

Homebrew 會自動加入專案嘅 [獨立 tap](https://github.com/jr-everstar/homebrew-armkeykey)，使用同一份已簽署及公證嘅 PKG，安裝到 `/Library/Input Methods/ArmKeyKey.app`，需要管理員密碼。安裝／升級前請儲存工作及切換輸入來源；背景程序重新啟動不會阻擋安裝。共用 App 會備份至 `/Library/ArmKeyKey Installer Backup.*`；如有舊個人安裝，0.8.1 起會自動移至 `~/Library/ArmKeyKey Installer Backup.*`，保留學習資料及設定。完成後請**自行登出再登入**；首次安裝會自動開啟鍵盤設定及上述指引。

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

多謝 Yahoo KeyKey、OpenVanilla／PlainVanilla 留低嘅程式碼同多年累積嘅輸入體驗，亦多謝 Rime Cantonese 嘅廣東話字詞資料，Jackchows 倉頡五代補完、小麥注音與 libtabe 嘅核心／字庫，以及 Noto Sans TC 字型。ArmKeyKey 直接沿用當中嘅引擎同資源，再為而家嘅 Mac 繼續改落去。

ArmKeyKey 原創部分採用 [BSD 3-Clause](LICENSE)；第三方程式碼、字表同字型保留各自授權。新增五代資料採 MIT；小麥核心與資料保留 MIT 及繼承嘅 BSD 聲明。逐項來源及歷史審核見[授權審核](Documentation/LicenseAudit.md)、[第三方聲明](Resources/ThirdPartyNotices.txt)及[依賴清單](Documentation/Dependencies.md)。

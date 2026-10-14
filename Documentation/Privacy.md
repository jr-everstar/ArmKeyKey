# ArmKeyKey privacy

ArmKeyKey processes input locally to compose and select text. It does not send keystrokes or candidate selections to a server, create an account, fetch suggestions, collect analytics, or log typed content.

When learning is enabled, ArmKeyKey stores selected code/candidate pairs and their selection counts on this Mac. Cangjie 3, Cangjie 5 and Smart Zhuyin learning are enabled by default; Simplex learning is disabled by default. Traditional Zhuyin has no learned ordering. You can change each learning setting, export/import learning, or reset it in settings. Exported JSON contains these learned code/candidate pairs; share it only intentionally.

Preferences are stored in macOS UserDefaults. Learned data is stored under the user’s Application Support/ArmKeyKey folder. Removing the application does not delete learned data automatically. Use Reset before removal if you want to clear it.

Input is received through InputMethodKit for the active input session. ArmKeyKey does not request global Input Monitoring or Accessibility access. Secure-field behavior is controlled by macOS and must be verified during release testing. System-generated crash reports remain subject to the user’s macOS diagnostics settings.

## Update checks in 0.8.0

Automatic checks are enabled by default and can be disabled in Settings → 軟件更新. While the app is running, it checks the public GitHub Pages stable feed at most once per 24 hours; manual checks bypass the interval. Requests contain no typed text, candidate selections, learning records, account or persistent user identifier. GitHub receives ordinary connection metadata such as IP address and HTTP client information. Sessions are ephemeral, with cookies and persistent HTTP caching disabled. Input and phrase lookup remain offline.

Downloads start only on request and come from this project's GitHub Releases. The app retains update preferences, check timestamps and skipped/notified build numbers in UserDefaults; verified packages are stored in the user's cache directory. Canceled or failed downloads are cleaned up. Notifications require macOS permission; declining permission does not prevent manual checks. Installation opens Apple's Installer after explicit confirmation and input-source checks. Learning data is not uploaded or deleted.

## Smart Zhuyin learning

Smart Zhuyin persists reading/word selection counts only when an explicitly selected word survives the final committed composition. Canceled text is not learned; whole sentences and raw keystroke history are not saved. Preferences live in a separate local SQLite file and are never transmitted. Disabling learning stops reading and updating those preferences without deleting them. Format-2 backups contain all four learning modes; old format-1 backups replace only legacy modes. Reset clears all learned modes. Exported preferences can reveal selected words, so share backups intentionally.

## First-install guidance in 0.9.2

Fresh PKG installations schedule a short-lived helper at graphical login to open Keyboard Settings and explain how to add the input source. Each account stores a local completion flag. Subsequent logins exit immediately after checking that flag; there is no continuously running setup helper. Upgrades do not create this login agent. The guide sends no network requests and does not enable or select an input source automatically.

First-login setup keeps a bounded local diagnostic log at `~/Library/Logs/ArmKeyKey/first-login-setup.log` containing launch, skip, Settings-open and acknowledgement states. It contains no typed content and is not uploaded. Build 20 also records the installer’s setup decision under `/Library/ArmKeyKey Setup/last-install`.


## v0.10.0 shortcut preferences (development)

Custom shortcuts store only a physical key code and modifier flags in local UserDefaults. They are not typing history, are not uploaded and are separate from learning-data backups. The shortcut recording sheet uses an in-process event monitor only while open; normal matching receives events from InputMethodKit. No global keyboard listener or additional permission is requested.

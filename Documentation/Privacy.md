# ArmKeyKey privacy

ArmKeyKey processes input locally to compose and select text. It does not send keystrokes or candidate selections to a server, create an account, fetch suggestions, collect analytics, or log typed content.

When learning is enabled, ArmKeyKey stores selected code/candidate pairs and their selection counts on this Mac. Cangjie learning is enabled by default; Simplex learning is disabled by default. You can change either setting, export/import learning, or reset it in settings. Exported JSON contains these learned code/candidate pairs; share it only intentionally.

Preferences are stored in macOS UserDefaults. Learned data is stored under the user’s Application Support/ArmKeyKey folder. Removing the application does not delete learned data automatically. Use Reset before removal if you want to clear it.

Input is received through InputMethodKit for the active input session. ArmKeyKey does not request global Input Monitoring or Accessibility access. Secure-field behavior is controlled by macOS and must be verified during release testing. System-generated crash reports remain subject to the user’s macOS diagnostics settings.

## v0.8.0 optional update checks (pending release)

These network behaviors apply to the upcoming v0.8.0 updater; 0.7.2 does not include update checks. Automatic checks are enabled by default and can be disabled in Settings → 軟件更新. While the app is running, it checks the public GitHub Pages stable feed at most once per 24 hours; manual checks bypass this interval. Requests do not contain keystrokes, candidates, learning records, an account or a persistent user identifier. GitHub receives ordinary connection information such as IP address and HTTP client metadata. The updater uses an ephemeral session without cookies or a persistent HTTP cache.

Downloads happen only after the user chooses Download Update. PKGs are fetched from this project's GitHub Releases and GitHub's asset hosts, stored in a private per-download cache directory, and checked before installation. Failed/cancelled downloads are removed. A verified package remains in the local cache for installation or manual recovery; a replaced in-session download is removed. The updater does not collect analytics or send installation results.

The app stores update preferences, the last attempted/successful check time, and skipped/notified build numbers in local UserDefaults. Each newer compatible build is notified at most once when notification permission is available. Notification permission is requested from the update page, not by background update checks; denied notifications do not prevent manual checks. Existing input-mode notifications share the same notification delegate. Input and learning remain offline.

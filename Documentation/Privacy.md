# ArmKeyKey privacy

ArmKeyKey processes input locally to compose and select text. It does not send keystrokes or candidate selections to a server, create an account, fetch suggestions, collect analytics, or log typed content.

When learning is enabled, ArmKeyKey stores selected code/candidate pairs and their selection counts on this Mac. Cangjie learning is enabled by default; Simplex learning is disabled by default. You can change either setting, export/import learning, or reset it in settings. Exported JSON contains these learned code/candidate pairs; share it only intentionally.

Preferences are stored in macOS UserDefaults. Learned data is stored under the user’s Application Support/ArmKeyKey folder. Removing the application does not delete learned data automatically. Use Reset before removal if you want to clear it.

Input is received through InputMethodKit for the active input session. ArmKeyKey does not request global Input Monitoring or Accessibility access. Secure-field behavior is controlled by macOS and must be verified during release testing. System-generated crash reports remain subject to the user’s macOS diagnostics settings.

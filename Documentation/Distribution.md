# Distribution

## GitHub update infrastructure

Source repository: https://github.com/jr-everstar/ArmKeyKey . Pages deploys only `site/` through the `Deploy update site` workflow on `main`; pull requests validate the feed without deploying. The stable endpoint is `https://jr-everstar.github.io/ArmKeyKey/updates/stable.json`. No Apple credentials or additional deployment token is needed for Pages.

The version-1 feed identifies the app and stable channel, with a `releases` array. An empty array means no update is offered, not a network error. Each future entry contains `version` (display string), `build` (positive integer), `minimumSystemVersion`, `architectures` (`["arm64"]`), `notes` (plain text), and `package` with a fixed GitHub Release asset `url`, `size` in bytes and lowercase `sha256`. Retain older supported releases when newer versions raise system requirements. The future client selects the highest compatible build newer than itself. Run `python3 Scripts/check-update-feed.py` before publishing feed changes.

Publish only after the existing release checks pass: sign and notarize the PKG locally, staple and verify it, calculate its final size and checksum, upload it to a versioned GitHub Release, verify the download, then update and deploy the feed. Do not overwrite an already advertised asset or use a moving `latest/download` URL. Feed validation checks metadata shape, not Apple signatures or release readiness. To withdraw an update, remove its feed entry and redeploy; this does not downgrade installed apps. Pages/CDN caches can delay visibility, so check the live endpoint after deployment.

This infrastructure does not add an updater to the current app. The initial feed intentionally offers no release; there is no placeholder download or unpublished package advertised as installable.

## Mac App Store feasibility

This build is an InputMethodKit input method intended for installation in the user’s Library/Input Methods folder. It is not sandboxed and is **not a Mac App Store submission build**.

[Apple’s review guidelines §2.4.5](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility) require appropriate sandboxing, a self-contained app bundle, and restrictions on installing resources outside that bundle. [App Sandbox documentation](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox) confirms sandboxing is required for the store. [InputMethodKit](https://developer.apple.com/documentation/inputmethodkit) provides the system input-method API; its availability alone does not establish App Store eligibility.

App Store acceptance remains unverified. A signed sandbox prototype must demonstrate registration, activation, cross-app composition, candidate presentation, and persistence through the complete permitted installation path. Obtain Apple technical/review clarification for any unresolved distribution requirements. Do not ship an App Store companion that silently installs an unsandboxed helper or advertise store availability before acceptance. The authorized fallback is direct notarized distribution.

## Local signing configuration

Supply `DEVELOPER_ID_APPLICATION`, `DEVELOPER_ID_INSTALLER` and `NOTARY_PROFILE` locally. Store credentials in macOS Keychain, never in this repository. Machine-specific profile notes live in the ignored `.local/notarization-settings.txt` on the development Mac; use that existing profile before requesting new credentials. Other Macs must configure their own signing environment.

Only an `Accepted` notarization result confirms success. Staple and validate the final PKG, verify its installer signature and extracted app signature, and calculate the checksum after stapling. Public certificate identities, bundle IDs and notarization submission IDs are not private keys.

## Direct release

`Scripts/release.sh` checks release-readiness flags, runs tests, builds arm64, signs with Developer ID and hardened runtime, submits to notarization, staples the result, verifies Gatekeeper assessment, and creates `build/distribution/ArmKeyKey.zip` with a SHA-256 checksum.

Supply `DEVELOPER_ID_APPLICATION`, `NOTARY_PROFILE` (an existing notarytool keychain profile), and optionally `ARMKEYKEY_BUNDLE_ID` (defaults to `everstar.inputmethod.armkeykey.mac`). Credentials are never stored in source. The release script is not run automatically. An Apple Development certificate is not a Developer ID Application certificate.

Before setting readiness flags, retain evidence of dictionary rights, both OS test matrices, a clean install/update/removal pass, and approved privacy/attribution text. Developer ID signing and Apple notarization have been completed for the candidate packages documented below; public release readiness remains a separate check. No updater or remote endpoint is included; users install later signed versions using the documented replacement process.

## Signed PKG installer

`Scripts/build-pkg.py <signed-app> <output.pkg>` packages a Developer-ID-signed app. Set `DEVELOPER_ID_INSTALLER` to the installer signing identity. The package is then submitted with `notarytool`, and the accepted ticket is stapled to the PKG. Verify the outer package signature and ticket as well as the extracted app signature before delivery.

The installer requires Apple Silicon and macOS 26+, and installs only to `/Library/Input Methods/ArmKeyKey.app` with administrator authorization. Bundle relocation is disabled. The preinstall script refuses installation while ArmKeyKey is running or when a personal installation exists under `/Users/*` or the current console user's home. It never deletes personal data, terminates processes, or switches input sources. Version 0.7.2 uses the native Installer `RequireLogout` conclusion action, so users are told to save their work and complete logout through Installer. No script forcibly kills loginwindow or applications. Custom home locations for other offline users are not enumerated. Each user logs out/in and adds the input source through Keyboard settings. Remove a previous development input-source entry before adding the new `everstar.inputmethod.armkeykey.mac` entry. Preferences tied to the previous bundle ID are not migrated automatically; learning data in Application Support remains untouched.

The app recognises its shared installation so its setup button does not copy a second instance into the user's Library. Downloaded ZIPs still default to per-user installation when no shared copy exists. The installer is not executed on the developer's live installation as part of packaging; clean-machine install/update/removal acceptance remains a separate check.


### Registration correction in 0.7.2 build 14

Do not redistribute the 0.7.1 build 13 package: its app identifier omitted `.inputmethod.` and was not discoverable after login. Current builds use `everstar.inputmethod.armkeykey.mac`; the installer receipt stays `everstar.armkeykey.mac.pkg` for upgrades. The corrected local app has been built and its presence under Chinese, Traditional verified. A replacement Developer-ID-signed PKG has been produced in `build/distribution/ArmKeyKey-0.7.2-build14/`; Apple notarization was Accepted (submission `b237c069-ac13-4385-bde3-87031bcbd9a0`), and the ticket was stapled and validated. The existing local keychain profile is used; no credentials are stored in the project. Expanded-package checks passed for the payload signature, corrected identifier, build 14, shared destination, and RequireLogout. The local repair is installed in the user's Input Methods directory; move that copy out before testing a shared PKG installation.

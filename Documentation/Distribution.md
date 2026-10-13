# Distribution

## v0.8.0 release sequence

v0.8.0 is the next planned release, not an available download. The feature PR deliberately retains `CFBundleShortVersionString=0.7.2` and `CFBundleVersion=14`; existing package validation records below refer to that older build. Never relabel the old PKG as v0.8.0.

1. Review and merge the updater feature PR, including tests and these pending-release docs.
2. Create a separate release-preparation branch/commit and PR for `0.8.0`, provisionally build `15` (check the latest source/feed first). Update Info.plist, release notes, version-sensitive documentation and clean-machine acceptance evidence; complete the existing readiness checks. Keep the stable feed and public site's released-version claim unchanged at this stage.
3. After that PR is merged, publish from its clean, pushed source commit. Use `python3 Scripts/publish-release.py --build --notes-file .local/release-notes-v0.8.0.txt --publish` with the local signing environment. This builds/signs/notarizes, uploads a draft PKG, verifies it, publishes the Release, and creates a separate feed PR. It does not merge PRs.
4. Review the feed PR for version/build, OS, asset URL, size and final SHA-256. Merge only after the public PKG download works. The Pages workflow then deploys `stable.json`; check the live response.
5. Use a separate website PR to update `site/index.html` with v0.8.0 and the verified download link. Merge and confirm Pages deployment. No placeholder or unreleased PKG is advertised by the current feature PR.

The first updater-bearing build must be installed manually by 0.7.2 users. To test actual in-app upgrading, use two appropriately versioned signed test builds on a private/local test setup; do not publish fake versions to the production stable feed. Required scenarios include notification permission denied/allowed, offline/failed checks, skipped versions, cancelled/corrupt downloads, shared/personal installs, another account still running ArmKeyKey, normal parent exit, Installer authorization and logout. Preserve learning data throughout.

## GitHub update infrastructure

Source repository: https://github.com/jr-everstar/ArmKeyKey . Pages deploys only `site/` through the `Deploy update site` workflow on `main`; pull requests validate the feed without deploying. The stable endpoint is `https://jr-everstar.github.io/ArmKeyKey/updates/stable.json`. No Apple credentials or additional deployment token is needed for Pages.

The version-1 feed identifies the app and stable channel, with a `releases` array. An empty array means no update is offered, not a network error. Each future entry contains `version` (display string), `build` (positive integer), `minimumSystemVersion`, `architectures` (`["arm64"]`), `notes` (plain text), and `package` with a fixed GitHub Release asset `url`, `size` in bytes and lowercase `sha256`. Retain older supported releases when newer versions raise system requirements. The client selects the highest compatible build newer than itself. Run `python3 Scripts/check-update-feed.py` before publishing feed changes.

Publish only after the existing release checks pass: sign and notarize the PKG locally, staple and verify it, calculate its final size and checksum, upload it to a versioned GitHub Release, verify the download, then update and deploy the feed. Do not overwrite an already advertised asset or use a moving `latest/download` URL. Feed validation checks metadata shape, not Apple signatures or release readiness. To withdraw an update, remove its feed entry and redeploy; this does not downgrade installed apps. Pages/CDN caches can delay visibility, so check the live endpoint after deployment.

The source now includes an opt-out daily update check, manual checks, optional notification banners and user-initiated PKG download/installation. The feed intentionally offers no release until a verified package is published; an empty feed is a successful check with no offered update. Existing 0.7.2 installations need one manual upgrade to a build containing this updater.

## Local release command

Run from the repository root with Python 3, Xcode command-line tools and an authenticated GitHub CLI (`gh auth login`). The command does not install the app, merge its feed PR or upload Apple credentials. Release notes are public; write only user-facing changes in the notes file.

Validate an existing signed, notarized and stapled package without changing GitHub:

```sh
python3 Scripts/publish-release.py \
  --pkg build/distribution/ArmKeyKey-0.7.2-build14/ArmKeyKey-0.7.2-mac-arm64.pkg \
  --notes-file .local/release-notes.txt
```

To perform the upload/publication and create the stable-feed PR, add `--publish` to the same command. The package's app version, build and minimum OS must match `Resources/Info.plist`. The tool checks the PKG signature, notarization staple, Gatekeeper assessment, payload app signature/team, architecture, receipt identity and install destination. This validates the package and metadata; it is not proof of a reproducible binary/source match.

For the complete local build/sign/notarize/package/upload pipeline:

```sh
python3 Scripts/publish-release.py --build \
  --notes-file .local/release-notes.txt --publish
```

Set `DEVELOPER_ID_APPLICATION`, `DEVELOPER_ID_INSTALLER` and `NOTARY_PROFILE` in the local shell first; the development Mac's existing settings are recorded in ignored `.local/notarization-settings.txt`. Without `--publish`, `--build` prints the intended steps only and does not build or contact Apple.

Publishing requires all existing `release-readiness.json` checks to be true, a clean committed source tree, and the current source commit already present in this GitHub repository. Complete the documented checks rather than toggling flags just to unblock the command. Commit/push this tooling before using it for a release. The existing ZIP-oriented `release.sh` is reused for app build/sign/notarization, followed by PKG creation and separate PKG notarization. Signed PKGs are retained under ignored `build/distribution/vVERSION-buildBUILD/`.

The publisher uses version/build-specific tags and asset names, verifies a draft's uploaded bytes, publishes the release without changing GitHub's Latest designation, then verifies the anonymous public download before creating an `updates/build-BUILD` PR from fresh `main`. Pages updates only after that PR is merged. No installation file is committed to Git. Review the PR link printed by the command.

On failure, completed GitHub steps remain visible: the command never deletes a release, overwrites an asset or force-pushes a branch. Retry with the saved PKG and identical notes using `--pkg`; do not rebuild and expect new signed bytes to match an existing asset. Matching uploads/PRs are reused. Conflicting tags, asset contents or feed branches stop for review. If the release is already public but the PR step fails, the public release remains available while the stable feed stays unchanged. Once the exact feed entry is merged, a retry needs no new PR. An older build cannot be added below a newer advertised build by this command.

Offline workflow tests: `python3 Tests/PublishReleaseTests.py` (also included in `Scripts/test.sh`).

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

Before setting readiness flags, retain evidence of dictionary rights, both OS test matrices, a clean install/update/removal pass, and approved privacy/attribution text. Developer ID signing and Apple notarization have been completed for the candidate packages documented below; public release readiness remains a separate check. The updater uses the Pages stable feed and GitHub Release assets. Feed publication remains separate from package signing and public release readiness.

## Signed PKG installer

`Scripts/build-pkg.py <signed-app> <output.pkg>` packages a Developer-ID-signed app. Set `DEVELOPER_ID_INSTALLER` to the installer signing identity. The package is then submitted with `notarytool`, and the accepted ticket is stapled to the PKG. Verify the outer package signature and ticket as well as the extracted app signature before delivery.

The installer requires Apple Silicon and macOS 26+, and installs only to `/Library/Input Methods/ArmKeyKey.app` with administrator authorization. Bundle relocation is disabled. The preinstall script refuses installation while ArmKeyKey is running or when a personal installation exists under `/Users/*` or the current console user's home. It never deletes personal data, terminates processes, or switches input sources. Version 0.7.2 uses the native Installer `RequireLogout` conclusion action, so users are told to save their work and complete logout through Installer. No script forcibly kills loginwindow or applications. Custom home locations for other offline users are not enumerated. Each user logs out/in and adds the input source through Keyboard settings. Remove a previous development input-source entry before adding the new `everstar.inputmethod.armkeykey.mac` entry. Preferences tied to the previous bundle ID are not migrated automatically; learning data in Application Support remains untouched.

The app recognises its shared installation so its setup button does not copy a second instance into the user's Library. Downloaded ZIPs still default to per-user installation when no shared copy exists. The installer is not executed on the developer's live installation as part of packaging; clean-machine install/update/removal acceptance remains a separate check.


### Registration correction in 0.7.2 build 14

Do not redistribute the 0.7.1 build 13 package: its app identifier omitted `.inputmethod.` and was not discoverable after login. Current builds use `everstar.inputmethod.armkeykey.mac`; the installer receipt stays `everstar.armkeykey.mac.pkg` for upgrades. The corrected local app has been built and its presence under Chinese, Traditional verified. A replacement Developer-ID-signed PKG has been produced in `build/distribution/ArmKeyKey-0.7.2-build14/`; Apple notarization was Accepted (submission `b237c069-ac13-4385-bde3-87031bcbd9a0`), and the ticket was stapled and validated. The existing local keychain profile is used; no credentials are stored in the project. Expanded-package checks passed for the payload signature, corrected identifier, build 14, shared destination, and RequireLogout. The local repair is installed in the user's Input Methods directory; move that copy out before testing a shared PKG installation.


## Manual release acceptance

The signed and notarized 0.7.2 build 14 candidate has completed package validation. The manual matrix below remains outstanding, and `release-readiness.json` remains false. Automated controller tests use a mock client and do not verify real InputMethodKit connections. Keep OS/app versions and results with the release evidence before changing readiness flags.

On **each** macOS version (26 and 27), use a clean test account and complete:

| Area | Required scenarios |
| --- | --- |
| Installation | Install, register/add input source, activate, relaunch after logout, update and removal |
| Native apps | TextEdit and Word: both modes, numeric selection, paging, selection replacement, marked-text cancellation |
| Browsers | Safari and Chrome: text areas, contenteditable, address fields, tabs and focus changes |
| Electron | An Electron editor: composition, shortcuts, source switching, candidate selection |
| Lifecycle | Switch apps while composing, switch input sources, forced commit, process restart, sleep/wake |
| Display | Multiple monitors, screen edges, full screen, dark/light appearances, scaling |
| Privacy/accessibility | Secure fields, no global input permissions, VoiceOver candidate labels and settings |
| Localized UI | Traditional Chinese settings and menu; no clipped labels |
| Storage | Reset and restore with an active input session; learning enabled/disabled per mode |

Acceptance: no lost/duplicated committed text, stable ordered candidates, correct caret anchoring, no stuck candidate panels, working keyboard shortcuts, no crashes, and no keystrokes in application diagnostics. Preserve recordings or written results with OS/app versions.

## v0.8.0 in-app updater installation handoff

Settings → 軟件更新 and the input-method menu's 檢查更新 entry expose the same updater. The user chooses Download and then confirms installation after saving work and selecting another input source. Downloads are bounded to the feed's declared size (maximum 512 MiB), checked by SHA-256, assessed by Gatekeeper as a notarized Developer ID installer, and expanded for app team/version, receipt/destination and RequireLogout checks. Verification uses macOS system tools and does not require Xcode on consumer Macs. HTTPS redirects are limited to the project feed or GitHub release asset hosts. Checks and verification do not block key handling.

The same signed executable has a narrow handoff mode that initializes no IMK server. It waits for the original process to exit, checks that another input source is selected, revalidates the package, then replaces itself with the system `open` command to launch Installer. The existing preinstall still refuses to overwrite any running ArmKeyKey instance, including other users' sessions. No processes are killed and no input source is switched automatically. Administrator authorization and logout remain in Apple's Installer UI.

For a personal installation, the updater exposes the verified PKG and the personal installation folder, with an explicit normal-quit action. Users move the old personal App out after quitting and open the downloaded PKG manually. It never removes or migrates learning data. Handoff errors leave the existing application and downloaded package intact. The helper and actual logout flow require a clean-machine signed-release acceptance test; building the source alone does not validate that system interaction.

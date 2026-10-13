# Distribution

## GitHub update infrastructure

Source repository: https://github.com/jr-everstar/ArmKeyKey . Pages deploys only `site/` through the `Deploy ArmKeyKey website` workflow on `main`; pull requests validate the feed without deploying. The stable endpoint is `https://jr-everstar.github.io/ArmKeyKey/updates/stable.json`. No Apple credentials or additional deployment token is needed for Pages.

The version-1 feed identifies the app and stable channel, with a `releases` array. An empty array means no update is offered, not a network error. Each future entry contains `version` (display string), `build` (positive integer), `minimumSystemVersion`, `architectures` (`["arm64"]`), `notes` (plain text), and `package` with a fixed GitHub Release asset `url`, `size` in bytes and lowercase `sha256`. Retain older supported releases when newer versions raise system requirements. The client selects the highest compatible build newer than itself. Run `python3 Scripts/check-update-feed.py` before publishing feed changes.

Publish only after the existing release checks pass: sign and notarize the PKG locally, staple and verify it, calculate its final size and checksum, upload it to a versioned GitHub Release, verify the download, then update and deploy the feed. Do not overwrite an already advertised asset or use a moving `latest/download` URL. Feed validation checks metadata shape, not Apple signatures or release readiness. To withdraw an update, remove its feed entry and redeploy; this does not downgrade installed apps. Pages/CDN caches can delay visibility, so check the live endpoint after deployment.

Version 0.8.0 includes the in-app updater. The stable feed is populated only after a signed package is published and its public download verified. An empty feed before publication is valid; no placeholder asset is offered.

## Local release command

Run from the repository root with Python 3, Xcode command-line tools and an authenticated GitHub CLI (`gh auth login`). The command does not install the app, merge its feed PR or upload Apple credentials. Release notes are public; write only user-facing changes in the notes file.

Validate an existing signed, notarized and stapled package without changing GitHub:

```sh
python3 Scripts/publish-release.py \
  --pkg build/distribution/v0.9.0-build17/ArmKeyKey-0.9.0-build17-mac-arm64.pkg \
  --notes-file Documentation/Releases/0.9.0.md
```

To perform the upload/publication and create the stable-feed PR, add `--publish` to the same command. The package's app version, build and minimum OS must match `Resources/Info.plist`. The tool checks the PKG signature, notarization staple, Gatekeeper assessment, payload app signature/team, architecture, receipt identity and install destination. This validates the package and metadata; it is not proof of a reproducible binary/source match.

For the complete local build/sign/notarize/package/upload pipeline:

```sh
python3 Scripts/publish-release.py --build \
  --notes-file Documentation/Releases/0.9.0.md --publish
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

Before setting readiness flags, retain evidence of dictionary rights, both OS test matrices, a clean install/update/removal pass, and approved privacy/attribution text. Developer ID signing and Apple notarization have been completed for the candidate packages documented below; public release readiness remains a separate check. Version 0.8.0 adds optional update checks and a user-confirmed Installer handoff; older versions require a manual first upgrade.

## Signed PKG installer

`Scripts/build-pkg.py <signed-app> <output.pkg>` packages a Developer-ID-signed app. Set `DEVELOPER_ID_INSTALLER` to the installer signing identity. The package is then submitted with `notarytool`, and the accepted ticket is stapled to the PKG. Verify the outer package signature and ticket as well as the extracted app signature before delivery.

The installer requires Apple Silicon and macOS 26+, and installs only to `/Library/Input Methods/ArmKeyKey.app` with administrator authorization. Bundle relocation is disabled. The preinstall script refuses installation while ArmKeyKey is running. Since 0.8.1, it moves personal copies found under `/Users/*` or the current console user's home into unique `Library/ArmKeyKey Installer Backup.*` directories within those homes, instead of failing the entire installation. Symlinked installation paths are rejected. Backups are retained even if a later installation step fails; restore the backed-up App to the original personal Input Methods directory only after removing any shared installation. It never deletes personal data, terminates processes, or switches input sources. Since version 0.7.2, the package uses the native Installer `RequireLogout` conclusion action, so users are told to save their work and complete logout through Installer. No script forcibly kills loginwindow or applications. Custom home locations for other offline users are not enumerated. Each user logs out/in and adds the input source through Keyboard settings. Remove a previous development input-source entry before adding the new `everstar.inputmethod.armkeykey.mac` entry. Preferences tied to the previous bundle ID are not migrated automatically; learning data in Application Support remains untouched.

The app recognises its shared installation so its setup button does not copy a second instance into the user's Library. Downloaded ZIPs still default to per-user installation when no shared copy exists. The installer is not executed on the developer's live installation as part of packaging; clean-machine install/update/removal acceptance remains a separate check.


### Registration correction in 0.7.2 build 14

Do not redistribute the 0.7.1 build 13 package: its app identifier omitted `.inputmethod.` and was not discoverable after login. Current builds use `everstar.inputmethod.armkeykey.mac`; the installer receipt stays `everstar.armkeykey.mac.pkg` for upgrades. The corrected local app has been built and its presence under Chinese, Traditional verified. A replacement Developer-ID-signed PKG has been produced in `build/distribution/ArmKeyKey-0.7.2-build14/`; Apple notarization was Accepted (submission `b237c069-ac13-4385-bde3-87031bcbd9a0`), and the ticket was stapled and validated. The existing local keychain profile is used; no credentials are stored in the project. Expanded-package checks passed for the payload signature, corrected identifier, build 14, shared destination, and RequireLogout. The local repair is installed in the user's Input Methods directory; move that copy out before testing a shared PKG installation.


## Manual release acceptance

The maintainer confirmed completion of the release reviews and manual acceptance for 0.8.0 on 2026-10-14; see [acceptance record](Releases/0.8.0-acceptance.md). `release-readiness.json` records that confirmation. The matrix below remains the checklist for future releases. Automated controller tests use a mock client and do not verify real InputMethodKit connections. Keep OS/app versions and results with the release evidence before changing readiness flags.

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

## In-app update handoff

The app downloads only on request, verifies the PKG and embedded app, and asks the user to save work and switch to another input source. A narrowly scoped helper waits for normal parent exit, verifies the package again and opens Apple's Installer. No script kills apps or forces logout. Version 0.8.1 allows the handoff from personal installations; its installer backs up the old App automatically and retains learning data. Older updater versions may still require opening the downloaded PKG manually.

## 0.9.0 publication sequence

1. Commit the feature branch, merge into main and push; this release explicitly uses the maintainer-authorized direct workflow without PRs. Run the regression and build checks.
2. From the clean pushed release commit, run the local publisher with `--build --notes-file Documentation/Releases/0.9.0.md --publish --feed-mode direct`.
3. Verify the resulting versioned GitHub Release and package; retain the signed bytes and publication results locally.
4. The publisher commits the verified stable feed directly to main. Commit the website release update on the feature branch and merge it into main. Check the deployed JSON, size/hash and public download link after Pages completes.

The app version is 0.9.0/build 17; the tag is `v0.9.0-build17`. Publication must use the newly built package, never a relabeled older PKG. The source release commit is separate from later feed/site publication commits.


## Homebrew

The public [homebrew-armkeykey](https://github.com/jr-everstar/homebrew-armkeykey) repository provides the tap, using the current signed release package. Homebrew automatically adds it when installing:

```sh
brew install --cask jr-everstar/armkeykey/armkeykey
```

[`Casks/armkeykey.rb`](https://github.com/jr-everstar/homebrew-armkeykey/blob/main/Casks/armkeykey.rb) in that separate repository pins the versioned, signed and notarized PKG and its final SHA-256. It requires arm64 and macOS 26+. Homebrew invokes the macOS command-line installer with administrator authorization; it installs to `/Library/Input Methods/ArmKeyKey.app`, not `/Applications`. This is a project-maintained tap, not a listing in Homebrew's official cask repository.

Before installing or upgrading, save work, switch input sources and quit ArmKeyKey in every logged-in account. The PKG refuses to replace a running input method. It automatically moves old personal Apps into `~/Library/ArmKeyKey Installer Backup.*`, retaining learning data and settings. After the command finishes, **log out and back in manually** and add ArmKeyKey in Keyboard settings. Command-line installation does not display the graphical Installer logout button.

```sh
brew update
brew upgrade --cask --greedy jr-everstar/armkeykey/armkeykey
```

The cask declares `auto_updates` because the app also has its own updater; `--greedy` includes it in Homebrew upgrades. If the app has already been updated outside Homebrew, Homebrew's recorded version may lag until the next cask upgrade/reinstall.

For removal, switch input sources, quit ArmKeyKey and remove its input-source entry in Keyboard settings before running:

```sh
brew uninstall --cask jr-everstar/armkeykey/armkeykey
```

Uninstall uses the exact package receipt ID and preserves preferences and learning data. No `zap` cleanup is provided. Never run uninstall while another account is using the input method.

For each release, build a fresh PKG, verify signing/notarization, and publish and verify its immutable download before updating the cask version/checksum in `homebrew-armkeykey` and the stable feed in this repository. Update `version` as `APP_VERSION,BUILD` so rebuilding an app release remains distinguishable. Validate with `brew info --cask jr-everstar/armkeykey/armkeykey`, `brew audit --cask --online jr-everstar/armkeykey/armkeykey`, and `brew fetch --cask jr-everstar/armkeykey/armkeykey`. Live install/upgrade/logout/removal testing requires a separate test Mac/account; download validation does not establish that acceptance.


If you previously tapped the source repository using its explicit URL, migrate once:

```sh
brew tap --custom-remote jr-everstar/armkeykey https://github.com/jr-everstar/homebrew-armkeykey.git
brew update-reset "$(brew --repository jr-everstar/armkeykey)"
```

This resets only this tap's local Git files to the new repository; back up any local cask edits first. It does not uninstall the app or remove learning data.

## 0.8.1 installer regression

The 0.8.0 installation log reported `PKInstallErrorDomain Code=112` from preinstall because a personal App remained. Version 0.8.1 replaces that refusal with recoverable migration. `Tests/InstallerTests.py` exercises fresh/repeated installs, personal and leftover bundles, running-process refusal, custom homes, symlinks and preservation of learning data. The existing 0.8.0 OS/input-engine acceptance is historical; these automated checks do not claim a new manual macOS 26/27 or live logout test. See [0.8.1 validation](Releases/0.8.1-validation.md).

## 0.9.0 maintainer publication

Target: 0.9.0/build 17. The maintainer explicitly requested direct feature-branch commits and a merge into main without PRs, including version/docs/site/release/tap updates. This supersedes the default contributor PR workflow for this release only.

After local tests and build, merge `feature/0.9.0-input-methods` into main and push without force. Publish the fresh signed/notarized PKG from that clean source commit using `--feed-mode direct` with the publisher. This opt-in updates the verified stable feed through a normal fast-forward main commit; concurrent changes reject the push and require a fresh retry. Never weaken branch rules or overwrite a published asset.

Only after the public PKG hash is verified, update the website download URL and the dedicated Homebrew tap to `0.9.0,17` with that final SHA-256. Verify deployed Pages/feed, release download, Homebrew style/audit/livecheck/fetch. No installation or forced logout is performed on the active development account. Current automated evidence and any remaining manual acceptance limits belong in `Releases/0.9.0-validation.md`; historical macOS 26/27 acceptance is not relabeled as a new run.

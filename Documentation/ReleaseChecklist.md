# Release checklist

This is the canonical checklist for every ArmKeyKey release, including hotfixes.
Use it with [Distribution.md](Distribution.md) for signing, installer and manual
acceptance details. Older version-specific publication sections are historical
records, not instructions to reuse their version numbers or authorization.

Create `Releases/VERSION-publication.md` from [TEMPLATE.md](Releases/TEMPLATE.md).
Record passed, pending, blocked, or not applicable with a reason and evidence.
Never mark a command or live check passed merely because it was planned.

## 1. Establish the candidate

- [ ] Inspect status, branch and remotes in both source and tap repositories;
  preserve unrelated/uncommitted work. The tap is a separate repository:
  `jr-everstar/homebrew-armkeykey`, commonly checked out at `../homebrew-armkeykey`.
- [ ] Read the current public Releases, live feed and remote tap before selecting
  the next version/build. Do not infer public state from a local checkout alone.
- [ ] Record version, strictly increasing build, minimum OS, architecture, intended
  source branch and publication workflow. Use PRs by default; use direct merges
  or `--feed-mode direct` when authorized by the current user instructions.
- [ ] Update version/build in `Scripts/generate_project.py`, regenerate with
  `python3 Scripts/generate_project.py`, and review `Resources/Info.plist` and
  `ArmKeyKey.xcodeproj/project.pbxproj`. Editing only the plist is insufficient:
  the build regenerates it.
- [ ] Use tag `vVERSION-buildBUILD` and asset
  `ArmKeyKey-VERSION-buildBUILD-mac-arm64.pkg`. Never relabel an old package.

## 2. Review all documentation

Review every row; record changed or unchanged with a reason. Preserve historical
release notes and acceptance records. Do not bulk-replace old version numbers.

| Files | Review for this release |
| --- | --- |
| `README.md` | Current version, features, system requirements, install/update/removal instructions and links; clearly label an unpublished candidate |
| `CHANGELOG.md` | Version/build, user-visible changes and limitations; do not include release dates |
| `Documentation/Releases/VERSION.md` | Public release notes used by the publisher, migration/logout guidance |
| `Documentation/Releases/VERSION-validation.md` | Actual automated/manual results, OS/app versions, remaining limitations |
| `Documentation/Development.md`, `Documentation/CI.md` | Build, test, generated files and workflow changes |
| `Documentation/Distribution.md`, `Documentation/Compatibility.md` | Packaging, installation, updater, Homebrew and supported OS behavior |
| `Documentation/Privacy.md` | Network, permissions, storage and telemetry claims |
| `Documentation/Dependencies.md`, `Documentation/LicenseAudit.md`, vendor READMEs and licenses | Changed dependencies, dictionary rights, provenance and attribution |
| `Resources/*LICENSE*`, `Resources/*Attribution*`, `Resources/LicensingOverview.txt`, `Resources/ThirdPartyNotices.txt` | Bundled notices; use `Scripts/generate-notices.py` if regeneration is needed |
| `site/index.html`, related `site/` content | Features, version/build badge, requirements, every PKG link, release-note link, install instructions and release summary |
| Tap `README.md`, `Casks/armkeykey.rb` | Current installation behavior, version/build, checksum, description, requirements and caveats |

- [ ] Search for stale current-release claims and links across tracked files with
  `rg`; inspect each match rather than rewriting history.
- [ ] Prepare website/tap changes, but advertise the new package only after its
  immutable public download is verified. Keep candidate source version separate
  from the version currently offered for download.

## 3. Validate and freeze source

Run from the source repository root:

```sh
bash Scripts/test.sh
bash Scripts/build.sh
python3 Scripts/check-update-feed.py
python3 Scripts/check-public-files.py
git diff --check
```

- [ ] Retain command results and review generated-file changes. Commit intended
  generated changes before publishing; the publisher requires a clean tree.
- [ ] Complete the manual matrix in `Distribution.md#manual-release-acceptance`,
  including macOS 26/27, real host apps, clean install, upgrade, logout/login and
  removal. Use a test machine/account for disruptive installation checks.
- [ ] Review every `Documentation/release-readiness.json` gate against recorded
  evidence. Identify carried-forward evidence and why it remains applicable;
  never claim it is a fresh manual test or toggle flags just to pass the tool.
- [ ] Commit/merge/push via the authorized workflow; record the exact clean source
  commit and successful required CI checks. This is the release tag target.

## 4. Build, sign, notarize and publish GitHub Release

Use existing local signing settings described in `Distribution.md`. Keep secrets
in Keychain/local ignored files. Replace `VERSION` below with the actual version.

```sh
python3 Scripts/publish-release.py --build \
  --notes-file Documentation/Releases/VERSION.md --publish
```

The default creates a feed PR. Append `--feed-mode direct` only for an authorized
direct main update. `--build` without `--publish` is a preview, not a build/test.

- [ ] Verify app and installer Developer ID signatures, accepted notarization,
  stapled tickets, Gatekeeper, embedded identity/version/build, arm64 and minimum
  OS using the publisher. Record the final PKG size and SHA-256 after stapling.
- [ ] Record saved PKG path, source commit, tag and public Release URL. Confirm
  tag resolves to the recorded source commit, release is public/non-prerelease,
  notes match, and anonymous download bytes match the final package.
- [ ] Check GitHub's Latest designation. The publisher uses `--latest=false`.
  For the new latest stable release, set it deliberately after verification
  (for example `gh release edit TAG --repo jr-everstar/ArmKeyKey --latest`);
  record a reason if this release should not become Latest.
- [ ] Save the feed PR URL or direct-feed commit. A successful publisher command
  does not finish the website or tap steps below.

On partial failure, inspect existing remote state and retry with the saved PKG:

```sh
python3 Scripts/publish-release.py \
  --pkg build/distribution/vVERSION-buildBUILD/ArmKeyKey-VERSION-buildBUILD-mac-arm64.pkg \
  --notes-file Documentation/Releases/VERSION.md --publish
```

Keep the intended feed mode on retry. Never rebuild different signed bytes for
an existing asset, use `--clobber`, delete/recreate a tag, or force-push.

## 5. Publish GitHub Pages and in-app feed

- [ ] Merge the publisher's feed PR, or verify its direct commit reached `main`.
  Preserve older supported feed entries, especially for older OS versions.
- [ ] Publish `site/index.html` changes: both download buttons, version/build,
  release tag link, release summary, features and installation instructions.
  All new links must refer to the same verified immutable PKG.
- [ ] Run `python3 Scripts/check-update-feed.py` on the final feed/site changes.
  Merge/push through the authorized workflow and record the commit.
- [ ] Wait for **Deploy ArmKeyKey website** to succeed for the applicable `main`
  commit. A PR validation run does not deploy; the workflow publishes `site/`.
- [ ] Fetch the live [website](https://jr-everstar.github.io/ArmKeyKey/) and
  [stable feed](https://jr-everstar.github.io/ArmKeyKey/updates/stable.json).
  Check actual deployed content after any cache delay: version/build, notes,
  requirements, architecture, asset URL, byte size and SHA-256.
- [ ] Open the deployed website, check its download buttons and release link,
  and verify the downloaded package hash. Record real in-app update/handoff
  acceptance separately; JSON validation alone does not prove it works.

## 6. Update the separate Homebrew tap

- [ ] Fetch and inspect the tap's current remote branch before editing. Update
  `Casks/armkeykey.rb` to `version "VERSION,BUILD"` and the verified final PKG
  SHA-256. Review the interpolated tag, URL and package filename.
- [ ] Review minimum OS/architecture, description, `auto_updates`, livecheck,
  receipt ID, logout caveat and tap README against the new installer behavior.
- [ ] Ensure Homebrew is checking the edited tap checkout (inspect
  `brew --repository jr-everstar/armkeykey`), not an older installed tap.
  In the tap repository, run and record:

```sh
brew style Casks/armkeykey.rb
brew info --cask jr-everstar/armkeykey/armkeykey
brew audit --cask --online jr-everstar/armkeykey/armkeykey
brew livecheck --cask jr-everstar/armkeykey/armkeykey
brew fetch --cask jr-everstar/armkeykey/armkeykey
git diff --check
```

- [ ] Commit and publish/merge the tap change through the authorized workflow;
  record the tap commit/PR. A local cask edit is not a published update.
- [ ] Run `brew update`, inspect the public tap version/checksum, and repeat
  info/fetch against the published tap. Download/hash validation is not a live
  install/upgrade/removal test; record those tests separately.

## 7. Close the release

- [ ] Cross-check documentation, public Release/Latest, deployed Pages, live feed
  and published tap against one version/build/tag/URL/size/hash record.
- [ ] Complete and commit the publication and validation records. Record source,
  feed/site and tap commits separately: publication commits can follow the tag.
- [ ] Report release, website/feed and tap links, test results, and any pending
  work. Publication is complete only when all required steps are evidenced;
  unavailable checks or missing access must remain explicitly pending/blocked.

If a published package must be withdrawn, remove its feed offer and update
website/tap pointers consistently through the authorized workflow, then verify
the deployed state. Do not replace bytes under an existing URL. Withdrawal does
not downgrade installed apps; ship a new build for a replacement package.

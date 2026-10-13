# Verification — 2026-10-13

## Completed locally

Environment: Apple Silicon, macOS 27.0.1, Xcode 27.0 (27A266a).

- Debug and Release Xcode builds succeed.
- 66,438 exact input codes / 146,107 entries match the original CIN parser, including order.
- Representative wildcard lookups match character entries from the original parser. Metadata exclusion is a deliberate fix.
- Key-event traces match a separately compiled untouched original engine with the same adapter. Covers composition, selection, paging, invalid input, Backspace, Escape, Return, continuing input, punctuation and wildcards.
- Engine tests run with AddressSanitizer and UndefinedBehaviorSanitizer.
- Frequency learning survives engine destruction/recreation.
- Dictionary generation is byte-reproducible, including repeated regeneration of the same destination.
- Swift storage tests cover export/import roundtrip, invalid format/count/candidate/duplicate rejection, reset, and rollback across both databases when the second database rejects insertion.
- Native Objective-C++ controller tests use an in-process mock text client. Marked text, candidate commit, cancellation, shortcuts, function keys and repeated commit/deactivation are checked. These are adapter unit tests: they do **not** validate the real InputMethodKit remote client connection or system registration.
- The English settings window launches and was visually inspected for layout and accessibility labels. Traditional Chinese strings are bundled; native-language visual review is pending.

Run `Scripts/test.sh` to repeat automated checks. Native controller tests require a logged-in macOS graphical session; they do not change the selected system input source. `Scripts/build.sh` produces the ad-hoc signed local test app.

## Manual release matrix — not completed

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

## Publication blockers

- Original merged dictionary rights have not been fully established.
- No Developer ID Application signing identity was available locally; no public signing or notarization performed.
- macOS 26 and real cross-app InputMethodKit/clean-install tests remain outstanding.
- Mac App Store installation/sandbox feasibility and acceptance remain unverified. The current target is unsandboxed direct distribution.

The release-readiness flags remain false. Do not represent this development build as release-ready or App Store approved.

## 0.2.0 installation and Chinese UI follow-up

The previous app was being launched outside Library/Input Methods. Added in-app installation, public TIS registration and enablement request; installed the updated app in the current user's Library/Input Methods. A separate process confirms source ID org.armkeykey.inputmethod.ArmKeyKey and language zh-Hant. The Chinese settings interface was inspected through accessibility, including labels and dialogs. All engine/storage/controller regression tests still pass.

The current login session's System Settings picker still does not display the source, and a fresh query reports it disabled despite a successful enable API return. Do not claim enablement or typing is verified. A user-controlled logout/login is the next required check; no logout was forced and no existing input source was changed.

## 0.3.0 candidate character-range regression

User reference: YahooKeyKey Windows screenshot, 竹戈 (hi), first page 凡 么 丟 夙 舟 卵 我 私 的, 17 pages. The initial port used PVDefaultEncodingService, accepting every Unicode character, and therefore showed all 398 candidates / 45 pages. The screenshot exposes a gap in the prior source-engine tests: both sides shared that permissive adapter rather than the platform's original font filter.

Added explicit compatible/full character profiles. Default compatible BMP without private-use/noncharacter ranges gives 145 candidates / 17 pages; full mode preserves 398 / 45. Tests verify the first nine, all page transitions and retained relative order, plus learned extended characters cannot bypass filtering and are preserved when switching back to full mode. This is a deterministic compatibility approximation, not verification that all 17 legacy pages match. On 2026-10-13 the user confirmed that the original page 17 contains 䑛, matching the sole final candidate in the compatible profile. The regression test now asserts this character explicitly. First-page order, total page count and final-page content match the supplied references; intermediate legacy pages remain unverified.

## 0.4.0 candidate presentation and phrase suggestions

Automated engine tests cover explicit selection, suffix-only insertion, Escape, Backspace, shortcuts, continuation into a new code without losing its first key, invalid number selection, highlight/Return, page selection, reset and opt-out. Native adapter tests verify that a lifecycle commit does not accept a pending suggestion and that accepting 我 → 我們 appends only 們. The candidate and phrase panels are rendered from the real native view for visual inspection. These adapter tests still do not replace real cross-application IMK testing.

## Input-source icon alignment follow-up

The previous icon generator used `NSImage.lockFocus()`, which inherited the Retina display scale: the nominal 16×16 PNG contained 32×32 pixels, and its @2x PNG contained 64×64. The input-source icon also referenced the app's multi-size ICNS. Generation now uses explicit bitmap dimensions, centres the visible glyph bounds, and supplies a separate InputSource.tiff with 16×16 and 32×32 pixel representations, both declaring a 16×16 point size. The build script regenerates both icon assets.

Release build and ad-hoc signature verification passed. Loaded the generated TIFF with AppKit and verified both representation dimensions and logical sizes. Inspected the generated icon visually. Backed up the installed app under build/backups/ArmKeyKey-before-icon-fix-*, applied only the icon resources and input-source icon plist key to the installed app, and verified its updated signature. The live macOS input menu alignment and cache refresh remain unverified; logout/login may be required. No input-method process or system menu process was terminated.

## 0.5.0 Cantonese tests

Added sanitizer tests for toned/toneless lookup, syllable separators, whole-phrase insertion, no replay of committed text, Cantonese colloquialisms, paging, invalid readings, editing from selection, Escape, shortcut passthrough, idle digits, literal Return, invalid candidate indices and expanded suggestions. The native mock-client test types nei5hou2, verifies marked text, commits 你好 once and checks that deactivation does not append a suggestion. Existing legacy lookup/order, 17-page screenshot regression, learning persistence/import and phrase tests remain required. The source manifest is SHA-256 verified and the database is rebuilt byte-for-byte offline during tests. Real text-client and macOS 26/27 acceptance remain manual gates.

### Retina drawing correction

The first alignment fix validated bitmap metadata and visually checked only the 1× image. The 2× image was still wrong: NSGraphicsContext already scales using the bitmap's logical size, so the additional CGContext scale doubled it again and clipped the drawing. Removed the redundant scale. Visually inspected the corrected 16-point Retina PNG; added Scripts/check-icons.swift to the build to check pixel/point sizes, transparent margins and symmetric visible bounds for all ten PNGs and both TIFF representations. All checks pass, including the installed TIFF. Backed up the installed app before replacing its two icon resources and verifying its signature. Actual System Settings/menu rendering after refreshing macOS's image cache is still pending.

### Input-menu visual size

User screenshot showed the centred icon visibly smaller than OpenVanilla. Removed the menu icon's 8% inset on each side: the coloured background now fills the 16-point canvas (previously 13.44 points). Increased the glyph proportionally from 0.57 to 0.68 of the canvas. App icon padding is unchanged. Both TIFF representations pass size, symmetric bounds and transparent rounded-corner checks; visually inspected the generated Retina image. Backed up the installed app, replaced its menu TIFF and verified the signature. Live menu appearance remains subject to macOS refreshing its cached icon.

### Monochrome input-source status template

The approved colour artwork is too detailed at menu-bar size. Added MakeStatusIcon.swift and StatusTemplate.tiff: a centred semibold 鍵 glyph on a transparent 16-point canvas, in 1×/2× representations. Enabled TISIconIsTemplate so the system can tint the input-source icon for its background. Both the input menu and menu bar use this template; separate colour menu artwork and status artwork are not implemented. App/installer branding and the approved artwork remain unchanged.

Generator checks decoded representation sizes, visible glyph centring and unclipped edges. Inspected a preview on white at native and enlarged sizes. Release build and signature verification passed. Backed up the installed app, copied only the new template and updated its two icon plist keys, then verified the signature. Live menu rendering, light/dark tinting and macOS cache refresh remain unverified; no source switch or process termination was performed.

### User-drawn two-icon experiment

Saved the user's original 32×32 topbar.png and dropdown.png under Design. Replaced the generated 鍵 status glyph with these assets. MakeStatusIcon.swift packages both at 16pt with 1x/2x TIFF representations and asserts all 32×32 source pixels survive unchanged. Template tinting is disabled to preserve the user's colours.

Experimental mapping: tsInputMethodIconFileKey = TopBarIcon.tiff; tsInputMethodAlternateIconFileKey = DropdownIcon.tiff. The alternate key denotes highlighted/alternate state, NOT a documented independent dropdown-row slot (see the installed SDK TextServices.h input-mode icon descriptions). Consequently a normal dropdown row may still show the primary topbar artwork. Do not describe this configuration as verified independent menu-bar/dropdown support.

Both assets passed pixel/size checks. Backed up the installed app and applied only the two assets and icon plist settings; signature verification passed. Attempted to inspect TextInputMenuAgent via native UI automation, but the accessibility call timed out. Actual rendering and cached-image refresh remain pending user visual verification.

### Two-icon experiment result

User reports that both locations still show the same icon. The alternate icon mapping did not achieve independent menu-bar/dropdown rendering. Removed the alternate key from the generator, resource plist and installed plist. Kept the user-supplied topbar artwork as the shared system input-source icon; both original PNGs and packaged assets remain available. No independent dropdown slot has been established.

### White logo and built-in icon investigation

Installed user-supplied Design/armkeykey-white.png through WhiteStatusIcon.tiff (16pt, 16/32px representations). Verified visible/transparent pixels, unchanged original Retina pixels and installed signature. Colour/template conversion remains disabled to honour the supplied white artwork; it is shared by the system menu and status bar and may have low contrast on light backgrounds. Preserved previous artwork and backed up installed app. Release build validation recorded in build/white-icon-build.log; live rendering remains unverified.

Read the installed Japanese input extension plist: TISIconLabels.Primary = あ and tsInputModeMenuIconFileKey = Hiragana.tiff, with no separate dropdown/status PNG pair in that entry. Inspected /System/Library/PrivateFrameworks/KeyboardLayouts.framework/Resources/Assets.car using assetutil. Found paired built-in assets including TCIM.cangjie.language.fill/.stroke, TCIM.cangjie.variant.fill/.stroke, SCIM.pinyin.language.fill/.stroke and JapaneseIM.FullWidthRoman.fill/.stroke. This is direct evidence of built-in fill/outline variants. The inference is that system rendering selects the context-specific built-in variants; runtime dispatch was not traced. No public third-party equivalent for arbitrary paired artwork has been established. Independent first-party project notes report the same limitation: https://github.com/qingjian-team/qingjian/blob/main/docs/design/architecture.md .

### User-selected transparent logo replacement

Replaced the shared system input-source icon with user-supplied Design/armkeykey-transparent.png via TransparentStatusIcon.tiff. Original colours, alpha and Retina pixels are preserved; both representations retain a 16-point logical size. Asset checks, Release build and signatures passed. Backed up the installed app and updated only its icon resource and icon metadata. Live system rendering remains unverified.

## Unused icon cleanup — 2026-10-14

Removed the obsolete Design/topbar.png and Design/dropdown.png and their TopBarIcon.tiff/DropdownIcon.tiff outputs. Removed dropdown generation and bundling references. The active input-source icon remains TransparentStatusIcon.tiff from Design/armkeykey-transparent.png. Earlier entries above describe historical asset states.


## 0.7.2 build 14 — input-source registration repair (2026-10-14)

The installed 0.7.1 PKG used `everstar.armkeykey.mac`; TIS registration returned success but discovery returned nil, and the setup button and registration CLI crashed at Installation.swift:52. Restored the `.inputmethod.` component as `everstar.inputmethod.armkeykey.mac` and handled missing TIS results without force-unwrapping. Updated the generator, generated project, package validation and release default together. The package receipt identifier remains unchanged for upgrades.

Release configuration builds successfully. Installation path and missing-bundle discovery tests pass. Installed a Developer-ID-signed build in the current user's `~/Library/Input Methods/ArmKeyKey.app`; its registration CLI finds one source with language `zh-Hant`. Verified ArmKeyKey is visible under Chinese, Traditional in System Settings' Add Input Source dialog. TISEnableInputSource returned success but the source remained disabled, so activation requires the Add button. No logout or typing verification was performed. No replacement PKG was produced or notarized in this repair.


The replacement 0.7.2 build 14 PKG was subsequently Developer-ID signed, accepted by Apple notarization (b237c069-ac13-4385-bde3-87031bcbd9a0), stapled, and validated. Expanded payload validation confirmed the corrected bundle ID, version, shared install path and RequireLogout conclusion action. The package was not installed on the current Mac and logout was not triggered. Second-Mac installation remains the user acceptance test.

## Self-contained source verification — 2026-10-14

Copied only Git-visible source candidates into a fresh temporary directory with no sibling YahooKeyKey archive, no existing build output and no `.local` settings. `Scripts/test.sh` and `Scripts/build.sh` both completed successfully there. The temporary copy and its build products were removed after verification; the installed input method was not changed. Local logs remain under ignored `build/standalone-tests.log` and `build/standalone-build.log`.

Checks included byte-identical dictionary regeneration, all 66,438 exact input codes / 146,107 entries and ordering, differential traces against the independent pinned legacy source, learning backup/rollback, character filtering, phrases, Jyutping, native controller mock-client tests and installation-path routing. The Release app built and received an ad-hoc test signature; this was not a new notarized release.

The 37 imported source/data files are pinned by SHA-256. The input verifier was also tested with changed, missing, extra and symlinked inputs and rejected each case. The public-file heuristic scan passed with the added inputs. This check establishes independence from the external archive, not a clean-room rewrite, new data licensing clearance or completion of the manual OS release matrix.

# Dependencies and licensing

The project license is [BSD-3-Clause](../LICENSE) for original ArmKeyKey contributions only. Copyright (c) 2026, jr-everstar. Third-party files, data and platform assets retain their own terms; this is not a blanket relicensing of the repository.

| Component | Source/version and use | Terms / evidence |
| --- | --- | --- |
| YahooKeyKey source distribution | YahooKeyKey-Source-1.1.2528; minimal byte-identical subset pinned in `Vendor/legacy-inputs-manifest.json`; no sibling-directory dependency | Original package BSD-3-Clause notice copied verbatim to `Licenses/YahooKeyKey-BSD-3-Clause.txt` |
| OpenVanilla Generic | `Vendor/Generic`; `OVIMGeneric.cpp` is compiled into the app | MIT-style file headers; The OpenVanilla Project, 2004–2010 |
| OpenVanilla framework headers | `Vendor/OpenVanilla`; engine and dictionary builder | MIT-style file headers; Lukhnos D. Liu, 2007–2010; `OVKey.h` also credits Weizhong Yang |
| PlainVanilla headers | `Vendor/PlainVanilla`; candidate state, text buffers and loader adapters | MIT-style file headers; Lukhnos D. Liu, 2007–2010 |
| Rime Cantonese data | Revision `259f0e48bba840c3a2e0d117539e96937f3d89bc`; chars, words, essay-cantonese; hashes in `Vendor/RimeCantonese/manifest.json` | CC-BY-4.0; CanCLID and contributors; bundled attribution, modifications and full license |
| Cangjie / Simplex data | Pinned `Vendor/LegacyTables/cj-ext.cin` and `simplex-ext.cin` → `Resources/Dictionary.sqlite3` | Maintainer confirmed review for 0.8.0; see [audit](LicenseAudit.md) |
| SQLite | Dynamically linked macOS `libsqlite3`; version follows the host OS | [Upstream public-domain statement](https://www.sqlite.org/copyright.html); no bundled SQLite implementation or proprietary extension |
| Apple frameworks and runtimes | AppKit, SwiftUI, Foundation, InputMethodKit, Carbon, UniformTypeIdentifiers, CryptoKit, UserNotifications, Swift and C++ runtimes | Platform/toolchain components; not relicensed by this project |
| Build tools | Xcode/Apple SDK, clang, Swift, Python 3 standard library; CoreText for icon generation | Build dependencies, not vendored third-party packages |

Rime's engine, OpenCC, ODbL `jyut6ping3.maps`, and the legacy archive's unused external libraries are not included in this app. No Swift Package Manager, CocoaPods, npm or downloaded runtime dependency is used by the current build.

## Source reuse

This version is not a wholly clean-room implementation: `Sources/Engine/Engine.cpp` directly includes and instantiates the retained Generic/OpenVanilla/PlainVanilla code, and `Scripts/BuildDictionary.cpp` uses the original CIN parser. Local changes are described in [Compatibility.md](Compatibility.md). A new native UI does not remove those source dependencies.

## Maintaining notices

Run `python3 Scripts/generate-notices.py` after changing vendored headers or license inputs. Run it with `--check` to detect stale bundled notices. The normal build and test scripts run this check. The script groups identical notices while preserving every distinct copyright and permission block, and includes the complete Rime license. `Resources/LicensingOverview.txt`, the project license, and all third-party notices ship inside the app.

Before adding dependencies, record their exact version, source, license, modifications and bundled notices here. Check data licensing separately from code licensing. The maintainer confirmed the existing dictionary-rights review for 0.8.0; see [release acceptance](Releases/0.8.0-acceptance.md).

## Self-contained build and test inputs

`Vendor/LegacyTables` holds exactly the two original CIN files used to rebuild the dictionary. `Tests/Fixtures/LegacyEngine` holds the 35 original source/header files required by the separately compiled reference engine; these files are test-only and are not part of the app target. The subset was identified using compiler dependency output, copied byte-for-byte from the original local distribution, and recorded with original relative paths and SHA-256 checksums in `Vendor/legacy-inputs-manifest.json`. No verified upstream archive URL or commit is claimed.

Both build and test scripts check the pinned inputs before use. Original file headers and the distribution notice in `Licenses/YahooKeyKey-BSD-3-Clause.txt` remain intact. No legacy installers, bundled external libraries, online services or unused input methods were imported. Keep the reference snapshot separate from production `Vendor/Generic`, `Vendor/OpenVanilla` and `Vendor/PlainVanilla`: changing both implementations together would weaken the differential tests. This removes the external folder dependency, not the documented source lineage or the separate table-license review.

## Updater platform dependencies (0.8.0)

The updater uses Foundation URLSession, CryptoKit SHA-256 and UserNotifications. Verification/handoff uses macOS-provided `pkgutil`, `spctl`, `codesign` and `open`, followed by Apple's Installer. Users do not need Xcode or `stapler`. No Sparkle framework, privileged helper, new third-party package or new dictionary data is included.

# License audit

Current release status: the maintainer confirmed the 0.8.0 review on 2026-10-14; see the final section. The dated history below preserves earlier findings and does not replace the maintainer confirmation.

## Historical audit — 2026-10-13

| Component | Evidence | Status |
| --- | --- | --- |
| YahooKeyKey source | Original `LICENSE.txt`: BSD 3-clause; retain notices and no Yahoo endorsement | Notices bundled; Yahoo branding replaced |
| OpenVanilla engine and framework headers | MIT-style permissions in individual file headers | Original headers retained; notices bundled |
| SQLite | macOS system library; no CEROD/SEE binary or extension included | Uses platform SQLite |
| Cangjie/Simplex tables | Headers credit CNS11643, opendesktop.org.tw, yylin/b6s; Cangjie also references HKSCS | **Historical merged-file redistribution rights unresolved** |
| Sinica corpus, BPMF mappings, Yahoo search terms | Source folders contain README files only; README calls out separate rights | Not bundled; Smart Zhuyin deferred |
| App icon | Generated locally with AppKit, system typography, and Chinese character 鍵 | No Yahoo artwork used |

The current [CNS11643 licensing page](https://www.cns11643.gov.tw/pageView.jsp?ID=59&SN=&la=0&lang=tw) and [government dataset record](https://data.gov.tw/dataset/5961/) describe attribution and available licensing for current CNS data. They do **not** by themselves establish the rights of every contribution in these 2012 merged CIN files. Do not equate the repository code license with dictionary clearance.

Before public distribution, record the applicable license/version and provenance of the actual historical data, including third-party additions. If those rights cannot be established, replacement data requires a separate compatibility review because candidate order may change. Keep `dictionary_rights_cleared` false until this is resolved. This audit records evidence and unresolved questions; it is not a legal determination.

## Associated-phrase starter resource

`Resources/Phrases.txt` was independently curated for ArmKeyKey from common expressions. It does not incorporate Yahoo's language-model files or associated-phrase database. The existing historical Cangjie/Simplex dictionary audit remains separate and unresolved.

## Rime Cantonese data (0.5.0)

Pinned source commit: 259f0e48bba840c3a2e0d117539e96937f3d89bc at https://github.com/rime/rime-cantonese . The project's README assigns CC BY 4.0 to its main data and separately ODbL to jyut6ping3.maps. This integration vendors only chars, words and essay-cantonese data, plus the upstream README and full CC BY license; maps and the legacy phrase table are not used. Per-file checksums are in Vendor/RimeCantonese/manifest.json. Build transformations and attribution are included in Resources/RimeCantonese-Attribution.txt and ThirdPartyNotices.txt; the full license ships with the app. ArmKeyKey supplements remain clearly distinguished from upstream data. The prior historical Cangjie/Simplex dictionary-rights gate remains unresolved; this integration does not clear publication gates or guarantee App Store acceptance.

## Project license and inventory update

Original ArmKeyKey contributions use BSD-3-Clause, copyright © 2026 jr-everstar; see `LICENSE`. This does not replace the retained MIT-style OpenVanilla/PlainVanilla permissions, Yahoo source-distribution notice, CC BY 4.0 data license or unresolved historical table rights. [Dependencies.md](Dependencies.md) records current code, data, platform and build dependencies. The current engine directly reuses upstream code and must not be described as wholly clean-room.

The full Yahoo package notice is preserved verbatim in `Licenses/YahooKeyKey-BSD-3-Clause.txt`. `Scripts/generate-notices.py` preserves distinct vendor copyright/permission blocks and generates bundled notices; build and test entry points verify they are current. The pinned Rime README and SQLite upstream copyright statement were checked on 2026-10-13. No release-readiness flag was changed.

## OpenVanilla attribution alignment — 2026-10-13

At the user's request, the app now follows OpenVanilla's presentation: retain project license text, original table headers, named contributors and source links. The user-facing table page describes provenance rather than displaying a pending-license badge. This is an attribution update, not new permission from upstream; `dictionary_rights_cleared` remains unchanged.

Verified official sources:
- Website: https://openvanilla.org/ (project MIT statement).
- Pinned project license: https://github.com/openvanilla/openvanilla/blob/a00488634ae723d3a379e158f278966948976ef1/LICENSE.txt (explicitly refers data-table licensing to each table).
- Pinned tables: https://github.com/openvanilla/openvanilla/tree/a00488634ae723d3a379e158f278966948976ef1/DataTables

`simplex-ext.cin` is byte-identical to the local YahooKeyKey source table, SHA-256 `8d925bfbd524dbc6042a1ce89912aadc17d8aa34109410a22948fd07c2d006e9`. The local Cangjie file is not byte-identical to that pinned OpenVanilla file; neither file nor ordering was replaced. Original table headers are reproduced in the bundled overview, and the complete pinned OpenVanilla project license is stored in `Licenses/OpenVanilla-Upstream-LICENSE.txt` and included in generated notices. No blanket MIT/CC0 data license is inferred.

## Maintainer acceptance for 0.8.0 — 2026-10-14

The maintainer explicitly confirmed completion of dictionary-rights review, privacy/notices approval, macOS 26/27 manual checks and clean installation acceptance. `release-readiness.json` now records that confirmation. See [acceptance record](Releases/0.8.0-acceptance.md). Earlier audit entries above describe the evidence available at those dates; this confirmation does not change upstream license text or claim that automated tooling established historical data rights. No additional legal documents were supplied in this release session. The updater adds no third-party code or dictionary data.

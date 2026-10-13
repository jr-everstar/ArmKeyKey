# Compatibility decisions

The checksum-pinned original source subset in `Tests/Fixtures/LegacyEngine` is the independent test baseline; `Vendor/LegacyTables` retains the original dictionary inputs. The retained `OVIMGeneric` and `PVCandidate` code supplies the key handling, candidate paging and selection behavior. Original CIN parsing supplies the dictionary order before character filtering. No replacement ranking model is used.

Intentional changes:

- OneKey（「一點通」）is intentionally excluded from ArmKeyKey. Do not port its shortcut menu, Yahoo search/stock/auction/map integrations, or custom website/application launch actions. It is outside the product scope, not a deferred feature.
- Dictionary lookups specify `ORDER BY seq`; legacy SQLite queries had unspecified ordering. The sequence is the original parser/converter insertion order.
- Wildcard results exclude `__property_` metadata rows. Legacy SQL could return these as visible candidates for patterns such as `*a`.
- Frequency ties explicitly use insertion order (`rowid ASC`). Learning commits each selection immediately instead of holding a session-long write transaction. This reduces lock contention and loss on process termination.
- Command, Control and Option shortcuts cancel unfinished composition and pass to the host. No global key taps or Accessibility permission are used.
- When the client requests a commit or the source deactivates, the highlighted converted candidate is committed once. Unconverted radicals are canceled. This lifecycle policy needs the manual cross-app acceptance matrix.
- Version 0.3.0 defaults to a stable compatible character profile: BMP characters, excluding private-use U+E000–U+F8FF and U+FFF0–U+FFFF. Full Unicode remains opt-in. The original Windows version filtered through the installed PMingLiU font; the original Mac version used STHeiti/AppleGothic coverage. Neither historical font coverage is reproduced exactly. For the supplied 竹戈/hi screenshot, the compatible profile has 145 candidates (17 pages) and the same first nine candidates; full Unicode has 398 (45 pages). On 2026-10-13 the user also confirmed that the original final page contains only 䑛, matching the compatible profile. Intermediate legacy pages remain unverified.
- Imported learned entries must exist in the current dictionary. Learning files use the original per-mode names internally to preserve the engine’s storage interface; the visible product is ArmKeyKey.

Vendored changes: `OVFileHelper.h` adds the missing POSIX include and replaces obsolete temporary-name creation with `mkstemp`; `OVSQLiteDatabaseService.h` adds dictionary ordering and metadata exclusion; `OVIMGeneric.cpp` adds deterministic learning ties, immediate persistence, database ownership cleanup, and filtering of learned entries against the active candidate set. Original copyright headers are retained.

Smart Zhuyin, associated phrases, reverse lookup, user phrase editing, Yahoo online integrations, and custom external tables are not part of this first Cangjie/Simplex build. No original binary installation was available for comparison.

## 0.4.0 candidate window and associated phrases

The candidate panel uses a narrow black rounded surface, white text, purple selection, numbered rows, clickable page arrows and a page counter, based on the supplied YahooKeyKey screenshot. macOS font availability may change the glyph appearance.

「選字後顯示聯想詞」 defaults on. After an explicit character commit with no pending composition, matching common phrases appear in their resource-file order. Labels show the full phrase; selection inserts only its remaining suffix. 1–9 select, Return accepts the highlight, Up/Down move it, Space/Page Down advance and Page Up goes back (phrase pages wrap). Escape dismisses; all other keys dismiss and are processed normally, including Backspace and host shortcuts. Focus changes dismiss suggestions without accepting them. Phrase suggestions never alter the Cangjie/Simplex dictionary order or learned frequencies. Disabling the setting preserves the previous behavior.

`Resources/Phrases.txt` is an independently curated starter vocabulary of common Traditional Chinese expressions, including a few Cantonese expressions. It is neither the original Yahoo associated-phrase database nor a complete predictive language model. No input is collected and no network or user-text harvesting is involved.

## 0.5.0 Cantonese integration (supersedes the starter-only phrase limitation)

The new 廣東話拼音（粵拼） mode uses a separate exact-word lookup engine with the same presentation state interface. Type concatenated LSHK Jyutping with every tone (1–6), or omit every tone. Apostrophes optionally separate syllables. Space opens candidates; only then do 1–9 select. Space/Page Down and Page Up wrap pages, arrows change the highlight, Return accepts the selected candidate, Escape cancels. Backspace from candidates resumes editing and deletes the last reading character. Return before opening candidates inserts the literal reading. Invalid readings remain editable and beep. Host shortcuts cancel and pass through. Focus changes commit a highlighted conversion once and never accept a mere associated suggestion.

Examples: `neihou`, `nei5hou2`, `nei5'hou2` → 你好; `ngo5dei6` → 我哋; `hoenggong` → 香港. This initial mode is exact whole-word lookup, not Rime's full sentence composition engine: mixed optional tones, v/x/q tone shortcuts, fuzzy pronunciation, predictive syllable completion, and adaptive Jyutping learning are not implemented. Cantonese uses its own upstream character repertoire; the compatible/full character switch applies only to Cangjie/Simplex.

Cantonese.sqlite3 includes 137,441 unique word/reading pairs and 101,745 distinct multi-character suggestion words from pinned Rime Cantonese chars/words tables plus ArmKeyKey supplements. Suggestions in all modes now use this indexed database. Frequencies come from essay-cantonese; dictionary reading percentages adjust lookup scores. Ties retain source order. This is ArmKeyKey's deterministic ranking, not a claim of identical Rime candidate order. Existing Cangjie/Simplex raw dictionary order and default learning preferences are unchanged.

## v0.8.0 (pending): optional update workflow

The updater does not change engine behavior, candidate order, learning formats or the macOS 26 / Apple Silicon requirement. Automatic version checks introduce optional HTTPS traffic; input, suggestions and learning remain local. Checks may be disabled, while manual checks remain available. Existing 0.7.2 users need to install the updater-bearing release manually once.

The updater selects the highest build compatible with the current OS and architecture, so a future release requiring a newer OS does not hide an older compatible update. Shared PKG upgrades require another input source, normal app exit, administrator authorization and logout. Personal installations require the documented manual migration; no learning data is removed. See [distribution](Distribution.md#v080-in-app-updater-installation-handoff) for acceptance limitations.

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

In the original first Cangjie/Simplex build, Smart Zhuyin and associated phrases were absent; later additions are documented below. Reverse lookup, user phrase editing, Yahoo online integrations and custom external tables remain excluded. No original binary installation was available for comparison.

## 0.4.0 candidate window and associated phrases

The candidate panel uses a narrow black rounded surface, white text, purple selection, numbered rows, clickable page arrows and a page counter, based on the supplied YahooKeyKey screenshot. macOS font availability may change the glyph appearance.

「選字後顯示聯想詞」 defaults on. After an explicit character commit with no pending composition, matching common phrases appear in their resource-file order. Labels show the full phrase; selection inserts only its remaining suffix. 1–9 select, Return accepts the highlight, Up/Down move it, Space/Page Down advance and Page Up goes back (phrase pages wrap). Escape dismisses; all other keys dismiss and are processed normally, including Backspace and host shortcuts. Focus changes dismiss suggestions without accepting them. Phrase suggestions never alter the Cangjie/Simplex dictionary order or learned frequencies. Disabling the setting preserves the previous behavior.

`Resources/Phrases.txt` is an independently curated starter vocabulary of common Traditional Chinese expressions, including a few Cantonese expressions. It is neither the original Yahoo associated-phrase database nor a complete predictive language model. No input is collected and no network or user-text harvesting is involved.

## 0.5.0 Cantonese integration (supersedes the starter-only phrase limitation)

The new 廣東話拼音（粵拼） mode uses a separate exact-word lookup engine with the same presentation state interface. Type concatenated LSHK Jyutping with every tone (1–6), or omit every tone. Apostrophes optionally separate syllables. Space opens candidates; only then do 1–9 select. Space/Page Down and Page Up wrap pages, arrows change the highlight, Return accepts the selected candidate, Escape cancels. Backspace from candidates resumes editing and deletes the last reading character. Return before opening candidates inserts the literal reading. Invalid readings remain editable and beep. Host shortcuts cancel and pass through. Focus changes commit a highlighted conversion once and never accept a mere associated suggestion.

Examples: `neihou`, `nei5hou2`, `nei5'hou2` → 你好; `ngo5dei6` → 我哋; `hoenggong` → 香港. This initial mode is exact whole-word lookup, not Rime's full sentence composition engine: mixed optional tones, v/x/q tone shortcuts, fuzzy pronunciation, predictive syllable completion, and adaptive Jyutping learning are not implemented. Cantonese uses its own upstream character repertoire; the compatible/full character switch applies only to Cangjie/Simplex.

Cantonese.sqlite3 includes 137,441 unique word/reading pairs and 101,745 distinct multi-character suggestion words from pinned Rime Cantonese chars/words tables plus ArmKeyKey supplements. Suggestions in the Cangjie/Simplex/Jyutping modes use this indexed database. Frequencies come from essay-cantonese; dictionary reading percentages adjust lookup scores. Ties retain source order. This is ArmKeyKey's deterministic ranking, not a claim of identical Rime candidate order. Existing Cangjie/Simplex raw dictionary order and default learning preferences are unchanged.

## 0.8.0 soft updates

Input engines, dictionaries and candidate order are unchanged. Optional update checks use the network while input remains offline. The client selects the highest newer build compatible with the current OS and arm64, retaining an older compatible release when the newest needs a newer OS.

0.7.2 and earlier require a manual first upgrade. Shared installations use a verified PKG, another active input source, normal app exit, administrator authorization and Installer's logout flow. Since 0.8.1, the PKG automatically backs up personal App bundles outside Input Methods before installing to the shared destination; older updater versions may still direct users to open the downloaded PKG manually. Learning data is preserved. See [installation handoff](Distribution.md#in-app-update-handoff).

## 0.9.0 Cangjie 5 and Zhuyin

Cangjie 5 uses Jackchows' Hong Kong completion table (132,420 unique code/value mappings). `mwsl` → 面, `lmsy` → 非, `hui` → 鬼. Cangjie 3 remains the default with its original table and learning filename; the two modes never combine codes or learned ranks. Character repertoire filtering applies to both Cangjie modes and Simplex, not Mandarin or Cantonese.

Traditional Zhuyin is single-syllable selection with a fixed source order. Smart Zhuyin uses local word scores to compose a sentence and lets the user override words at the cursor. Both use the standard Zhuyin keyboard only. Tone 1 completes with Space; tones 2/3/4/5 use 6/3/4/7. Numbers choose candidates only while the panel is open. Smart choices remain marked until Return or a forced commit. Left/Right/Home/End edit the sentence; Down/Space at a completed syllable opens choices. Backspace/Delete edit readings. Escape closes the panel, then cancels an unfinished syllable, then cancels the sentence. Shift-comma/period/question mark and other documented Shift punctuation commit converted text followed by Chinese punctuation. Unshifted punctuation keys may be Zhuyin vowels.

Composition is bounded to 128 syllables; an extra completed syllable remains editable and beeps. Shortcuts pass through after committing converted smart text; unfinished phonetics are canceled on forced commit or focus loss. This differs from the legacy radical cancellation policy. Output script/width conversion occurs at commit, never while calculating the caret. The candidate window uses UTF-16 selection ranges, including supplementary-plane characters.

Mandarin data contains 26,535 plain mappings and 172,663 smart mappings. 966 non-aligned symbol/emoji/variant mappings are excluded and reported by the builder to keep one output Unicode scalar per syllable. Reading keys for macros and special symbol modes are omitted. The legacy Cantonese associated suggestions are not used in either Zhuyin mode. There is no cloud input, custom phrase editor, other keyboard layout, or claim of identical Yahoo/McBopomofo candidate behavior.

Smart learning stores only explicit selected reading/value pairs from the final submitted sentence. Cancellation does not learn. A bounded score bonus influences future composition; turning learning off ignores but preserves saved preferences. Backup format 2 restores all four learning modes atomically; format 1 restores only Cangjie 3 and Simplex, retaining new-mode data.

### 0.9.1 installer relaunch handling

Background ArmKeyKey processes no longer block a PKG upgrade. The shared bundle is backed up and atomically replaced by PackageKit; all users must log out/in afterward. This fixes the process-name preinstall failure reported with 0.9.0. It does not claim that old sessions immediately switch to the newly installed engine.

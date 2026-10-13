#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/generate-notices.py --check
python3 Scripts/check-legacy-inputs.py
python3 Tests/PublishReleaseTests.py
mkdir -p build/tests
tables="Vendor/LegacyTables"
reference="Tests/Fixtures/LegacyEngine"
testdir=$(mktemp -d "${TMPDIR:-/tmp}/ArmKeyKey-tests.XXXXXX")
trap 'rm -rf "$testdir"' EXIT
flags=(-std=c++17 -DOV_USE_SQLITE -I Vendor -I Sources/Engine -Wno-parentheses -Wno-dangling-else)
xcrun clang++ "${flags[@]}" Scripts/BuildDictionary.cpp -lsqlite3 -o build/tests/build-dictionary
build/tests/build-dictionary "$tables" "$testdir/Dictionary.sqlite3"
python3 Scripts/compare-dictionaries.py Resources/Dictionary.sqlite3 "$testdir/Dictionary.sqlite3"
cp "$testdir/Dictionary.sqlite3" "$testdir/Dictionary-first.sqlite3"
build/tests/build-dictionary "$tables" "$testdir/Dictionary.sqlite3"
cmp "$testdir/Dictionary-first.sqlite3" "$testdir/Dictionary.sqlite3"
xcrun clang++ "${flags[@]}" -fsanitize=address,undefined -g Sources/Engine/Engine.cpp Vendor/Generic/OVIMGeneric.cpp Tests/EngineTests.cpp -lsqlite3 -o build/tests/engine-tests
AK_TRACE=1 build/tests/engine-tests "$testdir/Dictionary.sqlite3" "$tables" "$testdir/current" > "$testdir/current.trace"
# Compile the same adapter against untouched original engine, parser and panel sources.
xcrun clang++ -std=c++17 -DOV_USE_SQLITE -include unistd.h -I "$reference" -I Sources/Engine -Wno-parentheses -Wno-dangling-else -Wno-deprecated-declarations Sources/Engine/Engine.cpp "$reference/Generic/OVIMGeneric.cpp" Tests/EngineTests.cpp -lsqlite3 -o build/tests/reference-tests
AK_TRACE=1 build/tests/reference-tests "$testdir/Dictionary.sqlite3" "$tables" "$testdir/legacy" > "$testdir/reference.trace"
diff -u "$testdir/reference.trace" "$testdir/current.trace"
head -3 "$testdir/current.trace"
echo 'PASS source-engine differential traces and byte-identical dictionary rebuild'
xcrun swiftc Sources/macOS/LearningStore.swift Tests/LearningStoreTests.swift -o build/tests/learning-tests
CFFIXED_USER_HOME="$testdir/preferences" build/tests/learning-tests "$testdir/learning" "$testdir/Dictionary.sqlite3"

xcrun clang++ "${flags[@]}" -fsanitize=address,undefined -g Sources/Engine/Engine.cpp Vendor/Generic/OVIMGeneric.cpp Tests/CharacterFilterTests.cpp -lsqlite3 -o build/tests/character-filter-tests
build/tests/character-filter-tests "$testdir/Dictionary.sqlite3" "$testdir/character-learning"
xcrun clang++ "${flags[@]}" -fsanitize=address,undefined -g Sources/Engine/Engine.cpp Vendor/Generic/OVIMGeneric.cpp Tests/PhraseTests.cpp -lsqlite3 -o build/tests/phrase-tests
build/tests/phrase-tests "$testdir/Dictionary.sqlite3" "$testdir/phrases" Resources/Phrases.txt
python3 Scripts/build-cantonese.py "$testdir/Cantonese.sqlite3"
python3 Scripts/compare-dictionaries.py Resources/Cantonese.sqlite3 "$testdir/Cantonese.sqlite3"
cp "$testdir/Cantonese.sqlite3" "$testdir/Cantonese-first.sqlite3"
python3 Scripts/build-cantonese.py "$testdir/Cantonese.sqlite3"
cmp "$testdir/Cantonese-first.sqlite3" "$testdir/Cantonese.sqlite3"
xcrun clang++ "${flags[@]}" -fsanitize=address,undefined -g Sources/Engine/Engine.cpp Vendor/Generic/OVIMGeneric.cpp Tests/JyutpingTests.cpp -lsqlite3 -o build/tests/jyutping-tests
build/tests/jyutping-tests "$testdir/Cantonese.sqlite3"
Scripts/test-native.sh

xcrun swiftc Sources/macOS/Installation.swift Tests/InstallationPathTests.swift -o build/tests/installation-path-tests
build/tests/installation-path-tests

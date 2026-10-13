#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/generate-notices.py --check
python3 Scripts/check-legacy-inputs.py
mkdir -p build/tools
xcrun swift Scripts/MakeStatusIcon.swift
xcrun swift Scripts/MakeIcon.swift build/ArmKeyKey.iconset Resources/InputSource.tiff
xcrun swift Scripts/check-icons.swift build/ArmKeyKey.iconset Resources/InputSource.tiff
iconutil -c icns build/ArmKeyKey.iconset -o Resources/ArmKeyKey.icns
xcrun clang++ -std=c++17 -DOV_USE_SQLITE -I Vendor -Wno-parentheses -Wno-dangling-else Scripts/BuildDictionary.cpp -lsqlite3 -o build/tools/build-dictionary
build/tools/build-dictionary Vendor/LegacyTables Resources/Dictionary.sqlite3
python3 Scripts/build-new-inputs.py
python3 Scripts/build-cantonese.py
python3 Scripts/generate_project.py
xcodebuild -project ArmKeyKey.xcodeproj -scheme ArmKeyKey -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
codesign --force --sign - build/Build/Products/Release/ArmKeyKey.app
printf '\nLocal test build: %s/build/Build/Products/Release/ArmKeyKey.app\n' "$PWD"

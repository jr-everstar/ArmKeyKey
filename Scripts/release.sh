#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVELOPER_ID_APPLICATION:?Set your Developer ID Application signing identity}"
: "${NOTARY_PROFILE:?Set the notarytool keychain profile name}"
: "${ARMKEYKEY_BUNDLE_ID:=everstar.inputmethod.armkeykey.mac}"
python3 - <<'PY'
import json
from pathlib import Path
r=json.loads(Path('Documentation/release-readiness.json').read_text())
required=['dictionary_rights_cleared','macos26_manual_pass','macos27_manual_pass','clean_install_pass','privacy_and_notices_approved']
missing=[k for k in required if r.get(k) is not True]
if missing:raise SystemExit('Release gates incomplete: '+', '.join(missing))
PY
Scripts/test.sh
Scripts/build.sh
xcodebuild -project ArmKeyKey.xcodeproj -scheme ArmKeyKey -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO "PRODUCT_BUNDLE_IDENTIFIER=$ARMKEYKEY_BUNDLE_ID" build
release_app="$PWD/build/Build/Products/Release/ArmKeyKey.app"
codesign --force --sign "$DEVELOPER_ID_APPLICATION" --options runtime --timestamp "$release_app"
codesign --verify --strict --verbose=2 "$release_app"
mkdir -p build/distribution
ditto -c -k --keepParent "$release_app" build/distribution/notary-upload.zip
xcrun notarytool submit build/distribution/notary-upload.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$release_app"
xcrun stapler validate "$release_app"
spctl --assess --type execute --verbose=2 "$release_app"
ditto -c -k --keepParent "$release_app" build/distribution/ArmKeyKey.zip
shasum -a 256 build/distribution/ArmKeyKey.zip

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests/include build/tests/IMKSmoke.app/Contents/{MacOS,Resources}
cat > build/tests/include/ArmKeyKey-Swift.h <<'EOF'
#import <Foundation/Foundation.h>
@interface AKFeatureNotifications : NSObject
+ (void)showFeature:(NSString *)key enabled:(BOOL)enabled;
@end
@interface AKSettings : NSObject
+ (void)show;
+ (void)showAbout;
+ (void)checkUpdates;
+ (void)showLicenses;
@end
EOF
cp Resources/Cantonese.sqlite3 Resources/Phrases.txt Resources/Dictionary.sqlite3 build/tests/IMKSmoke.app/Contents/Resources/
ditto Resources/zh-Hant.lproj build/tests/IMKSmoke.app/Contents/Resources/zh-Hant.lproj
python3 - <<'PY'
import plistlib
from pathlib import Path
Path('build/tests/IMKSmoke.app/Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'org.armkeykey.tests.IMKSmoke','CFBundleExecutable':'IMKSmoke','CFBundlePackageType':'APPL','LSUIElement':True}))
PY
xcrun clang++ -std=c++17 -DOV_USE_SQLITE -fobjc-arc -I build/tests/include -I Sources/macOS -I Sources/Engine -I Vendor -Wno-parentheses -Wno-dangling-else Tests/IMKSmoke.mm Sources/macOS/AKInputController.mm Sources/Engine/Engine.cpp Vendor/Generic/OVIMGeneric.cpp -lsqlite3 -framework AppKit -framework InputMethodKit -framework Carbon -o build/tests/IMKSmoke.app/Contents/MacOS/IMKSmoke
native_home=$(mktemp -d "${TMPDIR:-/tmp}/ArmKeyKey-native.XXXXXX")
trap 'rm -rf "$native_home"' EXIT
CFFIXED_USER_HOME="$native_home" build/tests/IMKSmoke.app/Contents/MacOS/IMKSmoke

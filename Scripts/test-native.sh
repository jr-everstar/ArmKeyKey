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
cp Resources/Mandarin.sqlite3 Resources/Cantonese.sqlite3 Resources/Phrases.txt Resources/Dictionary.sqlite3 build/tests/IMKSmoke.app/Contents/Resources/
ditto Resources/zh-Hant.lproj build/tests/IMKSmoke.app/Contents/Resources/zh-Hant.lproj
python3 - <<'PY'
import plistlib
from pathlib import Path
Path('build/tests/IMKSmoke.app/Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'org.armkeykey.tests.IMKSmoke','CFBundleExecutable':'IMKSmoke','CFBundlePackageType':'APPL','LSUIElement':True}))
PY
xcrun clang++ -std=c++20 -DOV_USE_SQLITE -fobjc-arc -I build/tests/include -I Sources/macOS -I Sources/Engine -I Vendor -Wno-parentheses -Wno-dangling-else Tests/IMKSmoke.mm Sources/macOS/AKShortcuts.mm Sources/macOS/AKInputController.mm Sources/Engine/Engine.cpp Vendor/McBopomofo/Source/Engine/Mandarin/Mandarin.cpp Vendor/McBopomofo/Source/Engine/gramambular2/reading_grid.cpp Vendor/Generic/OVIMGeneric.cpp -lsqlite3 -framework AppKit -framework InputMethodKit -framework Carbon -o build/tests/IMKSmoke.app/Contents/MacOS/IMKSmoke
native_home=$(mktemp -d "${TMPDIR:-/tmp}/ArmKeyKey-native.XXXXXX")
trap 'rm -rf "$native_home"' EXIT
CFFIXED_USER_HOME="$native_home" build/tests/IMKSmoke.app/Contents/MacOS/IMKSmoke
xcrun swiftc Sources/macOS/FeatureNotifications.swift Tests/FeatureNotificationTests.swift -o build/tests/feature-notification-tests
build/tests/feature-notification-tests

# Exercise the actual first-login app lifecycle, then ensure completion suppresses it.
setup_test_app="$PWD/build/tests/FirstLoginSetupTests.app"
mkdir -p "$setup_test_app/Contents/MacOS"
python3 - "$setup_test_app" <<'PYTEST'
import plistlib, sys
from pathlib import Path
(Path(sys.argv[1])/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'org.armkeykey.tests.FirstLoginSetup','CFBundleExecutable':'FirstLoginSetupTests','CFBundlePackageType':'APPL','LSUIElement':True}))
PYTEST
xcrun swiftc Sources/macOS/FirstLoginSetup.swift Tests/FirstLoginSetupLifecycleTests.swift -o "$setup_test_app/Contents/MacOS/FirstLoginSetupTests"
CFFIXED_USER_HOME="$native_home" "$setup_test_app/Contents/MacOS/FirstLoginSetupTests" --first-login-setup | tee "$native_home/setup.log"
/usr/bin/grep -q "PASS real AppKit launch" "$native_home/setup.log"
CFFIXED_USER_HOME="$native_home" /usr/bin/defaults read org.armkeykey.tests.FirstLoginSetup firstLoginSetupCompleted | /usr/bin/grep -qx 1
CFFIXED_USER_HOME="$native_home" "$setup_test_app/Contents/MacOS/FirstLoginSetupTests" --first-login-setup --expect-completed

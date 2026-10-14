#!/usr/bin/env python3
"""Package an already Developer-ID-signed app; does not install or notarize it."""
import argparse, os, plistlib, subprocess, tempfile
from pathlib import Path
from xml.sax.saxutils import escape
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('app', type=Path)
p.add_argument('output', type=Path)
a = p.parse_args()
app, output = a.app.resolve(), a.output.resolve()
identity = os.environ['DEVELOPER_ID_INSTALLER']
if output.exists():
    raise SystemExit('Output already exists; choose a fresh output path')
info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'everstar.inputmethod.armkeykey.mac'
subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='ArmKeyKey-pkg-') as temp:
    temp = Path(temp)
    payload = temp/'payload'; payload.mkdir()
    subprocess.run(['ditto', str(app), str(payload/'ArmKeyKey.app')], check=True)
    components = temp/'components.plist'
    subprocess.run(['pkgbuild', '--analyze', '--root', str(payload), str(components)], check=True)
    entries = plistlib.loads(components.read_bytes())
    for entry in entries:
        entry['BundleIsRelocatable'] = False
        entry['BundleIsVersionChecked'] = True
        entry['BundleOverwriteAction'] = 'upgrade'
    components.write_bytes(plistlib.dumps(entries))
    package = temp/'ArmKeyKey-component.pkg'
    subprocess.run(['pkgbuild', '--root', str(payload), '--component-plist', str(components),
                    '--identifier', 'everstar.armkeykey.mac.pkg', '--version', info['CFBundleVersion'],
                    '--install-location', '/Library/Input Methods', '--ownership', 'recommended',
                    '--scripts', str(root/'Scripts/Installer'), str(package)], check=True)
    resources = temp/'resources'; resources.mkdir()
    (resources/'welcome.html').write_text('''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><body>
<h1>安裝 ArmKeyKey</h1><p>適用於 Apple Silicon Mac，macOS 26 或以上。</p>
<p>安裝到 /Library/Input Methods，供此 Mac 的所有使用者使用，需要管理員密碼。</p>
<p>如已安裝個人測試版，請先切換至其他輸入法，安裝程式會將舊個人版 App 移至該帳戶 Library/ArmKeyKey Installer Backup.* 備份目錄，避免重複安裝，毋須手動刪除。共用版本會另行備份至 /Library/ArmKeyKey Installer Backup.*。背景輸入法即使重新啟動亦不會阻擋安裝；安裝後所有使用者需登出再登入。</p>
<p>請保留 Application Support/ArmKeyKey 中的個人選字資料。安裝程式不會刪除個人資料。安裝完成後需要登出，請先儲存其他 App 中的工作；macOS 安裝程式會帶你完成登出流程。</p></body></html>''')
    (resources/'conclusion.html').write_text('''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><body>
<h1>安裝完成：請登出</h1><p>請按安裝程式的「登出」按鈕，然後重新登入，以更新輸入來源清單。</p>
<p>首次安裝後，重新登入會自動開啟鍵盤設定及一次性的加入步驟指引；升級使用者不會重複顯示。</p>
<p>前往「系統設定 → 鍵盤 → 文字輸入 → 編輯 → ＋ → 中文（繁體）」，加入 ArmKeyKey。</p>
<p>再從選單列切換至 ArmKeyKey。由舊測試版升級時，請移除舊輸入來源，再加入新版。</p>
<p>移除方法：切換至其他輸入法，移除設定中的輸入來源，再將 /Library/Input Methods/ArmKeyKey.app 移到垃圾桶。</p></body></html>''')
    dist = temp/'Distribution.xml'
    title = escape('ArmKeyKey '+info['CFBundleShortVersionString'])
    dist.write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
<title>{title}</title><organization>everstar.armkeykey.mac</organization>
<options customize="never" require-scripts="true" hostArchitectures="arm64"/>
<domains enable_localSystem="true" enable_currentUserHome="false" enable_anywhere="false"/>
<volume-check><allowed-os-versions><os-version min="26.0"/></allowed-os-versions></volume-check>
<welcome file="welcome.html" mime-type="text/html"/><conclusion file="conclusion.html" mime-type="text/html"/>
<choices-outline><line choice="main"/></choices-outline>
<choice id="main" visible="false" title="ArmKeyKey"><pkg-ref id="everstar.armkeykey.mac.pkg"/></choice>
<pkg-ref id="everstar.armkeykey.mac.pkg" version="{escape(info['CFBundleVersion'])}" onConclusion="RequireLogout">ArmKeyKey-component.pkg</pkg-ref>
</installer-gui-script>''')
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['productbuild', '--distribution', str(dist), '--resources', str(resources),
                    '--package-path', str(temp), '--sign', identity, '--timestamp', str(output)], check=True)
print(output)

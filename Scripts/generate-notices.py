#!/usr/bin/env python3
"""Generate bundled notices from retained license texts and vendor headers."""
import argparse
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()

def read(path):
    return (root / path).read_text(encoding='utf-8')

parts = [read('Resources/LicensingOverview.txt'),
         'ArmKeyKey — BSD 3-Clause\n\n' + read('LICENSE'),
         'YahooKeyKey — original distribution notice\n\n' + read('Licenses/YahooKeyKey-BSD-3-Clause.txt')]
groups = {}
for directory in ('Generic', 'OpenVanilla', 'PlainVanilla'):
    for path in sorted((root / 'Vendor' / directory).iterdir()):
        if path.suffix not in ('.h', '.cpp'):
            continue
        lines = path.read_text(encoding='utf-8').splitlines()
        start = next((i for i, line in enumerate(lines) if line.startswith('// Copyright')), None)
        if start is None:
            raise SystemExit(f'Missing copyright header: {path}')
        notice = []
        for line in lines[start:]:
            if not line.startswith('//'):
                break
            notice.append(line[3:] if line.startswith('// ') else line[2:])
        block = '\n'.join(notice).strip()
        if 'Permission is hereby granted' not in block or 'OTHER DEALINGS IN THE SOFTWARE.' not in block:
            raise SystemExit(f'Unrecognized or incomplete license: {path}')
        groups.setdefault(block, []).append(str(path.relative_to(root)))
for block, paths in groups.items():
    parts.append('OpenVanilla / PlainVanilla — MIT-style notice\nApplies to:\n' + '\n'.join(paths) + '\n\n' + block)
upstream_notice = 'OpenVanilla — upstream project license (data-table scope retained)\n\n' + read('Licenses/OpenVanilla-Upstream-LICENSE.txt')
parts.append(upstream_notice)
parts.extend([read('Resources/RimeCantonese-Attribution.txt'), read('Vendor/RimeCantonese/LICENSE-CC-BY')])
parts.extend([read('Resources/NotoSansTC-Attribution.txt'), read('Resources/NotoSansTC-LICENSE.txt')])
outputs = {
    'Resources/OpenVanilla-LICENSE.txt': '\n\n'.join(parts[3:3 + len(groups)] + [upstream_notice]).rstrip() + '\n',
    'Resources/YahooKeyKey-LICENSE.txt': read('Licenses/YahooKeyKey-BSD-3-Clause.txt'),
    'Resources/ThirdPartyNotices.txt': '\n\n'.join(parts).rstrip() + '\n',
    'Resources/ArmKeyKey-LICENSE.txt': read('LICENSE'),
    'Resources/RimeCantonese-LICENSE.txt': read('Vendor/RimeCantonese/LICENSE-CC-BY'),
}
for name, content in outputs.items():
    path = root / name
    if args.check:
        if not path.exists() or path.read_text(encoding='utf-8') != content:
            raise SystemExit(f'Stale license resource: {name}; run Scripts/generate-notices.py')
    else:
        path.write_text(content, encoding='utf-8')
print(f'PASS notices: {sum(map(len, groups.values()))} source files, {len(groups)} distinct permission blocks; project and Rime licenses')

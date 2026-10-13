#!/usr/bin/env python3
"""Verify the pinned dictionary inputs and independent legacy test baseline."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'Vendor/legacy-inputs-manifest.json').read_text())
expected = {entry['path']: entry['sha256'] for entry in manifest['files']}
actual = {str(path.relative_to(root))
          for directory in ('Vendor/LegacyTables', 'Tests/Fixtures/LegacyEngine')
          for path in (root / directory).rglob('*') if path.is_file() or path.is_symlink()}
errors = []
for name in sorted(actual - expected.keys()):
    errors.append(f'unpinned file: {name}')
for name, checksum in expected.items():
    path = root / name
    if path.is_symlink() or not path.is_file():
        errors.append(f'missing file or symlink: {name}')
    elif hashlib.sha256(path.read_bytes()).hexdigest() != checksum:
        errors.append(f'changed baseline: {name}')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print(f'PASS pinned legacy inputs: {len(expected)} files')

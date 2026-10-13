#!/usr/bin/env python3
"""Heuristic pre-publication check. Prints file paths, never matched secrets."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def git(*args, input=None):
    return subprocess.run(['git', '-C', str(ROOT), *args], input=input,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def main():
    candidates = git('ls-files', '--cached', '--others', '--exclude-standard', '-z')
    if candidates.returncode:
        print('FAIL: cannot enumerate repository files', file=sys.stderr)
        return 1
    names = sorted(set(filter(None, candidates.stdout.split(b'\0'))))
    ignored = git('check-ignore', '--no-index', '--stdin', '-z',
                  input=b'\0'.join(names) + b'\0') if names else None
    if ignored and ignored.returncode not in (0, 1):
        print('FAIL: cannot check ignore rules', file=sys.stderr)
        return 1
    forbidden = set(filter(None, ignored.stdout.split(b'\0'))) if ignored else set()
    patterns = {
        'private key': rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----',
        'GitHub token': rb'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})',
        'AWS access key': rb'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b',
        'service token': rb'\b(?:sk-proj-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{20,})',
        'credential assignment': rb'''(?im)^\s*(?:export\s+)?["']?(?:[\w-]*(?:password|token|secret|api_key))["']?\s*[:=]\s*["']?[A-Za-z0-9_+/=-]{16,}''',
        'personal absolute path': rb'/Users/[A-Za-z0-9_.-]+/',
    }
    findings = []
    total = 0
    for raw in names:
        name = raw.decode('utf-8', errors='surrogateescape')
        path = ROOT / name
        if raw in forbidden:
            findings.append((name, 'ignored file is tracked; remove from index'))
        if path.is_symlink():
            findings.append((name, 'symlink requires manual review'))
            continue
        if not path.exists():
            continue  # Tracked deletion, not content to publish.
        if not path.is_file():
            findings.append((name, 'non-file entry requires manual review'))
            continue
        data = path.read_bytes()
        total += len(data)
        if len(data) >= 100 * 1024 * 1024:
            findings.append((name, 'file is at least 100 MiB; review distribution location'))
        for reason, pattern in patterns.items():
            if re.search(pattern, data):
                findings.append((name, reason))
    for name, reason in findings:
        print(f'FAIL {name!r}: {reason}')
    print(f'Checked {len(names)} candidate files ({total / 1024 / 1024:.1f} MiB); '
          f'{len(findings)} findings. Heuristic scan only; review before publishing.')
    return 1 if findings else 0


if __name__ == '__main__':
    sys.exit(main())

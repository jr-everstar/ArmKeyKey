#!/usr/bin/env python3
"""Validate public stable feed metadata before deploying Pages."""
import json
from pathlib import Path
import re
import sys
from urllib.parse import urlparse


def validate(feed):
    if not isinstance(feed, dict) or type(feed.get('schemaVersion')) is not int or feed['schemaVersion'] != 1:
        raise ValueError('unsupported schemaVersion')
    if feed.get('bundleIdentifier') != 'everstar.inputmethod.armkeykey.mac' or feed.get('channel') != 'stable':
        raise ValueError('incorrect app or channel')
    releases = feed.get('releases')
    if not isinstance(releases, list):
        raise ValueError('releases must be an array; empty means no offered update')
    builds = set()
    for release in releases:
        if not isinstance(release, dict):
            raise ValueError('release must be an object')
        build = release.get('build')
        if type(build) is not int or build <= 0 or build in builds:
            raise ValueError('build must be a unique positive integer')
        builds.add(build)
        for field in ('version', 'minimumSystemVersion'):
            if not isinstance(release.get(field), str) or not re.fullmatch(r'\d+\.\d+(?:\.\d+)?', release[field]):
                raise ValueError(f'invalid {field}')
        if release.get('architectures') != ['arm64']:
            raise ValueError('only arm64 packages are supported')
        if not isinstance(release.get('notes'), str) or not release['notes'].strip():
            raise ValueError('plain-text release notes are required')
        package = release.get('package')
        if not isinstance(package, dict):
            raise ValueError('package metadata is required')
        if type(package.get('size')) is not int or package['size'] <= 0:
            raise ValueError('package size must be positive bytes')
        if not isinstance(package.get('sha256'), str) or not re.fullmatch(r'[0-9a-f]{64}', package['sha256']):
            raise ValueError('package SHA-256 must be lowercase hex')
        url = urlparse(package.get('url', ''))
        if (url.scheme != 'https' or url.netloc != 'github.com' or url.query or url.fragment
                or not re.fullmatch(r'/jr-everstar/ArmKeyKey/releases/download/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+\.pkg', url.path)):
            raise ValueError('package URL must identify a fixed release PKG in this repository')
    return len(releases)


if __name__ == '__main__':
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / 'site/updates/stable.json'
    try:
        count = validate(json.loads(path.read_text()))
    except (OSError, ValueError, TypeError, AttributeError) as error:
        raise SystemExit(f'FAIL update feed: {error}')
    print(f'PASS update feed: {count} offered releases')

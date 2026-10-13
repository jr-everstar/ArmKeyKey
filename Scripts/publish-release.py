#!/usr/bin/env python3
"""Local signed-PKG release workflow. Defaults to validation only."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
REPO = 'jr-everstar/ArmKeyKey'
TEAM = '6495K4X8W5'
BUNDLE = 'everstar.inputmethod.armkeykey.mac'
GATES = ('dictionary_rights_cleared', 'macos26_manual_pass', 'macos27_manual_pass',
         'clean_install_pass', 'privacy_and_notices_approved')


def run(*args, cwd=ROOT):
    result = subprocess.run([str(a) for a in args], cwd=cwd, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError(f'{args[0]} {args[1]} failed: {result.stderr.strip() or result.stdout.strip()}')
    return result.stdout if result.stdout else result.stderr


def gh(*args):
    return run('gh', *args)


def digest(path):
    with Path(path).open('rb') as stream:
        checksum = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            checksum.update(chunk)
        return checksum.hexdigest()


def validate_feed(feed):
    spec = importlib.util.spec_from_file_location('feed_check', ROOT / 'Scripts/check-update-feed.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.validate(feed)


def add_release(feed, entry):
    validate_feed(feed)
    for old in feed['releases']:
        if old['build'] == entry['build']:
            if old != entry:
                raise ValueError('This build is already advertised with different metadata.')
            return feed
    if any(old['build'] > entry['build'] for old in feed['releases']):
        raise ValueError('Refusing to advertise an older build as a new release.')
    feed['releases'].append(entry)
    feed['releases'].sort(key=lambda item: item['build'], reverse=True)
    validate_feed(feed)
    return feed


def inspect_package(pkg, temporary):
    signature = run('pkgutil', '--check-signature', pkg)
    if not re.search(r'Developer ID Installer: .*\(' + TEAM + r'\)', signature):
        raise ValueError('PKG is not signed by the expected Developer ID Installer team.')
    run('xcrun', 'stapler', 'validate', pkg)
    run('spctl', '--assess', '--type', 'install', '--verbose=2', pkg)
    expanded = temporary / 'expanded'
    run('pkgutil', '--expand-full', pkg, expanded)
    apps = list(expanded.glob('**/Payload/ArmKeyKey.app'))
    if len(apps) != 1:
        raise ValueError('Expected exactly one ArmKeyKey app payload.')
    app = apps[0]
    run('codesign', '--verify', '--deep', '--strict', app)
    identity = run('codesign', '-dv', '--verbose=4', app)
    if f'TeamIdentifier={TEAM}' not in identity or 'Authority=Developer ID Application:' not in identity:
        raise ValueError('Payload has an unexpected application signing identity.')
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != BUNDLE:
        raise ValueError('Unexpected payload bundle identifier.')
    if run('lipo', '-archs', app / 'Contents/MacOS' / info['CFBundleExecutable']).strip() != 'arm64':
        raise ValueError('Expected arm64-only payload.')
    packages = list(expanded.glob('**/PackageInfo'))
    if len(packages) != 1:
        raise ValueError('Unexpected component package count.')
    component = ET.parse(packages[0]).getroot()
    if (component.get('identifier') != 'everstar.armkeykey.mac.pkg'
            or component.get('install-location') != '/Library/Input Methods'
            or component.get('version') != str(info['CFBundleVersion'])):
        raise ValueError('Unexpected installer identity, destination or build.')
    source = plistlib.loads((ROOT / 'Resources/Info.plist').read_bytes())
    for key in ('CFBundleShortVersionString', 'CFBundleVersion', 'LSMinimumSystemVersion'):
        if info.get(key) != source.get(key):
            raise ValueError(f'PKG does not match source metadata: {key}')
    return info


def build_package(temporary):
    for key in ('DEVELOPER_ID_APPLICATION', 'DEVELOPER_ID_INSTALLER', 'NOTARY_PROFILE'):
        if not os.environ.get(key):
            raise ValueError(f'Set {key} locally before building.')
    print('Building, signing and notarizing app (this may take several minutes)…', flush=True)
    run('bash', 'Scripts/release.sh')
    pkg = temporary / 'build.pkg'
    run('python3', 'Scripts/build-pkg.py', ROOT / 'build/Build/Products/Release/ArmKeyKey.app', pkg)
    response = json.loads(run('xcrun', 'notarytool', 'submit', pkg, '--keychain-profile',
                              os.environ['NOTARY_PROFILE'], '--wait', '--output-format', 'json'))
    if response.get('status') != 'Accepted':
        raise ValueError('Apple has not accepted the PKG notarization submission.')
    run('xcrun', 'stapler', 'staple', pkg)
    return pkg


def ensure_asset(tag, target, package, notes, temporary):
    # Listing is read-only and errors (including authentication) never mean "absent".
    releases = json.loads(gh('api', '--paginate', '--slurp', f'repos/{REPO}/releases?per_page=100'))
    release = next((r for page in releases for r in page if r['tag_name'] == tag), None)
    refs = run('git', 'ls-remote', f'https://github.com/{REPO}.git',
               f'refs/tags/{tag}', f'refs/tags/{tag}^{{}}').splitlines()
    if refs:
        # Resolve annotated as well as lightweight tags using the commit API.
        resolved = json.loads(gh('api', f'repos/{REPO}/commits/{tag}'))['sha']
        if resolved != target:
            raise ValueError('Release tag already points to another source commit.')
    if release and release['prerelease']:
        raise ValueError('Existing tag belongs to a prerelease.')
    if release and release['draft'] and release.get('target_commitish') != target:
        raise ValueError('Existing draft has a different release target.')
    if not release:
        gh('release', 'create', tag, '--repo', REPO, '--target', target, '--draft',
           '--title', f'ArmKeyKey {tag}', '--notes-file', notes)
    assets = release['assets'] if release else []
    if not any(asset['name'] == package.name for asset in assets):
        if release and not release['draft']:
            raise ValueError('Published release lacks this asset; refusing to alter it.')
        gh('release', 'upload', tag, package, '--repo', REPO)  # Never --clobber.
    downloaded = temporary / 'downloaded'
    downloaded.mkdir()
    gh('release', 'download', tag, '--repo', REPO, '--pattern', package.name, '--dir', downloaded)
    if digest(downloaded / package.name) != digest(package):
        raise ValueError('Remote asset differs from the verified PKG; nothing is overwritten.')
    if not release or release['draft']:
        gh('release', 'edit', tag, '--repo', REPO, '--draft=false', '--latest=false')
    url = f'https://github.com/{REPO}/releases/download/{tag}/{package.name}'
    # Verify anonymous public availability before ever proposing a feed update.
    public = temporary / 'public.pkg'
    with urllib.request.urlopen(url, timeout=60) as response, public.open('wb') as output:
        shutil.copyfileobj(response, output)
    if digest(public) != digest(package):
        raise ValueError('Public download checksum mismatch; feed PR was not created.')
    return url


def feed_pr(entry, temporary):
    checkout = temporary / 'feed-repository'
    gh('repo', 'clone', REPO, checkout, '--', '--depth', '1', '--branch', 'main')
    path = checkout / 'site/updates/stable.json'
    previous = json.loads(path.read_text())
    updated = add_release(json.loads(path.read_text()), entry)
    if previous == updated:
        print('This exact update is already on main; no PR needed.')
        return
    branch = f'updates/build-{entry["build"]}'
    # Existing PRs are reused only if the proposed feed is exactly the same.
    prs = json.loads(gh('pr', 'list', '--repo', REPO, '--head', branch, '--state', 'open', '--json', 'url'))
    refs = run('git', 'ls-remote', '--heads', f'https://github.com/{REPO}.git', branch).strip()
    if refs:
        run('git', 'fetch', 'origin', branch, cwd=checkout)
        remote = json.loads(run('git', 'show', 'FETCH_HEAD:site/updates/stable.json', cwd=checkout))
        if remote != updated:
            raise ValueError('Update branch differs; review the existing branch instead of overwriting it.')
    else:
        run('git', 'switch', '-c', branch, cwd=checkout)
        path.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + '\n')
        user = json.loads(gh('api', 'user'))
        run('git', 'config', 'user.name', user['login'], cwd=checkout)
        run('git', 'config', 'user.email', f'{user["id"]}+{user["login"]}@users.noreply.github.com', cwd=checkout)
        run('git', 'add', 'site/updates/stable.json', cwd=checkout)
        run('git', 'commit', '-m', f'Offer ArmKeyKey {entry["version"]} build {entry["build"]}', cwd=checkout)
        run('git', 'push', '-u', 'origin', branch, cwd=checkout)
    if prs:
        print('Existing update PR:', prs[0]['url'])
        return
    body = temporary / 'pr-body.txt'
    body.write_text(f'Offer ArmKeyKey {entry["version"]} (build {entry["build"]}) through the stable feed.\n\n'
                    'The local publisher verified installer/app signatures, the stapled notarization ticket, '
                    'Gatekeeper assessment and both authenticated and public download checksums. '
                    'Merge after reviewing release readiness; Pages deploys automatically.\n')
    print(gh('pr', 'create', '--repo', REPO, '--base', 'main', '--head', branch,
             '--title', f'Offer ArmKeyKey {entry["version"]} build {entry["build"]}', '--body-file', body).strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--pkg', type=Path, help='Existing signed, notarized and stapled PKG')
    mode.add_argument('--build', action='store_true', help='Build and notarize app and PKG locally')
    parser.add_argument('--notes-file', required=True, type=Path, help='UTF-8 release notes; will be public')
    parser.add_argument('--publish', action='store_true', help='Actually publish release and create feed PR')
    args = parser.parse_args()
    notes = args.notes_file.resolve().read_text().strip()
    if not notes:
        raise ValueError('Release notes cannot be empty.')
    readiness = json.loads((ROOT / 'Documentation/release-readiness.json').read_text())
    missing = [key for key in GATES if readiness.get(key) is not True]
    if missing:
        print('Release gates incomplete:', ', '.join(missing))
        if args.publish:
            raise ValueError('Complete documented release checks before publishing; no bypass flag is provided.')
    if args.build and not args.publish:
        print('Preview: tests → app signing/notarization → PKG signing/notarization/staple → verification '
              '→ Draft Release/upload → publish/download verification → feed PR. No build or upload performed.')
        return
    if args.publish:
        if run('git', 'status', '--porcelain').strip():
            raise ValueError('Commit source changes before publishing; source tree must be clean.')
        target = run('git', 'rev-parse', 'HEAD').strip()
        gh('auth', 'status')
        gh('api', f'repos/{REPO}/commits/{target}')  # Commit must already exist in the destination repo.
    with tempfile.TemporaryDirectory(prefix='ArmKeyKey-publish-') as folder:
        temporary = Path(folder)
        source_pkg = build_package(temporary) if args.build else args.pkg.resolve()
        if not source_pkg.is_file() or source_pkg.suffix != '.pkg':
            raise ValueError('Provide an existing .pkg file.')
        package = temporary / 'verified.pkg'
        shutil.copyfile(source_pkg, package)
        info = inspect_package(package, temporary)
        version, build = info['CFBundleShortVersionString'], int(info['CFBundleVersion'])
        if not re.fullmatch(r'\d+\.\d+(?:\.\d+)?', version) or build <= 0:
            raise ValueError('Invalid package version or build.')
        tag = f'v{version}-build{build}'
        named = temporary / f'ArmKeyKey-{version}-build{build}-mac-arm64.pkg'
        package.rename(named)
        entry = {'version': version, 'build': build, 'minimumSystemVersion': info['LSMinimumSystemVersion'],
                 'architectures': ['arm64'], 'notes': notes,
                 'package': {'url': f'https://github.com/{REPO}/releases/download/{tag}/{named.name}',
                             'size': named.stat().st_size, 'sha256': digest(named)}}
        add_release(json.loads((ROOT / 'site/updates/stable.json').read_text()), entry)
        print(json.dumps(entry, ensure_ascii=False, indent=2))
        if not args.publish:
            print('Validation only. No GitHub changes. Add --publish to execute after release gates pass.')
            return
        # Preserve completed package even if a later upload/PR step fails.
        saved = ROOT / 'build/distribution' / tag / named.name
        saved.parent.mkdir(parents=True, exist_ok=True)
        if saved.exists() and digest(saved) != digest(named):
            raise ValueError('Local release package already exists with different contents.')
        if not saved.exists():
            shutil.copyfile(named, saved)
        note_path = temporary / 'release-notes.txt'
        note_path.write_text(notes + '\n')
        ensure_asset(tag, target, named, note_path, temporary)
        feed_pr(entry, temporary)
        print('Release published. Feed becomes live only after its PR is merged. Saved PKG:', saved)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, ValueError, OSError, KeyError) as error:
        raise SystemExit(f'ERROR: {error}')

#!/usr/bin/env python3
"""Read-only macOS app inventory; outputs JSON for reviewing app installations."""

import argparse
import concurrent.futures
import datetime
import json
import os
import plistlib
import re
import subprocess
from pathlib import Path
from xml.parsers.expat import ExpatError


def command(*args):
    try:
        result = subprocess.run(args, check=False, capture_output=True, text=True, timeout=60)
        return result.stdout.strip() if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def applications(roots):
    for root in roots:
        for directory, children, _ in os.walk(root):
            for name in list(children):
                if name.endswith('.app'):
                    yield Path(directory) / name
                    children.remove(name)  # Do not count embedded helpers as separate apps.


def inspect(path):
    info = {}
    error = None
    wrapped = path / 'WrappedBundle'
    bundle = wrapped if wrapped.is_dir() else path
    plist = bundle / 'Info.plist' if wrapped.is_dir() else bundle / 'Contents/Info.plist'
    try:
        with plist.open('rb') as stream:
            info = plistlib.load(stream)
    except (OSError, ValueError, ExpatError) as exc:
        error = str(exc)
    executable_dir = bundle if wrapped.is_dir() else bundle / 'Contents/MacOS'
    executable_name = info.get('CFBundleExecutable')
    inferred_executable = not executable_name and (executable_dir / path.stem).is_file()
    executable = executable_dir / (executable_name or (path.stem if inferred_executable else '__missing__'))
    file_type = command('/usr/bin/file', '-b', str(executable))
    architectures = command('/usr/bin/lipo', '-archs', str(executable))
    if not architectures and file_type and file_type.startswith('Mach-O'):
        architectures = ' '.join(sorted(set(re.findall(r'\b(?:x86_64|arm64e?|i386|ppc_7400)\b', file_type))))
    metadata = command('/usr/bin/mdls', '-plist', '-', '-name', 'kMDItemLastUsedDate',
                       '-name', 'kMDItemUseCount', str(path))
    usage = {}
    if metadata:
        try:
            usage = plistlib.loads(metadata.encode())
        except (ValueError, ExpatError):
            pass
    size = command('/usr/bin/du', '-sk', str(path))
    return {
        'path': str(path), 'name': path.stem,
        'bundle_id': info.get('CFBundleIdentifier'),
        'version': info.get('CFBundleShortVersionString', info.get('CFBundleVersion')),
        'executable': str(executable),
        'executable_inferred_from_name': inferred_executable,
        'architectures': architectures,
        'file_type': file_type,
        'last_used': usage.get('kMDItemLastUsedDate'),
        'use_count': usage.get('kMDItemUseCount'),
        'metadata_available': metadata is not None,
        'allocated_kib': int(size.split()[0]) if size else None,
        'app_store_receipt': (path / 'Contents/_MASReceipt/receipt').exists() or (bundle / '_MASReceipt/receipt').exists(),
        'wrapped_ios_app': wrapped.is_dir(),
        'plist_error': error,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, action='append',
                        help='App directory to scan; repeatable (default: /Applications and ~/Applications).')
    parser.add_argument('--output', type=Path, help='Write JSON here instead of stdout.')
    args = parser.parse_args()
    roots = args.root or [Path('/Applications'), Path.home() / 'Applications']
    paths = sorted(set(applications(roots)))
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        apps = list(pool.map(inspect, paths))
    result = json.dumps({'collected_at': datetime.datetime.now(datetime.UTC).isoformat(),
                         'roots': [str(root) for root in roots], 'apps': apps},
                        indent=2, default=str) + '\n'
    if args.output:
        args.output.write_text(result)
    else:
        print(result, end='')


if __name__ == '__main__':
    main()

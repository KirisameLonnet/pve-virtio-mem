#!/usr/bin/env python3
"""Fetch exact upstream commits into a new, project-owned build directory."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def checkout(spec, destination):
    if not re.fullmatch(r'[0-9a-f]{40}', spec['commit']):
        raise RuntimeError('Expected an exact source commit')
    if not re.fullmatch(r'https://github.com/luhsra/[a-z0-9-]+\.git', spec['repository']):
        raise RuntimeError('Unexpected upstream repository')
    if destination.is_symlink():
        raise RuntimeError('Refusing a symlink checkout destination')
    destination.mkdir(parents=True, exist_ok=True)
    if any(destination.iterdir()):
        raise RuntimeError(f'Checkout destination is not empty: {destination.name}')
    subprocess.run(['git', 'init', '-q', str(destination)], check=True)
    subprocess.run(['git', '-C', str(destination), 'fetch', '-q', '--depth=1', '--no-tags',
                    spec['repository'], spec['commit']], check=True)
    subprocess.run(['git', '-C', str(destination), '-c', 'core.hooksPath=/dev/null',
                    'checkout', '-q', '--detach', 'FETCH_HEAD'], check=True)
    actual = subprocess.check_output(['git', '-C', str(destination), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != spec['commit']:
        raise RuntimeError('Source revision did not match the lock file')


def main():
    root = Path(os.environ['PROJECT_TMP_ROOT']).resolve()
    destination = Path(sys.argv[1]).resolve()
    if not destination.is_relative_to(root / 'build'):
        raise RuntimeError('Build directory must be under the project build root')
    sources = json.loads(Path(__file__).with_name('sources.json').read_text())
    checkout(sources['qemu'], destination / 'qemu')
    checkout(sources['linux'], destination / 'linux')
    # Both upstream parents pin the same ABI revision. Do not follow their
    # SSH submodule URLs or recursively fetch unrelated ROM/benchmark projects.
    for parent, path in [('qemu', 'subprojects/llfree-c/llc'), ('linux', 'mm/llfree/llc')]:
        recorded = subprocess.check_output(
            ['git', '-C', str(destination / parent), 'ls-tree', 'HEAD', path], text=True,
        ).split()
        if recorded[:2] != ['160000', 'commit'] or recorded[2] != sources['llfree']['commit']:
            raise RuntimeError('Allocator ABI revision does not match its parent source')
        checkout(sources['llfree'], destination / parent / path)
    applied = {}
    for patch in sorted(Path(__file__).with_name('patches').glob('linux-*.patch')):
        command = ['git', '-C', str(destination / 'linux'), 'apply', '--whitespace=error']
        subprocess.run(command + ['--check', str(patch)], check=True)
        subprocess.run(command + [str(patch)], check=True)
        applied[patch.name] = hashlib.sha256(patch.read_bytes()).hexdigest()
    (destination / 'sources.json').write_text(json.dumps(sources, indent=2) + '\n')
    (destination / 'applied-patches.json').write_text(json.dumps(applied, indent=2) + '\n')


if __name__ == '__main__':
    main()

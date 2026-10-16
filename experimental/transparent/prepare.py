#!/usr/bin/env python3
"""Fetch exact upstream commits into a new, project-owned build directory."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

REPOSITORIES = {
    'https://github.com/qemu/qemu.git',
    'https://github.com/torvalds/linux.git',
    'https://github.com/luhsra/llfree-c.git',
}


def checkout(spec, destination):
    if not re.fullmatch(r'[0-9a-f]{40}', spec['commit']):
        raise RuntimeError('Expected an exact source commit')
    if spec['repository'] not in REPOSITORIES:
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
    applied = {}
    for parent in ('qemu', 'linux'):
        patches = sorted(Path(__file__).with_name('patches').glob(parent + '-*.patch'))
        if not patches:
            raise RuntimeError(f'Missing {parent} source port')
        for patch in patches:
            command = ['git', '-C', str(destination / parent), 'apply', '--whitespace=error']
            subprocess.run(command + ['--check', str(patch)], check=True)
            subprocess.run(command + [str(patch)], check=True)
            applied[patch.name] = hashlib.sha256(patch.read_bytes()).hexdigest()
    # Both ports use the same explicitly pinned shared-metadata ABI. Do not
    # recursively follow unrelated ROM, benchmark or SSH submodule URLs.
    for parent, path in [('qemu', 'subprojects/llfree-c/llc'), ('linux', 'mm/llfree/llc')]:
        checkout(sources['llfree'], destination / parent / path)
    (destination / 'sources.json').write_text(json.dumps(sources, indent=2) + '\n')
    (destination / 'applied-patches.json').write_text(json.dumps(applied, indent=2) + '\n')


if __name__ == '__main__':
    main()

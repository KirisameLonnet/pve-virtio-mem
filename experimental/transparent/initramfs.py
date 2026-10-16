#!/usr/bin/env python3
"""Reproducible newc initramfs for the freestanding synthetic test guest."""
import gzip
from pathlib import Path
import stat
import sys


def entry(name, mode, payload=b'', major=0, minor=0):
    encoded = name.encode() + b'\0'
    fields = [0, mode, 0, 0, 1, 0, len(payload), 0, 0, major, minor, len(encoded), 0]
    header = b'070701' + ''.join(f'{value:08x}' for value in fields).encode()
    result = header + encoded
    result += b'\0' * (-len(result) % 4)
    result += payload
    return result + b'\0' * (-len(payload) % 4)


if __name__ == '__main__':
    content = b''.join([
        entry('dev', stat.S_IFDIR | 0o755),
        entry('proc', stat.S_IFDIR | 0o755),
        entry('dev/console', stat.S_IFCHR | 0o600, major=5, minor=1),
        entry('init', stat.S_IFREG | 0o755, Path(sys.argv[1]).read_bytes()),
        entry('TRAILER!!!', 0),
    ])
    Path(sys.argv[2]).write_bytes(gzip.compress(content, mtime=0))

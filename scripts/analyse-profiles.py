#!/usr/bin/env python3
"""Summarise temporary Valgrind CPU/allocation captures, not a performance gate."""
from pathlib import Path
import subprocess
import sys

report = Path(sys.argv[1]).resolve()
cpu, heap = [], []
for kind, rows in (('cpu', cpu), ('heap', heap)):
    for path in report.glob(f'{kind}.*'):
        if not path.name.split('.')[-1].isdigit():
            continue
        lines = path.read_text().splitlines()
        cmd = next((line[5:] for line in lines if line.startswith('cmd: ')), '')
        marker = 'summary: ' if kind == 'cpu' else 'totals: '
        counts = next((list(map(int, line.split()[1:])) for line in lines
                       if line.startswith(marker)), [])
        if counts:
            # Xt memory events: curB curBk totB totBk totFdB totFdBk.
            score = counts[0] if kind == 'cpu' else counts[2]
            rows.append((score, counts, cmd, path))

out = [f'CPU captures: {len(cpu)}; allocation captures: {len(heap)}.\n',
       'CPU units are instrumented instructions, not latency. Heap units are '
       'cumulative bytes and objects. Paired runs execute the same test workload.\n']
for kind, rows in (('CPU instructions', cpu), ('Allocated bytes/objects', heap)):
    out += [f'\n## Largest {kind.lower()} processes\n']
    for score, counts, cmd, path in sorted(rows, key=lambda row: row[0], reverse=True)[:6]:
        value = str(score) if kind.startswith('CPU') else f'{score} / {counts[3]}'
        # Public conclusions must not retain host paths or arbitrary arguments.
        label = ('perl tests/virtio-mem/adapter.t'
                 if cmd.endswith('/tests/virtio-mem/adapter.t')
                 else 'profiled helper (arguments omitted)')
        out.append(f'* {value}: {label}\n')
        target = Path(str(path) + '.top.txt')
        if not target.exists() or not target.stat().st_size:
            with target.open('w') as stream:
                subprocess.run(['callgrind_annotate', '--inclusive=yes', '--threshold=95',
                                str(path)], stdout=stream, stderr=subprocess.DEVNULL,
                               check=False)
(report / 'profile-summary.md').write_text(''.join(out))
print(''.join(out))
if not cpu or not heap:
    raise SystemExit('Missing captures: do not accept the profiling gate')

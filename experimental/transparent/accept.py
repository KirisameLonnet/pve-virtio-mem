#!/usr/bin/env python3
"""Isolated capacity/reclaim/reuse acceptance; never connects to a PVE VM.

This launches a new TCG guest with no disks, network or passed-through devices.
It does not prove VFIO/GPU safety or PVE compatibility.
"""
import argparse
import json
import os
from pathlib import Path
import selectors
import subprocess
import tempfile
import time


def rss_bytes(pid):
    for line in Path(f'/proc/{pid}/status').read_text().splitlines():
        if line.startswith('VmRSS:'):
            return int(line.split()[1]) * 1024
    raise RuntimeError('QEMU RSS is unavailable')


def validate(phases, samples, memory_mib):
    expected = ['baseline', 'allocated_1', 'freed_1', 'idle_1',
                'allocated_2', 'freed_2', 'idle_2', 'pass']
    if list(phases) != expected:
        raise RuntimeError('Guest did not complete both allocation/reuse cycles')
    totals = {phase['mem_total_kib'] for phase in phases.values()}
    if len(totals) != 1:
        raise RuntimeError('Guest-visible memory capacity changed')
    total = totals.pop()
    if not memory_mib * 1024 * 7 // 8 <= total <= memory_mib * 1024:
        raise RuntimeError('Guest-visible capacity does not match configured memory')
    reclaimed = []
    for i in (1, 2):
        peak_samples = samples.get(f'allocated_{i}', [])
        idle_samples = samples.get(f'freed_{i}', [])
        if not peak_samples or not idle_samples:
            raise RuntimeError('Missing physical-memory measurements')
        payload = phases[f'allocated_{i}']['allocation_bytes']
        if not total * 1024 * 85 // 100 <= payload <= total * 1024:
            raise RuntimeError('Guest did not exercise most of its visible capacity')
        drop = max(peak_samples) - min(idle_samples)
        if drop < payload // 2:
            raise RuntimeError(f'Insufficient physical reclaim in round {i}: {drop} bytes')
        reclaimed.append(drop)
    return {
        'scope': 'isolated TCG; no VFIO device and no PVE integration',
        'guest_mem_total_kib': total, 'reclaimed_bytes': reclaimed, 'cycles': 2,
        'fixed_guest_capacity': True, 'allocated_data_preserved': True,
    }


def run(build, memory_mib, timeout, auto_reclaim=True):
    device = {
        'driver': 'virtio-llfree-balloon-pci', 'auto-mode': auto_reclaim,
        'auto-mode-iothread': 'reclaim',
        'iothread-vq-mapping': [{'iothread': 'install'}],
    }
    with tempfile.TemporaryDirectory(prefix='accept-', dir=build) as scratch:
        log = Path(scratch) / 'guest.log'
        emulator_log = Path(scratch) / 'qemu.log'
        command = [
            str(build / 'qemu-build/qemu-system-x86_64'),
            '-machine', 'q35,accel=tcg', '-cpu', 'max', '-smp', '1',
            '-m', str(memory_mib), '-nodefaults', '-no-reboot', '-display', 'none',
            '-serial', 'stdio', '-monitor', 'none',
            '-kernel', str(build / 'linux-build/arch/x86/boot/bzImage'),
            '-initrd', str(build / 'initramfs.gz'),
            '-append', 'console=ttyS0 rdinit=/init panic=-1',
            '-object', 'iothread,id=reclaim', '-object', 'iothread,id=install',
            '-device', json.dumps(device, separators=(',', ':')),
        ]
        samples, phases = {}, {}
        phase = 'boot'
        start = time.monotonic()
        try:
            with log.open('w') as output, emulator_log.open('w') as errors, subprocess.Popen(
                command, stdout=subprocess.PIPE, stderr=errors,
            ) as process:
                selector = selectors.DefaultSelector()
                selector.register(process.stdout, selectors.EVENT_READ)
                pending = b''
                try:
                    while time.monotonic() - start < timeout:
                        if process.poll() is not None:
                            raise RuntimeError(f'QEMU exited with {process.returncode}')
                        samples.setdefault(phase, []).append(rss_bytes(process.pid))
                        for key, _ in selector.select(timeout=0.25):
                            chunk = os.read(key.fileobj.fileno(), 65536)
                            if not chunk:
                                raise RuntimeError('Guest console closed before acceptance completed')
                            pending += chunk
                            while b'\n' in pending:
                                raw, pending = pending.split(b'\n', 1)
                                line = raw.decode(errors='replace').strip()
                                output.write(line + '\n')
                                output.flush()
                                if line.startswith('TRANSPARENT FAIL'):
                                    raise RuntimeError(line)
                                if line.startswith('TRANSPARENT {'):
                                    record = json.loads(line[len('TRANSPARENT '):])
                                    phase = record['phase']
                                    phases[phase] = record
                                    print(json.dumps(record), flush=True)
                        if phase == 'pass':
                            break
                    else:
                        raise RuntimeError('Guest acceptance timed out')
                finally:
                    selector.close()
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
            return validate(phases, samples, memory_mib)
        except Exception:
            # Diagnose in the owning run, then TemporaryDirectory disposes logs.
            for capture in (log, emulator_log):
                if capture.exists():
                    print(capture.name + ':', flush=True)
                    print('\n'.join(capture.read_text(errors='replace').splitlines()[-40:]), flush=True)
            raise


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('build', type=Path)
    parser.add_argument('--memory-mib', type=int, default=512)
    parser.add_argument('--timeout', type=int, default=300)
    parser.add_argument('--no-auto-reclaim', action='store_true',
                        help='Negative control: disable soft reclaim; reclaim validation should fail')
    args = parser.parse_args()
    root = Path(os.environ['PROJECT_TMP_ROOT']).resolve() / 'build'
    build = args.build.resolve()
    if not build.is_relative_to(root) or not 256 <= args.memory_mib <= 2048:
        parser.error('Use a project-owned build and 256–2048 MiB test guest')
    print(json.dumps(run(build, args.memory_mib, args.timeout, not args.no_auto_reclaim), indent=2))

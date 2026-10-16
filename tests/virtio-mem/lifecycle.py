"""Real GNU patch and package journal operations against synthetic PVE fixtures."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix='lifecycle-', dir=os.environ.get('TMPDIR'))
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.originals = {}
        for patch in (REPO / 'patches').glob('*.patch'):
            lines = patch.read_text().splitlines(keepends=True)
            relative = lines[1].strip().split(' b/', 1)[1]
            content = []
            for line in lines[2:]:
                if line.startswith('@@'):
                    start = int(re.match(r'@@ -(\d+)', line)[1])
                    while len(content) < start - 1:
                        content.append('# synthetic upstream context\n')
                elif line.startswith((' ', '-')):
                    content.append(line[1:])
            data = ''.join(content).encode()
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            self.originals[relative] = data
        self.checksums()

    def checksums(self):
        for package in ('qemu-server', 'pve-manager'):
            path = self.root / f'var/lib/dpkg/info/{package}.md5sums'
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(''.join(f'{hashlib.md5(data).hexdigest()}  {name}\n'
                                    for name, data in self.originals.items()
                                    if ('/pve-manager/' in name) == (package == 'pve-manager')))

    def run_tool(self, action, success=True):
        result = subprocess.run([sys.executable, str(REPO/'tools/pve-virtio-mem-patch'),
                                 action, '--root', str(self.root), '--patches', str(REPO/'patches')],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def snapshot(self):
        return {name:(self.root/name).read_bytes() for name in self.originals}

    def test_roundtrip_idempotency(self):
        self.run_tool('apply')
        applied = self.snapshot()
        self.assertNotEqual(applied, self.originals)
        self.run_tool('apply')
        self.assertEqual(applied, self.snapshot())
        self.run_tool('status')
        self.run_tool('revert')
        self.assertEqual(self.originals, self.snapshot())

    def test_preflight_no_partial_write(self):
        name = 'usr/share/perl5/PVE/QemuServer/Monitor.pm'
        (self.root/name).write_bytes(b'unsupported version\n')
        self.originals[name] = b'unsupported version\n'
        self.checksums()
        before = self.snapshot()
        self.run_tool('apply', False)
        self.assertEqual(before, self.snapshot())

    def test_admin_change_rejected_apply_and_revert(self):
        self.run_tool('apply')
        path = self.root/next(iter(self.originals))
        path.write_bytes(path.read_bytes()+b'# administrator edit\n')
        before = self.snapshot()
        self.run_tool('apply', False)
        self.run_tool('revert', False)
        self.assertEqual(before, self.snapshot())

    def test_partial_package_upgrade(self):
        self.run_tool('apply')
        name = next(iter(self.originals))
        self.originals[name] += b'# new package revision\n'
        (self.root/name).write_bytes(self.originals[name])
        self.checksums()
        self.run_tool('apply')
        self.run_tool('revert')
        self.assertEqual(self.originals, self.snapshot())

    def test_interrupted_apply_can_resume(self):
        self.run_tool('apply')
        name = next(iter(self.originals))
        (self.root/name).write_bytes(self.originals[name])
        self.run_tool('status', False)
        self.run_tool('apply')
        self.run_tool('status')

    def test_frontend_upgrade_and_rollback(self):
        self.run_tool('apply')
        name = 'usr/share/pve-manager/js/pvemanagerlib.js'
        self.originals[name] += b'// new pve-manager revision\n'
        (self.root/name).write_bytes(self.originals[name])
        self.checksums()
        self.run_tool('apply')
        self.run_tool('status')
        self.run_tool('revert')
        self.assertEqual(self.originals, self.snapshot())

    def test_frontend_admin_edit_is_not_overwritten(self):
        self.run_tool('apply')
        path = self.root/'usr/share/pve-manager/js/pvemanagerlib.js'
        path.write_bytes(path.read_bytes() + b'// administrator edit\n')
        before = self.snapshot()
        result = self.run_tool('apply', False)
        self.assertIn('installed pve-manager package', result.stderr)
        self.run_tool('revert', False)
        self.assertEqual(before, self.snapshot())

    def test_frontend_preflight_prevents_backend_writes(self):
        name = 'usr/share/pve-manager/js/pvemanagerlib.js'
        self.originals[name] = b'// incompatible pve-manager source\n'
        (self.root/name).write_bytes(self.originals[name])
        self.checksums()
        before = self.snapshot()
        self.run_tool('apply', False)
        self.assertEqual(before, self.snapshot())

    def test_damaged_backup_rejected(self):
        self.run_tool('apply')
        path = self.root/'var/lib/pve-virtio-mem/state.json'
        state = json.loads(path.read_text())
        state[next(iter(state))]['original'] = base64.b64encode(b'corrupt').decode()
        path.write_text(json.dumps(state))
        before = self.snapshot()
        self.run_tool('apply', False)
        self.run_tool('revert', False)
        self.assertEqual(before, self.snapshot())

    def test_config_prevents_uninstall(self):
        self.run_tool('apply')
        path = self.root/'etc/pve/nodes/example/qemu-server/9000.conf'
        path.parent.mkdir(parents=True)
        path.write_text('virtio-mem: 12288\n')
        self.run_tool('revert', False)
        path.unlink()
        self.run_tool('revert')


if __name__ == '__main__':
    unittest.main()

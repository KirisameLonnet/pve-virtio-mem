"""Validate generated options in paused QEMU/TCG, without disks or passthrough."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

repo = Path(__file__).resolve().parents[2]
qemu = shutil.which('kvm') or shutil.which('qemu-system-x86_64')
if not qemu:
    raise SystemExit('QEMU is required for the optional smoke check')
code = r'''
use JSON::PP;
require $ARGV[0];
sub PVE::QemuServer::Memory::get_current_memory { return $_[0]; }
my @cmd;
PVE::QemuServer::VirtioMem::config(
    { memory => 4096, 'virtio-mem' => 2048, balloon => 2048,
      numa => 1, machine => 'q35', ostype => 'l26' },
    9000, 1, 2, 0, 0, \@cmd, {},
);
print encode_json(\@cmd);
'''
options = json.loads(subprocess.check_output(['perl','-e',code,str(repo/'tools/VirtioMem.pm')]))
commands = [
    {'execute':'qmp_capabilities'},
    {'execute':'query-memory-devices'},
    {'execute':'qom-set','arguments':{'path':'machine/peripheral/vmem0',
                                     'property':'requested-size','value':1024*1024*1024}},
    {'execute':'query-memory-devices'},
    {'execute':'quit'},
]
result = subprocess.run([qemu,'-machine','q35','-accel','tcg','-S','-nodefaults',
                         '-display','none','-smp','2','-qmp','stdio',*options],
                        input='\n'.join(map(json.dumps,commands))+'\n',
                        capture_output=True,text=True,timeout=30)
if result.returncode:
    sys.exit(result.stderr)
responses = [json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')]
assert not any('error' in entry for entry in responses), responses
devices = [entry['return'][0]['data'] for entry in responses if isinstance(entry.get('return'),list)]
assert len(devices)==2 and devices[0]['size']==0, devices
assert devices[1]['requested-size']==1024*1024*1024 and devices[1]['size']==0, devices
print('QEMU accepts generated topology and QMP resize; paused guest size remains zero as expected')

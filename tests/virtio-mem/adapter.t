use strict;
use warnings;
use Test::More;
use FindBin;
require "$FindBin::Bin/../../tools/VirtioMem.pm";

# Only PVE's memory-property parser is stubbed. All adapter behavior is real.
sub PVE::QemuServer::Memory::get_current_memory { return $_[0]; }
my $conf = { memory => 16384, 'virtio-mem' => 12288, balloon => 4096,
             machine => 'q35', ostype => 'l26', numa => 1 };
my $mib = 1024 * 1024;
ok(!PVE::QemuServer::VirtioMem::enabled({}), 'ordinary VM stays native');
my $native = { value => 8192 * $mib, timeout => 10 };
my ($cmd, $args) = PVE::QemuServer::VirtioMem::translate_balloon({}, 'balloon', $native);
is($cmd, 'balloon', 'native command unchanged');
is($args, $native, 'native arguments not copied or changed');
($cmd, $args) = PVE::QemuServer::VirtioMem::translate_balloon($conf, 'balloon', $native);
is($cmd, 'qom-set', 'native scheduler target translated');
is_deeply($args, { path => 'machine/peripheral/vmem0', property => 'requested-size',
                   value => 4096 * $mib, timeout => 10 }, 'subtract base; preserve transport options');
is($native->{value}, 8192 * $mib, 'does not mutate caller');
for my $target (4096, 16384) {
    (undef, $args) = PVE::QemuServer::VirtioMem::translate_balloon($conf, 'balloon', {value=>$target*$mib});
    is($args->{value}, ($target-4096)*$mib, "boundary $target");
}
(undef, $args) = PVE::QemuServer::VirtioMem::translate_balloon($conf, 'balloon', {value=>8193*$mib});
is($args->{value},4096*$mib,'round to complete blocks');
for my $target (4095,16385) {
    eval { PVE::QemuServer::VirtioMem::translate_balloon($conf,'balloon',{value=>$target*$mib}) };
    like($@,qr/outside/,'reject target outside range');
}
eval { PVE::QemuServer::VirtioMem::translate_balloon({%$conf, balloon=>8192},'balloon',{value=>4096*$mib}) };
like($@,qr/outside/,'honor minimum above base');
my @command;
PVE::QemuServer::VirtioMem::config($conf,9000,1,4,0,0,\@command,{});
is_deeply([@command[0,1]],['-m','4096M,slots=1,maxmem=16384M'],'fixed boot RAM and maximum');
like(join(' ',@command),qr/memory-backend-ram,id=vmem0,size=12288M,reserve=off,prealloc=off/,'sparse removable pool');
like(join(' ',@command),qr/requested-size=0M/,'boot at configured minimum');
@command=();
PVE::QemuServer::VirtioMem::config({%$conf,balloon=>8192},9000,1,4,0,0,\@command,{});
like(join(' ',@command),qr/requested-size=4096M/,'minimum above base starts partially plugged');
for my $invalid ({'virtio-mem'=>16384},{balloon=>0},{balloon=>4097},{numa=>0},
                 {machine=>'pc'},{numa0=>'cpus=0-3'},{hugepages=>2},{ostype=>'win11'}) {
    eval { my @c; PVE::QemuServer::VirtioMem::config({%$conf,%$invalid},9000,1,4,0,0,\@c,{}) };
    ok($@,'reject unsupported layout');
}
for my $extra ([2,0,0],[1,1,0],[1,0,1]) {
    eval { my @c; PVE::QemuServer::VirtioMem::config($conf,9000,$extra->[0],4,$extra->[1],$extra->[2],\@c,{}) };
    ok($@,'reject unsupported socket/DIMM/virtio-fs combination');
}
{
    package TestQueue;
    sub queue_cmd { my ($self,@entry)=@_; push @$self,\@entry; }
}
my $client = bless [], 'TestQueue';
my $cache = {};
PVE::QemuServer::VirtioMem::queue_stats($client,{id=>9000},{},$cache);
is(scalar(@$client),0,'ordinary VM has no extra QMP roundtrip');
PVE::QemuServer::VirtioMem::queue_stats($client,{id=>9000},$conf,$cache);
is(scalar(@$client),1,'one async command');
is($client->[0][2],'query-memory-devices','query actual plugged memory');
ok(!PVE::QemuServer::VirtioMem::normalize_stats({},$cache->{9000}),'missing device does not fabricate allocation');
$client->[0][1]->(9000,{return=>[
    {type=>'dimm',data=>{id=>'other',size=>999}},
    {type=>'virtio-mem',data=>{id=>'vmem0',size=>2048*$mib,'requested-size'=>0}},
]});
my $info = {actual=>4096*$mib,max_mem=>4096*$mib,total_mem=>6000,free_mem=>2000};
ok(PVE::QemuServer::VirtioMem::normalize_stats($info,$cache->{9000}),'normalize successful query');
is_deeply($info,{actual=>6144*$mib,max_mem=>16384*$mib,total_mem=>6000,free_mem=>2000},
          'use actual size, never requested size; preserve guest counters');
done_testing;

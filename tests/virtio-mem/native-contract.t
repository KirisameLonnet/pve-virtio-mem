use strict;
use warnings;
use Test::More;
use FindBin;
require "$FindBin::Bin/../../tools/VirtioMem.pm";
require "$FindBin::Bin/fixtures/AutoBalloon.pm";
sub PVE::QemuServer::Memory::get_current_memory { return $_[0]; }

my $mib = 1024 * 1024;
my $maximum = 16384 * $mib;
my $base = 4096 * $mib;
my $conf = { memory => 16384, 'virtio-mem' => 12288, balloon => 4096 };
{
    package NativeContractQueue;
    sub queue_cmd { my ($self, $peer, $callback) = @_; $self->{callback} = $callback; }
}
for my $case (
    ['grow from floor', 4096, 512, 8192, 1000],
    ['shrink under host pressure', 12288, 6144, -8192, 1000],
    ['guest pressure', 8192, 128, 8192, 1000],
    ['manual mode', 8192, 512, 8192, 0],
    ['maximum', 16384, 4096, 8192, 1000],
    ['minimum', 4096, 1024, -8192, 1000],
) {
    my ($name, $actual, $free, $goal, $shares) = @$case;
    my $native_info = {
        actual => $actual * $mib, max_mem => $maximum,
        total_mem => $actual * $mib, free_mem => $free * $mib,
    };
    my $info = { %$native_info, actual => $base, max_mem => $base };
    my $queue = bless {}, 'NativeContractQueue';
    my $cache = {};
    PVE::QemuServer::VirtioMem::queue_stats($queue, {id=>9000}, $conf, $cache);
    $queue->{callback}->(9000, {return=>[
        {type=>'virtio-mem', data=>{id=>'vmem0', size=>$actual*$mib-$base,
                                  'requested-size'=>$maximum-$base}},
    ]});
    PVE::QemuServer::VirtioMem::normalize_stats($info, $cache->{9000});
    is_deeply($info, $native_info, "$name: native-equivalent actual/usage counters");
    my $make_status = sub {
        my ($stats) = @_;
        return {
            9000 => { balloon=>$stats->{actual}, maxmem=>$stats->{max_mem},
                      balloon_min=>$base, freemem=>$stats->{free_mem}, shares=>$shares },
            9001 => { balloon=>8192*$mib, maxmem=>$maximum,
                      balloon_min=>$base, freemem=>4096*$mib, shares=>2000 },
        };
    };
    my $native = PVE::AutoBalloon::compute_alg1($make_status->($native_info), $goal*$mib, 100*$mib);
    my $adapted = PVE::AutoBalloon::compute_alg1($make_status->($info), $goal*$mib, 100*$mib);
    is_deeply($adapted, $native, "$name: unmodified native scheduler makes identical decisions");
    if (defined(my $target = $native->{9000})) {
        my ($cmd, $params) = PVE::QemuServer::VirtioMem::translate_balloon(
            $conf, 'balloon', {value=>$target});
        is($cmd, 'qom-set', "$name: only device operation changes");
        my $effective = $params->{value} + $base;
        cmp_ok($effective, '<=', $target, "$name: translated target does not exceed native target");
        cmp_ok($target-$effective, '<', 2*$mib, "$name: difference is less than one device block");
    }
}
done_testing;

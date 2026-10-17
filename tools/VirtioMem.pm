package PVE::QemuServer::VirtioMem;

use strict;
use warnings;

# Derived from rcarmo/pve-microvm's MicroVM.pm memory construction.
# Keep the upstream option semantics: memory = maximum, virtio-mem = removable
# pool. PVE owns scheduling, QMP transport, statistics polling and VM lifecycle.
my $MIB = 1024 * 1024;
my $BLOCK_MIB = 2;

sub enabled {
    my ($conf) = @_;
    return defined($conf->{'virtio-mem'}) && $conf->{'virtio-mem'} > 0;
}

sub layout {
    my ($conf) = @_;
    my $maximum = PVE::QemuServer::Memory::get_current_memory($conf->{memory});
    my $pool = $conf->{'virtio-mem'};
    die "virtio-mem pool must be positive and smaller than maximum memory\n"
        if !defined($pool) || $pool <= 0 || $pool >= $maximum;
    my $base = $maximum - $pool;
    my $minimum = $conf->{balloon} // $maximum;
    die "virtio-mem requires at least 1024 MiB of boot memory\n" if $base < 1024;
    die "virtio-mem requires balloon statistics and base <= minimum <= maximum\n"
        if $minimum < $base || $minimum > $maximum;
    die "virtio-mem memory values must be aligned to $BLOCK_MIB MiB\n"
        if $base % $BLOCK_MIB || $pool % $BLOCK_MIB || $minimum % $BLOCK_MIB;
    return ($base, $pool, $maximum, $minimum);
}

sub config {
    my ($conf, $vmid, $sockets, $cores, $hotplug, $virtiofs, $cmd, $machine_flags) = @_;
    my ($base, $pool, $maximum, $minimum) = layout($conf);
    die "virtio-mem currently requires a Linux q35 VM with NUMA and one socket\n"
        if ($conf->{ostype} // '') ne 'l26' || !$conf->{numa} || $sockets != 1
        || ($conf->{machine} // '') !~ /^(?:pc-)?q35(?:[-,+]|$)/;
    die "virtio-mem cannot combine with DIMM hotplug, hugepages, virtio-fs or confidential VMs\n"
        if $hotplug || $conf->{hugepages} || $virtiofs || $conf->{'amd-sev'} || $conf->{'intel-tdx'};
    for my $key (keys %$conf) {
        die "virtio-mem custom NUMA topology is not supported\n" if $key =~ /^numa\d+$/;
    }
    my $lastcpu = $cores - 1;
    push @$cmd, '-m', "${base}M,slots=1,maxmem=${maximum}M";
    push @$cmd, '-object', "memory-backend-ram,id=ram-node0,size=${base}M";
    push @$cmd, '-numa', "node,nodeid=0,cpus=0-$lastcpu,memdev=ram-node0";
    push @$cmd, '-object', "memory-backend-ram,id=vmem0,size=${pool}M,reserve=off,prealloc=off";
    return;
}

# QEMU allocates automatic PCI addresses in command-line order. Append only
# after PVE devices and custom args, so their explicit addresses are occupied.
sub add_device {
    my ($conf, $cmd) = @_;
    my ($base, $pool, $maximum, $minimum) = layout($conf);
    my $requested = $minimum - $base;
    # Static memslots work with the host's existing vhost limits. The discard
    # manager still coordinates actual VFIO unpinning for unplugged blocks.
    push @$cmd, '-device', "virtio-mem-pci,id=vmem0,memdev=vmem0,node=0,requested-size=${requested}M,block-size=${BLOCK_MIB}M,dynamic-memslots=off";
    return;
}

# Called by the existing Monitor::mon_cmd entry point. No additional controller
# or polling service: pvestatd's original target and shares algorithm is reused.
sub translate_balloon {
    my ($conf, $execute, $params) = @_;
    return ($execute, $params) if $execute ne 'balloon' || !enabled($conf);
    my ($base, $pool, $maximum, $minimum) = layout($conf);
    my $target = $params->{value};
    # PVE owns the policy floor. In manual mode its pending-config handler can
    # send a newly lowered target before the old balloon value is committed.
    # Enforce physical capacity here, not the previous configuration's target.
    die "virtio-mem target is outside configured capacity\n"
        if !defined($target) || $target < $base * $MIB || $target > $maximum * $MIB;
    my $block = $BLOCK_MIB * $MIB;
    my $requested = int(($target - $base * $MIB) / $block) * $block;
    my %args = %$params;
    $args{path} = 'machine/peripheral/vmem0';
    $args{property} = 'requested-size';
    $args{value} = $requested;
    return ('qom-set', \%args);
}

# Add to the caller's existing asynchronous QMP queue: a second synchronous
# connection inside a callback would deadlock QEMU's single monitor socket.
sub queue_stats {
    my ($client, $peer, $conf, $cache) = @_;
    return if !enabled($conf);
    my ($base, $pool, $maximum) = layout($conf);
    $cache->{$peer->{id}} = {}; # Never substitute base-only stats if the device is missing.
    $client->queue_cmd($peer, sub {
        my ($vmid, $response) = @_;
        for my $device (@{ $response->{'return'} // [] }) {
            next if $device->{type} ne 'virtio-mem' || $device->{data}->{id} ne 'vmem0';
            $cache->{$vmid} = {
                actual => $base * $MIB + $device->{data}->{size},
                max_mem => $maximum * $MIB,
                virtio_mem => 1,
            };
        }
    }, 'query-memory-devices');
}

sub normalize_stats {
    my ($info, $memory) = @_;
    return 1 if !defined($memory);
    return 0 if !defined($memory->{actual});
    # query-balloon excludes virtio-mem's memory. Its guest total/free counters
    # remain useful; replace only allocation fields with the device's real size.
    $info->{actual} = $memory->{actual};
    $info->{max_mem} = $memory->{max_mem};
    $info->{virtio_mem} = 1 if $memory->{virtio_mem};
    return 1;
}

1;

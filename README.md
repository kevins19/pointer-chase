# pointer-chase

Pointer-chase set up for measuring cache/dram access latency. Original source from https://github.com/bsc-mem/Mess-benchmark.

## Requirements:
`perf` and `numactl` should be installed. The following configurations should also be added.

```bash
# perf event paranoid, huge pages
echo -1 > /proc/sys/kernel/perf_event_paranoid
sysctl -w vm.nr_hugepages=1024
```

Disabling HW Prefetchers:
_Be sure to confirm registers and values before setting them._
AMD:
```bash
sudo modprobe msr
# disable prefetching into L2 cache
sudo wrmsr -a 0xc0011022 0xc000000401510000
sudo wrmsr -a 0xc001102b 0x2000cc14
```

Intel:
```bash
sudo modprobe msr
sudo wrmsr -a 0x1a0 0x60628e2289    # Disable hw prefetching
sudo wrmsr -a 0x1A4 0xf             # Disable L1, L2 cache prefetching
```

Power:
```bash
dscrctl -n -s 1         # aix
ppc64_cpu --dscr=1      # linux
```
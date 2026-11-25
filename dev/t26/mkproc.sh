mkdir -p proc/net proc/sys
# fake /proc: cpu, meminfo, uptime, route, net/dev
printf 'cpu  1000 0 500 8000 500 0 0 0 0 0\n' > proc/stat
printf 'MemTotal: 4000000 kB\nMemAvailable: 1000000 kB\n' > proc/meminfo
printf '5000.5 9000.1\n' > proc/uptime
printf 'Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\n' > proc/net/route
printf 'ens5\t00000000\t0102A8C0\t0003\t0\t0\t100\t00000000\n' >> proc/net/route
printf 'ens5\t0000A8C0\t00000000\t0001\t0\t0\t100\t00FFFFFF\n' >> proc/net/route
nic(){ printf 'Inter-|   Receive\n face |bytes packets errs drop fifo frame compressed multicast|bytes packets\n    lo: 5 1 0 0 0 0 0 0 5 1 0 0 0 0 0 0\n  ens5: %s 10 0 0 0 0 0 0 %s 10 0 0 0 0 0 0\n' $1 $2 > proc/net/dev; }

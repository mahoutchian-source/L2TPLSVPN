# netns lab: srv (the gateway) with two dial-in clients (ppp0, ppp1), one outgoing site (ppp-s1) and "internet" (eth0)
for n in srv cA cB site1 site2 inet; do ip netns del $n 2>/dev/null; ip netns add $n; ip netns exec $n ip link set lo up; done
mk() { # srvdev ns peerdev   (made with temporary unique names in the host, moved, then renamed inside the namespaces)
  ip link add lt$$a type veth peer name lt$$b
  ip link set lt$$a netns srv; ip link set lt$$b netns $2
  ip netns exec srv ip link set lt$$a name $1; ip netns exec $2 ip link set lt$$b name $3
  ip netns exec srv ip link set $1 up; ip netns exec $2 ip link set $3 up
}
mk ppp0 cA a0; mk ppp1 cB b0; mk ppp-s1 site1 s0; mk ppp-s2 site2 t0; mk eth0 inet i0
S="ip netns exec srv"
$S ip addr add 10.99.99.1 peer 10.99.99.2/32 dev ppp0
$S ip addr add 10.99.99.1 peer 10.99.99.3/32 dev ppp1
$S ip addr add 172.17.1.1 peer 172.17.1.3/32 dev ppp-s1
$S ip addr add 172.17.2.1 peer 172.17.2.3/32 dev ppp-s2
$S ip addr add 203.0.113.1/24 dev eth0
ip netns exec cA ip addr add 10.99.99.2 peer 10.99.99.1/32 dev a0; ip netns exec cA ip route add default via 10.99.99.1 dev a0
ip netns exec cB ip addr add 10.99.99.3 peer 10.99.99.1/32 dev b0; ip netns exec cB ip route add default via 10.99.99.1 dev b0
ip netns exec site1 ip addr add 172.17.1.3 peer 172.17.1.1/32 dev s0; ip netns exec site1 ip route add default via 172.17.1.1 dev s0
ip netns exec site2 ip addr add 172.17.2.3 peer 172.17.2.1/32 dev t0; ip netns exec site2 ip route add default via 172.17.2.1 dev t0
ip netns exec inet ip addr add 203.0.113.2/24 dev i0; ip netns exec inet ip addr add 8.8.8.8/32 dev lo
ip netns exec inet ip route add 10.99.99.0/24 via 203.0.113.1; ip netns exec inet ip route add 172.17.1.0/24 via 203.0.113.1; ip netns exec inet ip route add 172.17.2.0/24 via 203.0.113.1
$S ip route add 8.8.8.8 via 203.0.113.2
for n in srv cA cB site1 site2 inet; do ip netns exec $n sysctl -qw net.ipv4.conf.all.rp_filter=0 net.ipv4.conf.default.rp_filter=0; done
$S sysctl -qw net.ipv4.ip_forward=1

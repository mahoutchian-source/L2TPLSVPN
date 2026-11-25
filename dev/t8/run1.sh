export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units
G=$PWD/../build/l2tp-gw
ip link set lo up
mk(){ ip tuntap add dev ppp-$1 mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-$1; ip link set dev ppp-$1 up; }
mk a; mk b
bash $G apply 2>&1 | grep -v WARNING
bash $G routes-sync ppp-a up; bash $G routes-sync ppp-b up
echo "=== check (all good except b has zero ESP counters)"; bash $G check; echo "rc=$?"
echo "=== route_block spot test"; ip route show

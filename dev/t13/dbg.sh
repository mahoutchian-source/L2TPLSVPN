export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c STATE_DIR=$PWD/st NO_RESTART=1 IPSEC_GRACE=0
ip link set lo up
ip tuntap add dev ppp-only mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-only; ip link set dev ppp-only up
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
bash -x ../build/l2tp-gw watch 2>&1 | tail -25
ls st

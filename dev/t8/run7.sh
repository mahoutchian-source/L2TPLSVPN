export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw
ip link set lo up
ip tuntap add dev ppp-a mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-a; ip link set dev ppp-a up
bash $L2TP_GW apply >/dev/null 2>&1; bash $L2TP_GW routes-sync ppp-a up
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1
python3 shot2.py 2>&1 | tail -3
kill $W

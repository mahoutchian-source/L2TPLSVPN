export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw
ip link set lo up
ip tuntap add dev ppp-only mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-only; ip link set dev ppp-only up
printf '[only]\nhost = 9.9.9.9\npsk = k\nuser = u\npass = p\nipsec_mode = allow\nroutes = 172.17.192.0/22 metric 2\n' > c/sites.conf
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1
python3 shot.py; kill $W

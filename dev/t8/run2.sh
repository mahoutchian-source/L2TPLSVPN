export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units
G=$PWD/../build/l2tp-gw
ip link set lo up
mk(){ ip tuntap add dev ppp-$1 mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-$1; ip link set dev ppp-$1 up; }
mk a
bash $G routes-sync ppp-a up
sed -i '/b\[2\]/d' ipsec.status
echo "=== FAIL cases: b has no ppp, no ipsec; NAT rule for a removed"
sed -i '/ppp-a/d' ipt/rules
bash $G check | grep -v '^OK'; echo "rc=${PIPESTATUS[0]}"
echo; echo "=== backup / restore"
bash $G backup $PWD/bk.conf; ls -l bk.conf | cut -c1-10
printf '[bad]\nhost = x y\npsk=1\nuser=u\npass=p\n' > bad.conf
bash $G restore bad.conf; echo "rc=$?"; grep -c '^\[' c/sites.conf
printf '[only]\nhost = 9.9.9.9\npsk = k\nuser = u\npass = p\n' > good.conf
bash $G restore good.conf 2>&1 | grep -v WARNING; grep '^\[' c/sites.conf; ls ipd; ls c/routes.d
bash $G restore bk.conf 2>&1 | grep -v WARNING; grep '^\[' c/sites.conf
echo; echo "=== reconnect"
: > calls
bash $G reconnect a; cat calls
bash $G reconnect nope; echo "rc=$?"
echo; echo "=== logs"
bash $G logs | wc -l; echo "-- site a:"; bash $G logs a; echo "-- site b:"; bash $G logs b

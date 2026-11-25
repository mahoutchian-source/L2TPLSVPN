export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units
G=$PWD/../build/l2tp-gw
ip link set lo up
bash $G watch; echo "baseline stored: $(cat st/ddns-b)"; : > st/watch.log
echo 7.7.7.7 > dns.b.example.com; bash $G watch; cat st/watch.log | cut -c21-
echo 5.5.5.5 > dns.b.example.com
bash $G timer; echo "timer rc=$?"; ls units

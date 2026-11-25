export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c STATE_DIR=$PWD/st NO_RESTART=1 L2TP_GW=$PWD/../build/l2tp-gw
ip link set lo up
ip tuntap add dev ppp-only mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-only; ip link set dev ppp-only up
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1
B=http://127.0.0.1:18084; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > m.html
t(){ grep -o "state [a-z]*'>[^<]*" m.html | head -1; }
echo "no IPsec:        $(t)"
echo "           only[1]: ESTABLISHED 5 minutes ago" > ipsec.status
$C -s -b $J $B/ > m.html; echo "IPsec ok:        $(t)"
touch ipsec.fail; echo "Security Associations (0 up" > ipsec.status
$C -s -b $J $B/ > m.html; echo "ipsec cmd fails: $(t)"
rm ipsec.fail
ip link set dev ppp-only down; $C -s -b $J $B/ > m.html; echo "ppp down:        $(t)"
kill $W

export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw SYS_NET=/sys/class/net
GW=$L2TP_GW
rm -rf c ipd ppp x st units ipt calls sec ipsec.conf run tr
mkdir -p c ipd ppp/ip-up.d x st units run
printf '#!/bin/sh\n' > ppp/ip-up; printf '#!/bin/sh\n' > ppp/ip-down
echo "include $IPSEC_D/*.conf" > ipsec.conf
cp ../t8/c/web.conf c/
ip link del ppp0 2>/dev/null; ip link set lo up
ip tuntap add dev ens5 mode tun; ip addr add 172.26.2.106/20 dev ens5; ip link set ens5 up
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
printf '[cl]\nhost = 9.9.9.9\npsk = clientpsk\nuser = cu\npass = cp\n' > c/sites.conf
bash $GW apply >/dev/null 2>&1
printf '[cl]\nhost = 9.9.9.9\npsk = clientpsk\nuser = cu\npass = cp\n' > c/sites.conf
bash $GW apply >/dev/null 2>&1
mkdir -p st; printf '%s\n' '{"t":1793700000,"k":"down","m":"Tunnel cl disconnected <b>x</b>"}' '{"t":1793700100,"k":"up","m":"Tunnel cl connected"}' 'garbage' > st/events.log
python3 -I ../build/l2tp-gw-web run >/dev/null 2>&1 & W=$!; sleep 1.5
B=http://127.0.0.1:18082; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
get(){ $C -s -b $J -c $J "$@"; }
get $B/events > ev.html; grep -o ">Events<" ev.html | head -1; grep -o "evk up'>up\|evk down'>down" ev.html; grep -c "&lt;b&gt;x" ev.html; grep -c "<b>x</b>" ev.html
get $B/ > d.html; grep -o "Recent events\|All events" d.html | head -2
get "$B/live?page=dash" | grep -o "Recent events" | head -1
$C -s -b $J -c $J -d "csrf=$CS" -d name=cl $B/toggle -o /dev/null; tail -1 st/events.log
kill $W

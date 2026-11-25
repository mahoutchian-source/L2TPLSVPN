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
printf '[cl]\nhost = 9.9.9.9\npsk = clientpsk\nuser = cu\npass = cp\nroutes = 10.5.0.0/16\n\n[cm]\nhost = 8.8.4.4\npsk = p2psk\nuser = cu2\npass = cp2\n' > c/sites.conf
bash $GW apply >/dev/null 2>&1; ls c/site-acc.d; cat c/site-acc.d/cl
: > calls; rm -f ipt/rules
L2TP_GW=$PWD/gwlog.sh python3 -I ../build/l2tp-gw-web run >/dev/null 2>&1 & W=$!; sleep 1.5
B=http://127.0.0.1:18082; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
post(){ $C -s -b $J -c $J -d "csrf=$CS" "$@"; }
get(){ $C -s -b $J -c $J "$@"; }
get "$B/edit?name=cl" > e1.html; echo "edit form boxes ticked: $(grep -o 'name=acc_[a-z]* value=yes checked' e1.html | wc -l)"
echo "--- only access changed (internet un-ticked): must use site-sync"
post -d name=cl -d host=9.9.9.9 -d user=cu -d routes=10.5.0.0/16 -d acc_sites=yes -d acc_clients=yes -d ipsec_mode=heal -d orig=cl $B/save -o /dev/null -w 'save %{http_code}\n'
grep -A12 '^\[cl\]' c/sites.conf | grep access; cat c/site-acc.d/cl
get "$B/sites" | grep -o "no internet\|no other sites\|no dial-in clients"
echo "--- a real change (host) must use a full apply"
post -d name=cl -d host=9.9.9.8 -d user=cu -d routes=10.5.0.0/16 -d acc_internet=yes -d acc_sites=yes -d acc_clients=yes -d ipsec_mode=heal -d orig=cl $B/save -o /dev/null -w 'save %{http_code}\n'
cat c/site-acc.d/cl
cat gw.log | grep -E "^(validate|apply|site-sync)" | cut -c1-30; kill $W

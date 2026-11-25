export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw PROC_DIR=$PWD/../t22/proc
GW=$L2TP_GW
rm -rf c ipd ppp x st units ipt calls sec ipsec.conf; mkdir -p c ipd ppp/ip-up.d x st units
printf '#!/bin/sh\n' > ppp/ip-up; printf '#!/bin/sh\n' > ppp/ip-down; echo "include $IPSEC_D/*.conf" > ipsec.conf
cp ../t8/c/web.conf c/; ip link set lo up; for i in ppp-a ppp-b ppp-c ppp-only ppp0 ppp1; do ip link del $i 2>/dev/null; done
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
printf '[a]\nhost = 9.9.9.9\npsk = k1\nuser = ua\npass = pa\nroutes = 172.30.0.0/16 metric 2\nnat = yes\n[b]\nhost = 8.8.8.8\npsk = k2\nuser = ub\npass = pb\n' > c/sites.conf
bash $GW apply >/dev/null 2>&1
ip tuntap add dev ppp-a mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-a; ip link set dev ppp-a up
bash $GW routes-sync ppp-a up
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1.5
B=http://127.0.0.1:18082; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
post(){ $C -s -b $J -c $J -d "csrf=$CS" "$@"; }; get(){ $C -s -b $J -c $J "$@"; }
get $B/sites > s1.html; ok "Switch off button present" "grep -q 'Switch off' s1.html"
ok "a connected" "grep -q 'state noipsec.>Connected\|state up.>Connected' s1.html"
: > calls
post -d name=a $B/toggle -o /dev/null -w '%{http_code}\n'
ok "sites.conf has disabled for a only" "grep -A8 '^\[a\]' c/sites.conf | grep -q 'disabled = yes' && ! grep -A8 '^\[b\]' c/sites.conf | grep -q disabled"
ok "a.conf removed, b.conf stays" "[ ! -f ipd/a.conf ] && [ -f ipd/b.conf ]"
ok "no restart of services" "! grep -q 'systemctl restart' calls 2>/dev/null"
ok "ipsec down a was called" "grep -q 'ipsec down a' calls 2>/dev/null || grep -q 'down a' calls"
ok "a route file removed" "[ ! -f c/routes.d/a ]"
ok "a not in nat/xl2tpd" "! grep -q 'lac a' x/x.conf && grep -q 'lac b' x/x.conf"
get $B/sites > s2.html; ok "row shows Switched off + Switch on" "grep -q 'Switched off' s2.html && grep -q 'Switch on' s2.html"
ok "summary counts only active" "tr -d '\n' < s2.html | sed 's/<[^>]*>/ /g' | grep -q '0 of 1 tunnels connected'"
post -d name=a $B/reconnect -o /dev/null; get $B/sites | grep -o "a is switched off[^<]*" | head -1
echo "--- edit keeps it off"
post -d orig=a -d name=a -d host=9.9.9.9 -d user=ua -d routes='172.30.0.0/16 metric 2' -d nat=yes -d ipsec_mode=heal $B/save -o /dev/null
ok "still disabled after edit" "grep -A9 '^\[a\]' c/sites.conf | grep -q 'disabled = yes'"
get $B/ | tr -d '\n' | sed 's/<[^>]*>/ /g' | grep -o 'Switched off *[0-9a-z ]*site' | head -1
echo "--- switch on"
post -d name=a $B/toggle -o /dev/null
ok "disabled removed" "! grep -q disabled c/sites.conf && [ -f ipd/a.conf ]"
ok "a back in xl2tpd" "grep -q 'lac a' x/x.conf"
echo "--- bash: list/check"
bash $GW list | head -3
echo "--- csrf missing / unknown"
$C -s -b $J -o /dev/null -w "toggle no csrf %{http_code}\n" -d name=a $B/toggle
post -d name=zzz $B/toggle -o /dev/null; get $B/sites | grep -o "Unknown site" | head -1
kill $W; ip link del ppp-a

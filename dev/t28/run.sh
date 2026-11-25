export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw SYS_NET=/sys/class/net IPSEC_RECHECK_WAIT=0
GW=$L2TP_GW
rm -rf c ipd ppp x st units ipt calls sec ipsec.conf run tr ipsec.seq ipsec.calls
mkdir -p c ipd ppp/ip-up.d x st units run
printf '#!/bin/sh\n' > ppp/ip-up; printf '#!/bin/sh\n' > ppp/ip-down
echo "include $IPSEC_D/*.conf" > ipsec.conf
cp ../t8/c/web.conf c/
for i in ppp-cl ppp-b; do ip link del $i 2>/dev/null; done
ip link set lo up
ip link show ens5 >/dev/null 2>&1 || { ip tuntap add dev ens5 mode tun; ip addr add 172.26.2.106/20 dev ens5; ip link set ens5 up; }
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
echo "--- 1.0.1: PPP keep-alive, require firewall"
printf '[cl]\nhost = 9.9.9.9\npsk = p1\nuser = cu\npass = cp\n\n[rq]\nhost = 8.8.8.8\npsk = p2\nuser = ru\npass = rp\nipsec_mode = require\nlcp_echo = off\n' > c/sites.conf
bash $GW apply >/dev/null 2>&1
ok "default: lcp-echo 30 / 6 in the PPP options" "grep -q '^lcp-echo-interval 30' ppp/options.l2tpd.cl && grep -q '^lcp-echo-failure 6' ppp/options.l2tpd.cl"
ok "lcp_echo = off: no lcp-echo lines" "! grep -q lcp-echo ppp/options.l2tpd.rq"
ok "require site: plain UDP 1701 from its address is dropped, IPsec accepted" "grep -q '^A L2TPGW-REQ -s 8.8.8.8 -p udp --dport 1701 -m policy --dir in --pol ipsec -j ACCEPT' ipt/rules && grep -q '^A L2TPGW-REQ -s 8.8.8.8 -p udp --dport 1701 -j DROP' ipt/rules"
ok "heal site is not in the REQ chain" "! grep -q 'L2TPGW-REQ.*9.9.9.9' ipt/rules"
ok "REQ chain is hooked into INPUT" "grep -q '^I INPUT 1 -j L2TPGW-REQ' ipt/rules"
sed -i 's/^ipsec_mode = require/ipsec_mode = allow/' c/sites.conf; bash $GW apply >/dev/null 2>&1
ok "no require site left: REQ chain emptied" "! grep -q '^A L2TPGW-REQ ' ipt/rules"
printf '[rq]\nhost = 8.8.8.8\npsk = p2\nuser = ru\npass = rp\nlcp_echo = maybe\n' > c/sites.conf
ok "bad lcp_echo value is refused" "! bash $GW apply 2>&1 | grep -q 'ok' && bash $GW apply 2>&1 | grep -q 'lcp_echo must be on or off'"
echo "--- IPsec re-check before alert / repair"
printf '[cl]\nhost = 9.9.9.9\npsk = p1\nuser = cu\npass = cp\n' > c/sites.conf
bash $GW apply >/dev/null 2>&1
printf 'telegram_token = 123456:ABC-def\ntelegram_chat = 42\ndns_flush_min = 0\n' > c/notify.conf
ip tuntap add dev ppp-cl mode tun; ip addr add 10.1.1.2 peer 10.1.1.1/32 dev ppp-cl; ip link set ppp-cl up
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
printf 'cl[1]: ESTABLISHED 3 minutes ago\n' > ipsec.status2
touch ipsec.seq; rm -f ipsec.calls calls; mkdir -p st; echo $(( $(date +%s) - 300 )) > st/noipsec-cl
bash $GW watch
ok "first reading has no SA but the fresh one has: no alert, no repair, state cleared" "[ ! -f st/noipsec-alerted-cl ] && [ ! -f st/noipsec-tries-cl ] && [ ! -f st/noipsec-cl ] && ! grep -q 'repair attempt' st/watch.log 2>/dev/null"
rm -f ipsec.seq ipsec.calls; echo $(( $(date +%s) - 300 )) > st/noipsec-cl
bash $GW watch
ok "SA really missing: alert and repair attempt as before" "[ -f st/noipsec-alerted-cl ] && grep -q 'repair attempt 1' st/watch.log"
echo "--- status shows multipath routes"
ip tuntap add dev ppp-b mode tun; ip addr add 10.2.2.2 peer 10.2.2.1/32 dev ppp-b; ip link set ppp-b up
ip route replace 10.55.0.0/24 nexthop dev ppp-cl weight 1 nexthop dev ppp-b weight 1
bash $GW status > status.out 2>&1
ok "routes via ppp-b lists the multipath route" "awk '/routes via ppp-b:/{f=1;next} /routes via /{f=0} f' status.out | grep -q '10.55.0.0/24'"
ok "routes via ppp-cl lists it too, with both nexthops" "awk '/routes via ppp-cl:/{f=1;next} /routes via /{f=0} f' status.out | grep -q '10.55.0.0/24' && awk '/routes via ppp-cl:/{f=1;next} /routes via /{f=0} f' status.out | grep -c nexthop | grep -q 2"
ip route del 10.55.0.0/24 2>/dev/null; ip link del ppp-b; ip link del ppp-cl
echo "--- duplicate network in two dial-in clients"
mkdir -p c/routes.d
printf '[a]\nmode = server\nuser = ua\npass = passwordaa1\nip = 10.99.99.2\nroutes = 172.17.248.0/24\n\n[b]\nmode = server\nuser = ub\npass = passwordbb2\nip = 10.99.99.3\nroutes = 172.17.248.0/24\n\n[c]\nmode = server\nuser = uc\npass = passwordcc3\nip = 10.99.99.4\nroutes = 172.17.252.0/24\n' > c/sites.conf
printf '172.17.248.0/24 100\n' > c/routes.d/a; printf '172.17.248.0/24 100\n' > c/routes.d/b; printf '172.17.252.0/24 100\n' > c/routes.d/c
bash $GW check > chk.out 2>&1
ok "warns: 172.17.248.0/24 metric 100 used by a and b" "grep -E '^WARN.*172.17.248.0/24 metric 100 \(a and b\)' chk.out"
ok "no warning for the unique network" "! grep -q 'WARN.*172.17.252.0' chk.out"
printf '172.17.248.0/24 5\n' > c/routes.d/b; bash $GW check > chk.out 2>&1
ok "same network, different distance: no warning" "! grep -q 'SAME network' chk.out"
echo "--- web: Persian password, real encryption text"
printf '[cl]\nhost = 9.9.9.9\npsk = p1\nuser = cu\npass = cp\n' > c/sites.conf
PW='رمز-فارسی-12345'
sed -i "s/^password = .*/password = $PW/" c/web.conf
python3 -I ../build/l2tp-gw-web run >/dev/null 2>&1 & W=$!; sleep 1.5
B=http://127.0.0.1:18082; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L --data-urlencode "password=$PW" $B/login > main.html
ok "login with a Persian password works (no server error)" "grep -q 'Dashboard' main.html"
$C -s -L --data-urlencode "password=ÿwrong" $B/login | grep -q 'Wrong password' && echo "PASS wrong non-ASCII password is refused, not a 500" || echo "FAIL wrong non-ASCII password is refused, not a 500"
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
post(){ $C -s -b $J -c $J -d "csrf=$CS" "$@"; }
get(){ $C -s -b $J -c $J "$@"; }
post --data-urlencode "current=$PW" -d new1=newpass123 -d new2=newpass123 $B/settings/password -o /dev/null; get $B/settings | grep -q 'Password changed' && echo "PASS password change with a Persian current password" || echo "FAIL password change with a Persian current password"
get $B/sites > sites.html
ok "sites page shows IPsec/PPP state and encryption" "grep -q 'IPsec .* PPP' sites.html"
ok "MPPE label says it is not IPsec" "get '$B/edit' | grep -q 'PPP-level encryption (MPPE), not IPsec'"
ok "edit form has the PPP keep-alive select" "get '$B/edit' | grep -q 'name=lcp_echo'"
kill $W
echo DONE

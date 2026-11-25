export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw SYS_NET=/sys/class/net IPSEC_RECHECK_WAIT=0
GW=$L2TP_GW
rm -rf c ipd ppp x st units ipt calls sec ipsec.conf run tr ping.log pinglimit
mkdir -p c ipd ppp/ip-up.d x st units run
printf '#!/bin/sh\n' > ppp/ip-up; printf '#!/bin/sh\n' > ppp/ip-down
echo "include $IPSEC_D/*.conf" > ipsec.conf
cp ../t8/c/web.conf c/
for i in ppp-cl ppp3; do ip link del $i 2>/dev/null; done
ip link set lo up
ip link show ens5 >/dev/null 2>&1 || { ip tuntap add dev ens5 mode tun; ip addr add 172.26.2.106/20 dev ens5; ip link set ens5 up; }
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
echo "--- 1.0.3: MTU setting per connection"
printf '[cl]\nhost = 9.9.9.9\npsk = p1\nuser = cu\npass = cp\nmtu = 1400\n\n[cl2]\nhost = 8.8.8.8\npsk = p2\nuser = c2\npass = c2p\n' > c/sites.conf
bash $GW apply >/dev/null 2>&1
ok "outgoing site with mtu = 1400: pppd gets mtu and mru 1400" "grep -q '^mtu 1400' ppp/options.l2tpd.cl && grep -q '^mru 1400' ppp/options.l2tpd.cl"
ok "site without mtu keeps 1280" "grep -q '^mtu 1280' ppp/options.l2tpd.cl2 && grep -q '^mru 1280' ppp/options.l2tpd.cl2"
printf '[cl]\nhost = 9.9.9.9\npsk = p1\nuser = cu\npass = cp\nmtu = 300\n' > c/sites.conf
ok "mtu below 576 is refused" "bash $GW apply 2>&1 | grep -q 'mtu must be a number from 576 to 1500'"
printf '[cl]\nhost = 9.9.9.9\npsk = p1\nuser = cu\npass = cp\nmtu = abc\n' > c/sites.conf
ok "mtu = abc is refused" "bash $GW apply 2>&1 | grep -q 'mtu must be'"
echo "--- dial-in client: live MTU"
printf 'enabled = yes\npublic_ip = 198.51.100.10\npsk = SharedPsk12345\npool = 10.99.99.0/24\n' > c/dialin.conf
printf '[hm]\nmode = server\nuser = hmuser\npass = hmpassword1\nip = 10.99.99.2\nmtu = 1360\n' > c/sites.conf
ip tuntap add dev ppp3 mode tun; ip addr add 10.99.99.1 peer 10.99.99.2/32 dev ppp3; ip link set ppp3 up; ip link set dev ppp3 mtu 1280
bash $GW mtu-apply > mtu.out 2>&1
ok "mtu-apply sets the connected dial-in link to the client's mtu" "grep -q 'hm: ppp3 mtu 1280 -> 1360' mtu.out && ip -o link show dev ppp3 | grep -q 'mtu 1360'"
printf '[hm]\nmode = server\nuser = hmuser\npass = hmpassword1\nip = 10.99.99.2\n' > c/sites.conf
bash $GW mtu-apply > mtu.out 2>&1
ok "mtu removed from the client: link goes back to 1280" "ip -o link show dev ppp3 | grep -q 'mtu 1280'"
bash $GW mtu-apply ppp9 > mtu.out 2>&1; ok "mtu-apply for another interface does nothing" "! grep -q hm mtu.out"
echo "--- MTU measurement"
ip tuntap add dev ppp-cl mode tun; ip addr add 172.17.218.3 peer 172.17.192.3/32 dev ppp-cl; ip link set ppp-cl up; ip link set dev ppp-cl mtu 1280
printf '[cl]\nhost = 9.9.9.9\npsk = p1\nuser = cu\npass = cp\n' > c/sites.conf
echo 1352 > pinglimit
bash $GW mtu-test cl > t1.out 2>&1
ok "measure site: biggest passing payload 1352 -> packet 1380, suggested 1380" "grep -q 'RESULT addr=172.17.192.3 dev=ppp-cl current=1280 max=1380 suggested=1380' t1.out"
ok "the link MTU is back to 1280 afterwards" "ip -o link show dev ppp-cl | grep -q 'mtu 1280'"
ok "probes use -M do (no fragmentation) and the tunnel interface" "grep -q -- '-M do' ping.log && grep -q -- '-I ppp-cl' ping.log"
echo 1472 > pinglimit
bash $GW mtu-test cl > t2.out 2>&1
ok "no limit: reports 1500 and says so" "grep -q 'max=1500 suggested=1500' t2.out && grep -q 'no size limit found' t2.out"
echo 0 > pinglimit; echo 40 > pinglimit
bash $GW mtu-test cl > t3.out 2>&1; rc=$?
ok "no answer even for a tiny packet: clear message, exit code 1, no guess" "[ $rc = 1 ] && grep -q 'No answer from' t3.out && grep -q 'max=0 suggested=0' t3.out"
echo 1300 > pinglimit
bash $GW mtu-test 172.17.192.1 ppp-cl > t4.out 2>&1
ok "measure any address through a chosen interface (1300 -> 1328)" "grep -q 'RESULT addr=172.17.192.1 dev=ppp-cl current=1280 max=1328 suggested=1328' t4.out"
bash $GW mtu-test nosuch > t5.out 2>&1; ok "unknown site name: clear error" "grep -q \"No site named 'nosuch'\" t5.out"
ip link set dev ppp-cl down; bash $GW mtu-test cl > t6.out 2>&1; ok "tunnel not connected: nothing to measure" "grep -q 'not connected' t6.out"
for i in ppp-cl ppp3; do ip link del $i 2>/dev/null; done
echo "--- web: MTU fields and measurement page"
printf '[cl]\nhost = 9.9.9.9\npsk = p1\nuser = cu\npass = cp\nmtu = 1400\n\n[hm]\nmode = server\nuser = hmuser\npass = hmpassword1\nip = 10.99.99.2\n' > c/sites.conf
printf 'enabled = yes\npublic_ip = 198.51.100.10\npsk = SharedPsk12345\npool = 10.99.99.0/24\n' > c/dialin.conf
PW=testpass123; sed -i "s/^password = .*/password = $PW/" c/web.conf
ip tuntap add dev ppp-cl mode tun; ip addr add 172.17.218.3 peer 172.17.192.3/32 dev ppp-cl; ip link set ppp-cl up; ip link set dev ppp-cl mtu 1280
echo 1352 > pinglimit
python3 -I ../build/l2tp-gw-web run >/dev/null 2>&1 & W=$!; sleep 1.5
B=http://127.0.0.1:18082; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L --data-urlencode "password=$PW" $B/login > main.html
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
post(){ $C -s -b $J -c $J -d "csrf=$CS" "$@"; }
get(){ $C -s -b $J -c $J "$@"; }
ok "web and program have the same version" "[ \"\$(python3 -I ../build/l2tp-gw-web version 2>/dev/null || grep -m1 '^VERSION' ../build/l2tp-gw-web | cut -d'\"' -f2)\" != '' ] && [ \"\$(grep -m1 '^VERSION' ../build/l2tp-gw-web | cut -d'\"' -f2)\" = \"\$(grep -m1 '^VERSION' ../build/l2tp-gw | cut -d'\"' -f2)\" ]"
ok "site edit form has the MTU field with the saved value" "get '$B/edit?name=cl' | grep -q \"name=mtu value='1400'\""
ok "dial-in edit form has the MTU field" "get '$B/dialin/edit?name=hm' | grep -q 'name=mtu'"
get $B/sites > sites.html; ok "sites page shows an MTU chip" "grep -q 'MTU 1400' sites.html"
ok "navigation has the Measure MTU page" "grep -q \"href='/mtu'\" sites.html"
get $B/mtu > mtu.html; ok "measure page lists the site and the client" "grep -q \"value='cl'\" mtu.html && grep -q \"value='hm'\" mtu.html"
post -d target=cl $B/mtu/run > r1.html
ok "measuring a site shows the suggestion and a button" "grep -q 'Suggested MTU: <b class=mono>1380' r1.html && grep -q 'Use 1380 for cl' r1.html"
ok "MikroTik command for an outgoing site is shown" "grep -q 'l2tp-server server set max-mtu=1380 max-mru=1380' r1.html"
post -d target=hm $B/mtu/run > r2.html
ok "a dial-in client that is not connected: message, no button" "grep -q 'not connected' r2.html && ! grep -q 'Use .* for hm' r2.html"
post -d address=8.8.8.8 -d iface=ppp-cl $B/mtu/run > r3.html
ok "any address: suggestion without a save button" "grep -q 'Suggested MTU: <b class=mono>1380' r3.html && ! grep -q 'mtu/set' r3.html"
post -d 'address=8.8.8.8;rm' $B/mtu/run | grep -q 'Write an IPv4 address' && echo "PASS bad address is refused" || echo "FAIL bad address is refused"
post -d name=cl -d mtu=1380 $B/mtu/set -o /dev/null
ok "set button writes mtu to the site and the pppd options" "grep -q '^mtu = 1380' c/sites.conf && grep -q '^mtu 1380' ppp/options.l2tpd.cl"
post -d name=cl -d mtu=100 $B/mtu/set -o /dev/null; ok "MTU 100 is refused by the web too" "grep -q '^mtu = 1380' c/sites.conf"
post -d name=cl -d orig=cl -d host=9.9.9.9 -d user=cu -d routes= -d mtu=1330 $B/save -o /dev/null
ok "saving the edit form stores the new mtu" "grep -q '^mtu = 1330' c/sites.conf"
post -d name=hm -d orig=hm -d user=hmuser -d pass=hmpassword1 -d ip=10.99.99.2 -d mtu=1360 -d acc_internet=yes -d acc_clients=yes -d acc_sites=yes $B/dialin/save -o /dev/null
ok "dial-in save stores the client's mtu" "grep -A8 '^\\[hm\\]' c/sites.conf | grep -q '^mtu = 1360'"
get $B/ > dash.html
ok "dashboard has the network map and the health donut" "grep -q 'class=netmap' dash.html && grep -q 'class=donut' dash.html && grep -q 'id=totchart' dash.html"
ok "map: tunnel up without IPsec is drawn red, dial-in client not connected is grey" "grep -q \"class='ln noipsec'\" dash.html && grep -q \"class='ln wait'\" dash.html"
get $B/sites | grep -q "data-spark='cl'" && echo "PASS connected site has a sparkline slot" || echo "FAIL connected site has a sparkline slot"
python3 - <<'PY' > page.js
import re,sys
s=open('../build/l2tp-gw-web').read(); i=s.index('JS = \"\"\"'); j=s.index('\n\"\"\"',i)
print(eval('\"\"\"'+s[i+8:j]+'\n\"\"\"'))
PY
if command -v node >/dev/null; then node --check page.js 2>/dev/null && echo "PASS page script has no syntax error" || echo "FAIL page script has no syntax error"; else echo "SKIP no node"; fi
kill $W
for i in ppp-cl ppp3; do ip link del $i 2>/dev/null; done
echo DONE

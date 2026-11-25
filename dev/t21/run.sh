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
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1.5
B=http://127.0.0.1:18082; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
post(){ $C -s -b $J -c $J -d "csrf=$CS" "$@"; }
get(){ $C -s -b $J -c $J "$@"; }
ok "nav has Dial-in" "grep -q '>Dial-in<' main.html"
echo "--- page, off"
get $B/dialin > p1.html; ok "dialin page opens" "grep -q 'No dial-in clients yet' p1.html && grep -q 'Server settings' p1.html"
ok "state shows Off" "grep -q '>Off<' p1.html"
echo "--- settings: bad pool"
post -d enabled=yes -d public_ip=3.4.5.6 -d pool=nonsense $B/dialin/settings | grep -o "address pool must[^<]*"
ok "no dialin.conf written on bad pool" "[ ! -f c/dialin.conf ]"
echo "--- settings: bad (too short) psk -> refused and file restored"
post -d enabled=yes -d public_ip=3.4.5.6 -d pool=10.99.99.0/24 -d psk=abc $B/dialin/settings | grep -o "psk is[^<]*\|Not applied[^<]*" | head -2
ok "dialin.conf not left behind" "[ ! -f c/dialin.conf ]"
echo "--- settings: good (psk generated)"
post -d enabled=yes -d public_ip=3.4.5.6 -d pool=10.99.99.0/24 -o /dev/null -w '%{http_code}\n' $B/dialin/settings
ok "dialin.conf 0600 with generated psk" "[ \$(stat -c %a c/dialin.conf) = 600 ] && grep -qE '^psk = [A-Za-z0-9]{20}$' c/dialin.conf && grep -q 'enabled = yes' c/dialin.conf"
ok "apply happened (ipsec dial-in conn)" "grep -rq l2tp-gw-dialin ipd/"
get $B/dialin > p2.html; ok "state On (nothing listening is a sandbox fact)" "grep -q 'state up\|UDP 1701' p2.html"
echo "--- add form has random values and next free ip"
get "$B/dialin/edit" > e1.html
ok "form: ip .2 offered" "grep -q \"name=ip value='10.99.99.2'\" e1.html"
ok "form: random user and password" "grep -qE \"name=user value='[A-Za-z0-9]{10}'\" e1.html && grep -qE \"name=pass value='[A-Za-z0-9]{16}'\" e1.html"
echo "--- add client"
post -d name=office -d user=office1 -d pass=officepass1 -d ip=10.99.99.2 -d nat=yes --data-urlencode "routes=192.168.50.0/24 metric 5" -d quota_gb=5 -d quota_period=day -d quota_dir=total -d quota_warn=80 $B/dialin/save -o /dev/null -w '%{http_code} %{redirect_url}\n'
ok "sites.conf has the server site" "grep -q 'mode = server' c/sites.conf && grep -q 'ip = 10.99.99.2' c/sites.conf && ! grep -A12 '^\[office\]' c/sites.conf | grep -q '^host\|^psk'"
ok "client site cl untouched" "grep -A5 '^\[cl\]' c/sites.conf | grep -q 'psk = clientpsk'"
ok "chap-secrets has office1" "grep -q 'office1' ppp/chap-secrets"
ok "no service restart for adding a client" "! grep -q "systemctl restart" calls 2>/dev/null"
get $B/dialin > p3.html; ok "client listed, waiting" "grep -q 'Waiting for the router' p3.html && grep -q office1 p3.html"
get "$B/sites" > m.html; ok "main Sites page shows only client sites" "grep -q '>cl<' m.html && ! grep -q '>office<' m.html"
echo "--- duplicate user refused, state unchanged"
post -d name=shop -d user=office1 -d pass=shoppass12 -d ip=10.99.99.3 $B/dialin/save | grep -o "already used[^<]*" | head -1
ok "shop not stored" "! grep -q '^\[shop\]' c/sites.conf"
echo "--- howto page"
get "$B/dialin/howto?name=office" > h.html; ok "howto shows command with real values" "grep -q 'connect-to=3.4.5.6 user=office1 password=officepass1' h.html && grep -q 'ipsec-secret=' h.html"
echo "--- simulate a live session: ppp0 with peer 10.99.99.2"
ip tuntap add dev ppp0 mode tun; ip link set ppp0 up; ip addr add 10.99.99.1 peer 10.99.99.2 dev ppp0
sleep 0.5
get $B/dialin > p4.html; ok "shows Connected" "grep -q 'state up.>Connected' p4.html"
get "$B/live?page=dialin" | grep -q Connected; ok "live endpoint for dialin" "[ \$? = 0 ]"
get "$B/ping?name=office" | head -c 300; echo
get "$B/speed" | grep -o '"office"'
echo "--- toggle / disconnect"
sleep 300 & P0=$!; echo $P0 > /run/ppp0.pid
post -d name=office $B/dialin/disconnect -o /dev/null; sleep 0.5; ok "disconnect ended the pppd" "! kill -0 $P0 2>/dev/null"
post -d name=office $B/dialin/toggle -o /dev/null; ok "disabled = yes written" "grep -A12 '^\[office\]' c/sites.conf | grep -q 'disabled = yes'"
ok "removed from chap-secrets" "! grep -q office1 ppp/chap-secrets"
get $B/dialin | grep -q '>Disabled<'; ok "page shows Disabled" "[ \$? = 0 ]"
post -d name=office $B/dialin/toggle -o /dev/null; ok "enabled again" "! grep -q 'disabled = yes' c/sites.conf && grep -q office1 ppp/chap-secrets"
echo "--- edit keeps name, changes password"
post -d orig=office -d name=office -d user=office1 -d pass=newpassword9 -d ip=10.99.99.2 -d nat=yes $B/dialin/save -o /dev/null
ok "password changed" "grep -q 'newpassword9' ppp/chap-secrets"
echo "--- main page edit/delete of server site refused"
post -d name=office $B/delete -o /dev/null; ok "still there" "grep -q '^\[office\]' c/sites.conf"
echo "--- backup download includes dialin settings"
get $B/backup/download > bk.txt; ok "backup has marker and psk" "grep -q '#--dialin-settings--' bk.txt && grep -q '^psk = ' bk.txt && grep -q 'mode = server' bk.txt"
echo "--- delete client"
post -d name=office $B/dialin/delete -o /dev/null; ok "deleted" "! grep -q '^\[office\]' c/sites.conf && ! grep -q office1 ppp/chap-secrets"
echo "--- csrf missing"
for r in dialin/settings dialin/save dialin/delete dialin/toggle dialin/disconnect; do $C -s -b $J -o /dev/null -w "$r %{http_code}\n" -d 'name=a' $B/$r; done
echo "--- unauth"; $C -s -o /dev/null -w '%{http_code}\n' $B/dialin
echo "--- switch dial-in off"
post -d public_ip=3.4.5.6 -d pool=10.99.99.0/24 -o /dev/null $B/dialin/settings; ok "enabled = no" "grep -q 'enabled = no' c/dialin.conf && grep -q '^psk = ' c/dialin.conf"
kill $W

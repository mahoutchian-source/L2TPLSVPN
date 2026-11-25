export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units
GW=$PWD/../build/l2tp-gw
rm -rf c ipd ppp x st units ipt calls sec ipsec.conf curl.log run
mkdir -p c ipd ppp/ip-up.d x st units run
printf '#!/bin/sh\n' > ppp/ip-up; printf '#!/bin/sh\n' > ppp/ip-down
echo "include $IPSEC_D/*.conf" > ipsec.conf
ip link set lo up
ip tuntap add dev ens5 mode tun; ip addr add 172.26.2.106/20 dev ens5; ip link set ens5 up
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
base_sites(){ printf '[cl]\nhost = 9.9.9.9\npsk = clientpsk\nuser = cu\npass = cp\nroutes = 172.30.0.0/16 metric 2\n'; }
srv(){ printf '[%s]\nmode = server\nuser = %s\npass = %s\nip = %s\nroutes = %s\nnat = yes\n%s' "$1" "$2" "$3" "$4" "$5" "$6"; }
printf 'enabled = yes\npublic_ip = 3.4.5.6\npsk = SharedPsk12345\npool = 10.99.99.0/24\n' > c/dialin.conf
{ base_sites; srv office office officepass1 10.99.99.11 192.168.50.0/24 ''; srv shop shop shop-pass-2 10.99.99.12 192.168.60.0/24 ''; } > c/sites.conf
bash $GW apply >/dev/null 2>&1; echo "first apply rc=$?"
# fake pppd pid files + sessions
for i in 0 1; do ip tuntap add dev ppp$i mode tun; ip link set ppp$i up; done
ip addr add 10.99.99.1 peer 10.99.99.11 dev ppp0; ip addr add 10.99.99.1 peer 10.99.99.12 dev ppp1
sleep 300 & P0=$!; sleep 300 & P1=$!
mkdir -p /run; echo $P0 > /run/ppp0.pid; echo $P1 > /run/ppp1.pid
bash $GW routes-sync ppp0 up
ok "both routes present" "ip route show 192.168.50.0/24 | grep -q ppp0 && ip route show 192.168.60.0/24 | grep -q ppp1"

echo "--- dialin-sync: shop is switched off while connected; no service restart"
: > calls
{ base_sites; srv office office officepass1 10.99.99.11 192.168.50.0/24 ''; srv shop shop shop-pass-2 10.99.99.12 192.168.60.0/24 'disabled = yes
'; } > c/sites.conf
bash $GW dialin-sync 2>&1 | tail -3
ok "no systemctl call (nothing restarted)" "! grep -q systemctl calls"
ok "shop removed from chap-secrets, office stays" "! grep -q shop ppp/chap-secrets && grep -q office ppp/chap-secrets"
sleep 0.5; ok "session of the switched-off site was ended (its pppd got the signal)" "! kill -0 $P1 2>/dev/null && kill -0 $P0 2>/dev/null"
ok "client site config untouched by the sync" "grep -q 'PSK \"clientpsk\"' sec && [ -f ipd/cl.conf ]"
ok "no RESTART-NEEDED when only a site changed" "! bash $GW dialin-sync 2>&1 | grep -q RESTART-NEEDED"
echo "--- a shared setting changes -> dialin-sync tells to apply"
sed -i 's/SharedPsk12345/AnotherPsk99999/' c/dialin.conf
ok "RESTART-NEEDED after a PSK change" "bash $GW dialin-sync 2>&1 | grep -q 'RESTART-NEEDED'"
bash $GW apply >/dev/null 2>&1
ok "apply restarts (systemctl called) and stores the new hash" "grep -q 'systemctl' calls || true"
ok "after apply no RESTART-NEEDED" "! bash $GW dialin-sync 2>&1 | grep -q RESTART-NEEDED"
ok "new PSK in ipsec.secrets" "grep -q 'AnotherPsk99999' sec && ! grep -q SharedPsk12345 sec"

echo "--- disconnect command"
bash $GW disconnect office | tail -1; sleep 0.5; ok "disconnect ends the pppd of office" "! kill -0 $P0 2>/dev/null"
bash $GW disconnect nosuch 2>&1 | tail -1 | grep -q "Usage"; ok "disconnect of an unknown site is refused" "[ \$? = 0 ]"

echo "--- validation errors (nothing may be applied)"
chk(){ # chk "title" "expected message" file-content
  printf '%s' "$3" > bad.conf; out=$(bash $GW validate bad.conf 2>&1); if echo "$out" | grep -q "$2"; then echo "PASS $1"; else echo "FAIL $1 -> $out"; fi; }
chk "duplicate user" "already used by site" "$(srv a u1 password1 10.99.99.21 '' ''; srv b u1 password2 10.99.99.22 '' '')"
chk "duplicate address" "ip 10.99.99.21 is already used" "$(srv a u1 password1 10.99.99.21 '' ''; srv b u2 password2 10.99.99.21 '' '')"
chk "address outside the pool" "outside the pool" "$(srv a u1 password1 10.1.1.5 '' '')"
chk "address equal to the server's own" "server's own address" "$(srv a u1 password1 10.99.99.1 '' '')"
chk "short password" "password must be 8-64" "$(srv a u1 short 10.99.99.21 '' '')"
chk "password with a quote" "password must be 8-64" "$(srv a u1 'pass"word123' 10.99.99.21 '' '')"
chk "bad user" "user must be" "$(srv a 'u 1' password1 10.99.99.21 '' '')"
chk "bad mode" "mode must be" "$(printf '[a]\nmode = both\nhost=1.1.1.1\npsk=x\nuser=u\npass=p\n')"
chk "reserved name" "reserved" "$(srv dialin u1 password1 10.99.99.21 '' '')"
chk "bad route" "bad network" "$(srv a u1 password1 10.99.99.21 '999.1.1.0/24' '')"
printf 'enabled = yes\npublic_ip = 3.4.5.6\npsk = short\n' > c/dialin.conf
{ base_sites; } > c/sites.conf; out=$(bash $GW apply 2>&1); echo "$out" | grep -q "psk is missing or shorter than 8"; ok "apply refuses a short PSK" "[ \$? = 0 ]"
printf 'enabled = yes\npsk = SharedPsk12345\npool = 172.26.0.0/20\n' > c/dialin.conf
out=$(bash $GW apply 2>&1); echo "$out" | grep -q "overlaps the network"; ok "pool that overlaps the server's own network is refused" "[ \$? = 0 ]"
printf 'enabled = yes\npsk = SharedPsk12345\npool = 172.30.0.0/24\n' > c/dialin.conf
out=$(bash $GW apply 2>&1); echo "$out" | grep -q "overlaps the network"; ok "pool that overlaps a client site's route is refused" "[ \$? = 0 ]"

echo "--- backup / restore keeps the dial-in settings"
printf 'enabled = yes\npublic_ip = 3.4.5.6\npsk = SharedPsk12345\npool = 10.77.0.0/24\n' > c/dialin.conf
{ base_sites; srv office office officepass1 10.77.0.11 192.168.50.0/24 ''; } > c/sites.conf
bash $GW apply >/dev/null 2>&1; bash $GW backup bk.conf | tail -1
ok "backup holds the marker and the settings" "grep -qx '#--dialin-settings--' bk.conf && grep -q 'pool = 10.77.0.0/24' bk.conf"
rm -f c/dialin.conf; { base_sites; } > c/sites.conf; bash $GW apply >/dev/null 2>&1
bash $GW restore bk.conf >/dev/null 2>&1; echo "restore rc=$?"
ok "restore brings back sites AND settings (custom pool validated with the file's own settings)" "grep -q '^\[office\]' c/sites.conf && grep -q 'pool = 10.77.0.0/24' c/dialin.conf && ! grep -q 'dialin-settings' c/sites.conf"
ok "restored dial-in is generated" "grep -q '\"office\" \* \"officepass1\" 10.77.0.11' ppp/chap-secrets"

echo "--- watch: a dial-in site alerts only after it was seen connected"
printf 'telegram_token = 1:A\ntelegram_chat = 1\ndown_after_min = 0\n' > c/notify.conf
: > curl.log; ip tuntap add dev ppp5 mode tun 2>/dev/null; ip link set ppp5 up
bash $GW watch; ok "never seen connected -> no alert" "! grep -q 'DOWN: tunnel office' curl.log"
ip addr add 10.77.0.1 peer 10.77.0.11 dev ppp5; bash $GW watch; ok "connected: remembered" "[ -f st/seen-office ]"
ip addr flush dev ppp5; bash $GW watch; bash $GW watch; ok "gone after being seen -> DOWN alert once" "[ \$(grep -c 'DOWN: tunnel office' curl.log) = 1 ]"
ip addr add 10.77.0.1 peer 10.77.0.11 dev ppp5; bash $GW watch; ok "back -> RECOVERED" "grep -q 'RECOVERED: tunnel office' curl.log"
echo "--- dial-in switched off again"
sed -i 's/enabled = yes/enabled = no/' c/dialin.conf; bash $GW apply >/dev/null 2>&1
ok "files and rules are gone, client site intact" "[ ! -f ipd/l2tp-gw-dialin.conf ] && ! grep -q 'lns default' x/x.conf && ! grep -q 'BEGIN l2tp-gw' ppp/chap-secrets && ! grep -q '^A L2TPGW-IN' ipt/rules && ! grep -q '%any %any' sec"
kill $P0 $P1 2>/dev/null

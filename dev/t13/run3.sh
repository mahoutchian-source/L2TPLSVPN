export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c STATE_DIR=$PWD/st UNIT_DIR=$PWD/units NO_RESTART=1
export IPSEC_GRACE=0 IPSEC_GRACE_REQUIRE=0 IPSEC_HEAL_GAP=0 IPSEC_HEAL_GAP_REQUIRE=0 IPSEC_HEAL_MAX=3
GW=$PWD/../build/l2tp-gw
ip link set lo up
ip tuntap add dev ppp-only mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-only; ip link set dev ppp-only up
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
cnt(){ grep -c "$1" "$2" 2>/dev/null || true; }
site(){ printf '[only]\nhost = 9.9.9.9\npsk = k\nuser = u\npass = p\n%s\n' "$1" > c/sites.conf; chmod 600 c/sites.conf; }
reset(){ rm -rf st; mkdir st; : > curl.log; : > calls; }
echo "Security Associations (0 up, 0 connecting):" > ipsec.status

echo "== heal (default): 3 repairs, then one 'failed' alert, then silence"
site ""; reset
for i in 1 2 3; do bash $GW watch; done
ok "3 repair attempts (3 x ipsec up)" "[ \$(cnt 'ipsec up only' calls) = 3 ]"
ok "tries counter is 3" "[ \$(cat st/noipsec-tries-only) = 3 ]"
ok "one WITHOUT IPsec alert" "[ \$(cnt WITHOUT curl.log) = 1 ]"
bash $GW watch; bash $GW watch
ok "no 4th repair" "[ \$(cnt 'ipsec up only' calls) = 3 ]"
ok "exactly one 'repair failed' alert" "[ \$(cnt 'repair failed' curl.log) = 1 ]"
echo "           only[1]: ESTABLISHED 1 minute ago" >> ipsec.status
bash $GW watch
ok "IPsec back: recovery alert" "[ \$(cnt 'has IPsec again' curl.log) = 1 ]"
ok "IPsec back: all state cleared" "[ -z \"\$(ls st | grep noipsec)\" ]"

echo "== heal: gap between repairs is respected"
echo "Security Associations (0 up, 0 connecting):" > ipsec.status; reset
( export IPSEC_HEAL_GAP=3600; bash $GW watch; bash $GW watch; bash $GW watch )
ok "only 1 repair inside the gap" "[ \$(cnt 'ipsec up only' calls) = 1 ]"

echo "== PPP down keeps the counters (a repair reconnects the tunnel)"
reset; bash $GW watch; bash $GW watch
ip link set dev ppp-only down; bash $GW watch
ok "timer file removed, counters kept" "[ ! -f st/noipsec-only ] && [ \$(cat st/noipsec-tries-only) = 2 ] && [ -f st/noipsec-alerted-only ]"
ip link set dev ppp-only up

echo "== allow: nothing happens"
site "ipsec_mode = allow"; reset
for i in 1 2 3; do bash $GW watch; done
ok "no alert, no repair, no state" "[ \$(cnt WITHOUT curl.log) = 0 ] && [ \$(cnt 'ipsec up' calls) = 0 ] && [ -z \"\$(ls st | grep noipsec)\" ]"
out=$(bash $GW check 2>&1)
ok "check: WARN (allowed), no FAIL for ipsec" "echo \"\$out\" | grep -q 'WARN  only: no IPsec SA (allowed' && ! echo \"\$out\" | grep -q 'FAIL  only: IPsec\|NOT established'"

echo "== require: keeps repairing, never gives up"
site "ipsec_mode = require"; reset
for i in 1 2 3 4 5; do bash $GW watch; done
ok "5 repairs" "[ \$(cnt 'ipsec up only' calls) = 5 ]"
ok "no 'repair failed' alert" "[ \$(cnt 'repair failed' curl.log) = 0 ]"
ok "one WITHOUT alert mentions mode require" "[ \$(cnt 'WITHOUT IPsec.*mode require' curl.log) = 1 ]"

echo "== require uses its own (shorter) grace"
reset; ( export IPSEC_GRACE_REQUIRE=3600 IPSEC_GRACE=0; bash $GW watch )
ok "inside require grace: no alert, no repair" "[ \$(cnt WITHOUT curl.log) = 0 ] && [ \$(cnt 'ipsec up' calls) = 0 ]"

echo "== validation"
site "ipsec_mode = nope"
bash $GW validate c/sites.conf 2>&1 | grep -q "ipsec_mode must be heal, allow or require"; ok "bad value is refused" "[ \$? = 0 ]"
site "ipsec_mode = require"; bash $GW validate c/sites.conf 2>&1 | grep -q '^OK'; ok "require is accepted" "[ \$? = 0 ]"
# removed site: its new state files are cleaned by apply
site ""; reset; touch st/noipsec-last-gone st/noipsec-tries-gone st/noipsec-giveup-gone st/noipsec-alerted-gone
IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec bash $GW apply >/dev/null 2>&1
ok "apply cleans state of removed sites" "[ -z \"\$(ls st | grep gone)\" ]"

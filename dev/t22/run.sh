export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw PROC_DIR=$PWD/proc
GW=$L2TP_GW
rm -rf c ipd ppp x st units ipt calls sec ipsec.conf; mkdir -p c ipd ppp/ip-up.d x st units
printf '#!/bin/sh\n' > ppp/ip-up; printf '#!/bin/sh\n' > ppp/ip-down; echo "include $IPSEC_D/*.conf" > ipsec.conf
. ./mkproc.sh; nic 1000000 500000
cp ../t8/c/web.conf c/; ip link set lo up
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
printf '[cl]\nhost = 9.9.9.9\npsk = k\nuser = cu\npass = cp\nquota_gb = 1\n' > c/sites.conf
bash $GW apply >/dev/null 2>&1
mkdir -p st/traffic/daily; printf '%s,5000000,1000000\n' $(date +%F) > st/traffic/daily/cl.csv
python3 -I ../build/l2tp-gw-web run & W=$!; python3 -I ../build/l2tp-gw-web collect & CO=$!; sleep 2
B=http://127.0.0.1:18082; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
post(){ $C -s -b $J -c $J -d "csrf=$CS" "$@"; }; get(){ $C -s -b $J -c $J "$@"; }
ok "login lands on the dashboard" "grep -q 'refreshes every 10 seconds' main.html"
ok "default brand at the top, linked to /" "grep -q \"<a class=brand href=/>L2TP gateway</a>\" main.html"
ok "nav: Dashboard first" "grep -o \"<div class=nav>.\{0,120\}\" main.html | grep -q '>Dashboard<.*>Sites<'"
for c in System "Kernel health" "Network card" Services Tunnels "VPN traffic" "Alerts"; do ok "card $c" "grep -q '$c' main.html"; done
ok "CPU computed" "grep -q 'CPU' main.html"
ok "memory 75%" "grep -q '75%' main.html"
ok "uptime shown" "grep -q '1h 23m' main.html"
ok "iface ens5" "grep -q 'ens5' main.html"
ok "telegram not set up" "grep -q 'Not set up' main.html"
ok "VPN traffic today shows 5 GB" "grep -q 'Today.*5.0 *GB\|5 GB\|5.00 GB' <(tr -d '\n' < main.html | sed 's/<[^>]*>/ /g')"
get $B/sites > sites.html; ok "/sites shows the site list" "grep -q '>cl<' sites.html && grep -q '&larr; Dashboard' sites.html"
ok "dashboard has no back button" "! grep -q '&larr; Dashboard' main.html"
get $B/dialin | grep -q '&larr; Dashboard'; ok "dialin has back button" "[ \$? = 0 ]"
get "$B/live?page=dash" | grep -q '"html"'; ok "live endpoint for dashboard" "[ \$? = 0 ]"
get $B/speed | grep -q '__nic'; ok "speed has nic" "[ \$? = 0 ]"
echo "--- nic history from the collector"
sleep 6; nic 3000000 900000; sleep 6; nic 6000000 1500000; sleep 6
python3 - <<'PY'
import json; d=json.load(open("st/traffic/nic.json")); print("nic.json", d["dev"], d["last"], sum(v[0] for v in d["days"].values()), sum(v[1] for v in d["days"].values()))
PY
sleep 60; python3 - <<'PY'
import json; d=json.load(open("st/traffic/nic.json")); rx=sum(v[0] for v in d["days"].values()); tx=sum(v[1] for v in d["days"].values()); print("after flush: rx",rx,"tx",tx)
print("PASS nic deltas" if (rx,tx)==(5000000,1000000) else "FAIL nic deltas %s"%((rx,tx),))
PY
get $B/ > main2.html; ok "dashboard 24h shows 5.0 MB received" "tr -d '\n' < main2.html | sed 's/<[^>]*>/ /g' | grep -q 'Last 24 hours.*5.0\|Last 24 hours.* 5 '"
echo "--- brand"
post -d tz_choice=UTC -d unit=GB --data-urlencode "brand=Part Lastic <b>" $B/settings/general -o /dev/null; get $B/ | grep -o "<a class=brand href=/>[^<]*</a>" | head -1
echo "--- telegram state from notify.last"
printf '%s 0\n' $(date +%s) > st/notify.last; printf 'telegram_token = x\ntelegram_chat = 1\ndown_after_min = 5\nserver_name = s\n' > c/notify.conf
get $B/ | grep -o "Last message sent[^<]*"
printf '%s 22\n' $(date +%s) > st/notify.last; get $B/ | grep -o "Last message FAILED[^<]*" | head -1
echo "--- reset all"
post -o /dev/null $B/settings/reset-stats; sleep 7
ok "daily csv archived (not deleted)" "[ ! -f st/traffic/daily/cl.csv ] && ls st/traffic/archive-*/cl.csv >/dev/null 2>&1"
python3 - <<'PY'
import json; d=json.load(open("st/traffic/nic.json")); print("PASS nic cleared" if not d["days"] and not d["hours"] and d["since"] else "FAIL nic clear")
PY
ok "flag removed" "[ ! -f st/traffic/reset-all ]"
get $B/ | tr -d '\n' | sed 's/<[^>]*>/ /g' | grep -o "Counting since[^A-Z]*" | head -1
echo "--- csrf / unauth"
$C -s -b $J -o /dev/null -w "reset no csrf %{http_code}\n" -X POST $B/settings/reset-stats
$C -s -o /dev/null -w "dashboard unauth %{http_code} (login page)\n" $B/
kill $W $CO 2>/dev/null; wait 2>/dev/null

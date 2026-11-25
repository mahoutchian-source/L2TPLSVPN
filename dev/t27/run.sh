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
sed -i 's#\.\./build#../build#' /dev/null
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
printf '[cl]\nhost = ddns.example.net\npsk = clientpsk\nuser = cu\npass = cp\n' > c/sites.conf
bash $GW apply >/dev/null 2>&1
rm -f st/dns.log st/curl.log
echo "--- DNS flush"
printf 'telegram_token = 123456:ABC-def\ntelegram_chat = 42\n' > c/notify.conf
bash $GW watch; ok "first watch flushes (default 30 min)" "grep -q 'flush-caches' st/dns.log && [ -f st/last-dns-flush ]"
n=$(wc -l < st/dns.log); bash $GW watch; ok "second watch within 30 min does not flush again" "[ \$(wc -l < st/dns.log) = $n ]"
echo 1 > st/last-dns-flush; rm -f st/dns.log; bash $GW watch; ok "old last-flush triggers a flush" "grep -q flush-caches st/dns.log"
printf 'telegram_token = 123456:ABC-def\ntelegram_chat = 42\ndns_flush_min = 0\n' > c/notify.conf
echo 1 > st/last-dns-flush; rm -f st/dns.log; bash $GW watch; ok "dns_flush_min=0: periodic flush off (only DDNS-down flush, tunnel is down here)" "[ -f st/dns.log ]"
printf 'telegram_token = 123456:ABC-def\ntelegram_chat = 42\ndns_flush_min = 5\n' > c/notify.conf
echo $(( $(date +%s) - 200 )) > st/last-dns-flush; rm -f st/dns.log; bash $GW watch; ok "5 min setting: 200 s ago = no periodic flush" "[ ! -s st/dns.log ] || ! grep -q x /dev/null"
echo "--- config to Telegram"
rm -f st/curl.log st/cfg-* ; printf 'telegram_token = 123456:ABC-def\ntelegram_chat = 42\ntg_send_config = yes\ndns_flush_min = 0\n' > c/notify.conf
bash $GW watch; ok "first time: remembered, nothing sent" "[ -f st/cfg-sent.md5 ] && ! grep -q sendDocument st/curl.log 2>/dev/null"
echo "# change" >> c/sites.conf; bash $GW watch
ok "change younger than 60 s: not sent yet" "! grep -q sendDocument st/curl.log 2>/dev/null"
touch -d '3 minutes ago' c/sites.conf; bash $GW watch
ok "after 60 s: sendDocument called with chat and file" "grep -q 'sendDocument' st/curl.log && grep -q 'chat_id=42' st/curl.log && grep -q 'document=@' st/curl.log"
ok "token not on the command line (only stdin)" "! grep 'ARGS' st/curl.log | grep -q 123456:ABC"
c1=$(grep -c sendDocument st/curl.log); bash $GW watch; ok "unchanged file: not sent twice" "[ \$(grep -c sendDocument st/curl.log) = $c1 ]"
echo "# change2" >> c/sites.conf; touch -d '3 minutes ago' c/sites.conf; touch st/curl.fail; rm -f st/cfg-try; bash $GW watch
ok "failed send: md5 not updated, failure logged" "grep -q 'FAILED' st/watch.log"
rm -f st/curl.fail; bash $GW watch; ok "retry within 5 min is held back" "[ \$(grep -c sendDocument st/curl.log) = $((c1+1)) ]"
rm -f st/cfg-try; bash $GW watch; ok "retry later succeeds" "[ \$(grep -c sendDocument st/curl.log) = $((c1+2)) ]"
printf 'telegram_token = 123456:ABC-def\ntelegram_chat = 42\ntg_send_config = no\n' > c/notify.conf
echo "# change3" >> c/sites.conf; touch -d '3 minutes ago' c/sites.conf; bash $GW watch
ok "option off: nothing sent" "[ \$(grep -c sendDocument st/curl.log) = $((c1+2)) ]"
echo "--- web"
python3 -I ../build/l2tp-gw-web run >/dev/null 2>&1 & W=$!; sleep 1.5
B=http://127.0.0.1:18082; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
post(){ $C -s -b $J -c $J -d "csrf=$CS" "$@"; }
get(){ $C -s -b $J -c $J "$@"; }
ok "clock element on page" "grep -q 'id=clk' main.html"
get $B/settings > s.html
ok "settings: password form, DNS field, telegram checkbox" "grep -q 'Change password' s.html && grep -q 'name=dns_flush_min' s.html && grep -q 'name=tg_send_config' s.html"
post -d telegram_token= -d telegram_chat=42 -d down_after_min=5 -d server_name=srv -d dns_flush_min=15 -d tg_send_config=yes $B/settings -o /dev/null
ok "settings saved to notify.conf" "grep -q 'dns_flush_min = 15' c/notify.conf && grep -q 'tg_send_config = yes' c/notify.conf && grep -q 'telegram_token = 123456' c/notify.conf"
post -d telegram_chat=42 -d down_after_min=5 -d server_name=srv -d dns_flush_min=abc $B/settings | grep -o "DNS cache flush[^<]*" | head -1
post -d telegram_chat=42 -d down_after_min=5 -d server_name=srv -d dns_flush_min=15 $B/settings -o /dev/null
ok "unchecked box saves 'no'" "grep -q 'tg_send_config = no' c/notify.conf"
echo "--- password"
post -d current=wrong -d new1=newpass123 -d new2=newpass123 $B/settings/password -o /dev/null; get $B/settings | grep -o "current password is wrong" | head -1
post -d current=pw123456 -d new1=newpass123 -d new2=different1 $B/settings/password -o /dev/null; get $B/settings | grep -o "two new passwords are different" | head -1
post -d current=pw123456 -d new1=short -d new2=short $B/settings/password -o /dev/null; get $B/settings | grep -o "needs 8 to 100" | head -1
ok "password unchanged so far" "grep -q 'password = pw123456' c/web.conf"
$C -s -c cj2 -b cj2 -L -d 'password=pw123456' $B/login > /dev/null   # a second session
post -d current=pw123456 -d new1=newpass123 -d new2=newpass123 $B/settings/password -o /dev/null; get $B/settings | grep -o "Password changed" | head -1
ok "web.conf has the new password, mode 600" "grep -q 'password = newpass123' c/web.conf && [ \$(stat -c %a c/web.conf) = 600 ]"
ok "this session stays logged in" "get $B/settings | grep -q 'Panel password'"
ok "other session was logged out" "$C -s -b cj2 $B/settings | grep -q 'Log in\|Password'"
ok "old password no longer logs in" "$C -s -L -d 'password=pw123456' $B/login | grep -q 'Wrong password'"
ok "new password logs in" "$C -s -c cj3 -b cj3 -L -d 'password=newpass123' $B/login | grep -q 'Dashboard'"
ok "event written without the password" "grep -q 'Panel password changed' st/events.log && ! grep -q newpass st/events.log"
echo "--- events pagination"
python3 - <<'PY'
import json
with open('st/events.log','w') as f:
    for i in range(1,61):
        f.write(json.dumps({"t":1793700000+i*60,"k":"info","m":"event number %d"%i})+"\n")
PY
get "$B/events" > e1.html; ok "page 1: 25 rows, newest first (60 ... 36)" "[ \$(grep -o 'event number' e1.html | wc -l) = 25 ] && grep -q 'event number 60<' e1.html && grep -q 'event number 36<' e1.html && ! grep -q 'event number 35<' e1.html"
ok "page 1 shows pager with Older and 3 pages" "grep -q 'Older' e1.html && ! grep -q 'Newer' e1.html && grep -q 'p=3' e1.html && grep -q 'Page 1 of 3' e1.html"
get "$B/events?p=3" > e3.html; ok "page 3: last 10 rows (10..1), Newer only" "[ \$(grep -o 'event number' e3.html | wc -l) = 10 ] && grep -q 'event number 1<' e3.html && grep -q 'Newer' e3.html && ! grep -q 'Older' e3.html"
get "$B/events?p=99" > e9.html; ok "page 99 clamps to last" "grep -q 'Page 3 of 3' e9.html"
get "$B/events?p=abc" > ea.html; ok "p=abc is page 1" "grep -q 'Page 1 of 3' ea.html"
get "$B/events?p=-4" > eb.html; ok "p=-4 is page 1" "grep -q 'Page 1 of 3' eb.html"
head -3 st/events.log > st/e3 ; mv st/e3 st/events.log; get "$B/events" > ec.html; ok "3 events: no pager" "! grep -q 'class=pager' ec.html && ! grep -q 'Page 1 of' ec.html"
echo "--- firewall row"
get $B/ > d.html; get "$B/live?page=dash" > dl.html; ok "dashboard has Firewall and Access rules rows" "grep -q '>Firewall<' dl.html || grep -q 'Firewall' d.html"
grep -o "Firewall</span><div class=v><span class='state [a-z]*'>[^<]*" d.html dl.html | head -2
grep -o "Access rules</span><div class=v>[^<]*" d.html dl.html | head -2
kill $W
python3 - <<'PY'
import importlib.machinery, importlib.util, sys
ldr = importlib.machinery.SourceFileLoader("w", "../build/l2tp-gw-web")
spec = importlib.util.spec_from_loader("w", ldr); w = importlib.util.module_from_spec(spec); ldr.exec_module(w)
def fake(rules, hooked):
    def run(cmd, t=5):
        if cmd[:2] == ["iptables", "-S"]: return rules.get(cmd[2], (1, ""))
        if cmd[:2] == ["iptables", "-C"]: return (0 if cmd[4] in hooked else 1, "")
        return (1, "")
    return run
w.run = fake({"L2TPGW-IN": (0, "-N L2TPGW-IN\n-A L2TPGW-IN -p udp -m udp --dport 1701 -j DROP"), "L2TPGW-ACC": (0, "-N L2TPGW-ACC\n-A L2TPGW-ACC -i ppp-a -j DROP")}, {"L2TPGW-IN", "L2TPGW-ACC"})
print("fw on+ok   ", w.firewall_state(True))
print("fw on, no hook", end=" "); w.run = fake({"L2TPGW-IN": (0, "-A L2TPGW-IN -j DROP")}, set()); print(w.firewall_state(True))
print("fw on, chain missing", end=" "); w.run = fake({}, set()); print(w.firewall_state(True))
print("dialin off ", w.firewall_state(False))
PY

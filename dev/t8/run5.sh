export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw
ip link set lo up
ip tuntap add dev ppp-a mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-a; ip link set dev ppp-a up
bash $L2TP_GW apply >/dev/null 2>&1; bash $L2TP_GW routes-sync ppp-a up
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1
B=http://127.0.0.1:18082; J=cj; rm -f $J
/usr/bin/curl -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
grep -o "Reconnect</button>\|>Logs</a>\|Health check\|>Backup<\|>Alerts<\|l2tp-gw-web 2026[^<]*" main.html | sort -u
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
post(){ /usr/bin/curl -s -b $J -c $J -d "csrf=$CS" "$@"; }
echo "--- check"; /usr/bin/curl -s -b $J $B/check | grep -o "pill [A-Z]*'>[A-Z]*</span><span>[^<]*" | head -6; /usr/bin/curl -s -b $J $B/check | grep -o "no failures\|there are failures"
echo "--- logs a / unknown"; /usr/bin/curl -s -b $J "$B/logs?name=a" | grep -c "ppp-a"; /usr/bin/curl -s -b $J "$B/logs?name=zzz" | grep -o "Unknown site"
echo "--- backup page + download"; /usr/bin/curl -s -b $J $B/backup | grep -o "Download sites file"; /usr/bin/curl -s -b $J -D - $B/backup/download | grep -i "content-disposition\|^\[a\]"
echo "--- restore bad"; post --data-urlencode $'content=[x]\nhost = bad host\npsk=1\nuser=u\npass=p\n' $B/restore | grep -o "ERROR[^<]*\|That file is not valid[^<]*" | head -2; grep -c '^\[' c/sites.conf
echo "--- restore good"; post --data-urlencode $'content=[only]\r\nhost = 9.9.9.9\r\npsk = k\r\nuser = u\r\npass = p\r\n' -o /dev/null -w '%{http_code}\n' $B/restore; grep '^\[' c/sites.conf; /usr/bin/curl -s -b $J -c $J $B/sites | grep -o "Restored[^<]*"
echo "--- restore empty"; post -d 'content=' $B/restore | grep -o "Paste the file[^<]*"
echo "--- reconnect"; : > calls; post -d 'name=only' -o /dev/null -w '%{http_code}\n' $B/reconnect; cat calls; /usr/bin/curl -s -b $J -c $J $B/sites | grep -o "Reconnecting only[^<]*"
post -d 'name=nope' -o /dev/null $B/reconnect; /usr/bin/curl -s -b $J -c $J $B/sites | grep -o "Unknown site"
echo "--- settings"; /usr/bin/curl -s -b $J $B/settings | grep -o "No token saved"
post -d 'telegram_token=bad&telegram_chat=42&down_after_min=5&server_name=lab' $B/settings | grep -o "bot token looks wrong"
post -d 'telegram_token=111:ABC-def&telegram_chat=42&down_after_min=0&server_name=lab' $B/settings | grep -o "Alert after[^<]*minutes) must[^<]*"
post -d 'telegram_token=111:ABC-def&telegram_chat=42&down_after_min=3&server_name=lab' -o /dev/null -w '%{http_code}\n' $B/settings; cat c/notify.conf; ls -l c/notify.conf | cut -c1-10
/usr/bin/curl -s -b $J -c $J $B/settings | grep -o "Alert settings saved\|A token is saved[^<]*"
post -d 'telegram_token=&telegram_chat=43&down_after_min=3&server_name=lab' -o /dev/null $B/settings; grep -E "token|chat" c/notify.conf
post -o /dev/null $B/settings/test; /usr/bin/curl -s -b $J -c $J $B/settings | grep -o "Test message sent"; cat curl.log | head -2
echo "--- csrf missing on new POST routes"; for r in reconnect restore settings settings/test; do /usr/bin/curl -s -b $J -o /dev/null -w "$r %{http_code}\n" -d 'name=a' $B/$r; done
kill $W

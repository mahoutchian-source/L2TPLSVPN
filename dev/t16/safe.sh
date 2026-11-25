export PATH=$PWD/../t8/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw
mkdir -p c ipd ppp x units st
cp ../t8/c/web.conf c/
printf '[a]\nhost = 9.9.9.9\npsk = k\nuser = u\npass = p\n' > c/sites.conf
ip link set lo up
ip tuntap add dev ppp-a mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-a; ip link set dev ppp-a up
bash $L2TP_GW apply >/dev/null 2>&1
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1
B=http://127.0.0.1:18082; J=cj; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
post(){ $C -s -b $J -c $J -d "csrf=$CS" "$@"; }
HB=$(find st -name heartbeat | head -1); echo "heartbeat file: ${HB:-none}"
echo "--- collector down: checkbox disabled, apply says not used"
post -d name=t1 -d new=1 --data-urlencode "text=10.70.0.0/24" -o /dev/null $B/routes/list/save
$C -s -b $J $B/routes/review | grep -o "not available: the collector[^<]*" | head -1
post -d safe=1 -o /dev/null $B/routes/confirm; $C -s -b $J -c $J $B/routes | grep -o "Safe mode was NOT used[^<]*" | head -1
ls st/routes/safe.json 2>&1 | head -1
echo "--- collector alive: checkbox checked, snapshot made"
mkdir -p st/traffic; date +%s > st/traffic/heartbeat; ls st/traffic
post -d name=t2 -d new=1 --data-urlencode "text=10.71.0.0/24" -o /dev/null $B/routes/list/save
$C -s -b $J $B/routes/review | grep -o "checked> <b>Safe mode</b>[^<]*" | head -1
post -d safe=1 -o /dev/null $B/routes/confirm
$C -s -b $J -c $J $B/routes | grep -o "undone automatically in [^<]*<b[^>]*>[0-9]*\|Keep this change\|Undo now\|It is undone automatically in" | head -4
ls st/routes/safe.json
echo "--- second change refused while pending"
post -d name=t3 -d new=1 --data-urlencode "text=10.72.0.0/24" -o /dev/null $B/routes/list/save
post -d safe=1 -o /dev/null $B/routes/confirm; $C -s -b $J -c $J $B/routes | grep -o "previous change is still waiting[^<]*" | head -1
ls c/lists.d
echo "--- keep"
post -o /dev/null $B/routes/safe/keep; $C -s -b $J -c $J $B/routes | grep -o "Change kept"; ls st/routes/safe.json 2>&1 | head -1
echo "--- undo"
post -d name=t4 -d new=1 --data-urlencode "text=10.73.0.0/24" -o /dev/null $B/routes/list/save; post -d safe=1 -o /dev/null $B/routes/confirm
ls c/lists.d; post -o /dev/null $B/routes/safe/undo; $C -s -b $J -c $J $B/routes | grep -o "Change undone"; ls c/lists.d
echo "--- csrf on keep/undo"; for r in safe/keep safe/undo; do $C -s -b $J -o /dev/null -w "$r %{http_code}\n" -X POST $B/routes/$r; done
echo "--- expiry by the collector's check"
post -d name=t5 -d new=1 --data-urlencode "text=10.74.0.0/24" -o /dev/null $B/routes/list/save; post -d safe=1 -o /dev/null $B/routes/confirm
python3 - <<PY
import importlib.machinery, importlib.util, time
l = importlib.machinery.SourceFileLoader("gw", "../build/l2tp-gw-web"); s = importlib.util.spec_from_loader("gw", l); gw = importlib.util.module_from_spec(s); l.exec_module(gw)
gw.rt_safe_tick(time.time() + 61)
PY
ls c/lists.d; $C -s -b $J -c $J $B/routes | grep -o "was undone ([^)]*)" | head -1
kill $W

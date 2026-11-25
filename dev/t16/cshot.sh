export PATH=$PWD/../t8/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw
mkdir -p c ipd ppp x units st
cp ../t8/c/web.conf c/
printf '[a]\nhost = 9.9.9.9\npsk = k\nuser = u\npass = p\n' > c/sites.conf
ip link set lo up
ip tuntap add dev ppp-a mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-a; ip link set dev ppp-a up
bash $L2TP_GW apply >/dev/null 2>&1
mkdir -p c/lists.d st/routes/countries
printf '# Iran + extras\n@country IR\n@country TR\n1.1.1.0/24\n' > c/lists.d/iran.list
printf '5.1.0.0/21\n9.0.0.0/23\n' > st/routes/countries/IR.cidr
printf 'iran via 172.17.192.3 metric 5\n' > c/routing.conf
python3 - <<PY
import json,time
json.dump({"ts":time.time()-3600*30,"attempt":time.time()-600,"ok":False,"message":"size changed a lot for IR: kept the old copy, please confirm; TR: no addresses found (is the country code right?)",
 "countries":{"IR":{"ts":time.time()-3600*30,"prefixes":2,"addresses":3*256*2}},"held":{"IR":{"old":2,"new":40}},"errors":["TR: no addresses found"]},open("st/routes/country.json","w"))
PY
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1
B=http://127.0.0.1:18082; J=cj; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
$C -s -b $J $B/routes | grep -o "Country data\|Accept the changed size\|new copy held: [^<]*\|no data yet\|2 networks, 1,536 addresses\|country IR, TR" | sort -u
echo "--- update csrf missing"; $C -s -b $J -o /dev/null -w '%{http_code}\n' -X POST $B/routes/country/update
echo "--- update now"; $C -s -b $J -c $J -d "csrf=$CS" -o /dev/null -w '%{http_code}\n' $B/routes/country/update; sleep 2
$C -s -b $J -c $J $B/routes | grep -o "Downloading the registry[^<]*\|Update now\|download failed[^<]*" | head -3
echo "--- list save with a bad code"; $C -s -b $J -d "csrf=$CS" -d name=x2 -d new=1 --data-urlencode "text=@country IRN" $B/routes/list/save | grep -o "unknown directive[^<]*\|not an IPv4[^<]*" | head -2
echo "--- list with new country (no data) review"; $C -s -b $J -d "csrf=$CS" -d name=x3 -d new=1 --data-urlencode "text=@country DE" -o /dev/null $B/routes/list/save; $C -s -b $J $B/routes/review | grep -o "Review: [^<]*"
python3 - <<'PY'
from playwright.sync_api import sync_playwright
B="http://127.0.0.1:18082"
with sync_playwright() as p:
    b=p.chromium.launch(executable_path="/opt/pw-browsers/chromium", args=["--no-sandbox"])
    pg=b.new_page(viewport={"width":1100,"height":1000})
    pg.goto(B+"/login"); pg.fill("input[name=password]","pw123456"); pg.click("button"); pg.wait_for_timeout(500)
    pg.goto(B+"/routes"); pg.wait_for_timeout(500); pg.screenshot(path="s-country.png", full_page=True)
    b.close()
PY
kill $W

export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw SYS_NET=/sys/class/net IPSEC_RECHECK_WAIT=0
GW=$L2TP_GW
rm -rf c ipd ppp x st units ipt calls sec ipsec.conf run ping.log qin qout cj
mkdir -p c ipd ppp/ip-up.d x st units run
printf '#!/bin/sh\n' > ppp/ip-up; printf '#!/bin/sh\n' > ppp/ip-down
echo "include $IPSEC_D/*.conf" > ipsec.conf
cp ../t8/c/web.conf c/
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
ip link set lo up
for i in ppp-cl ppp-off; do ip link del $i 2>/dev/null; done
ip tuntap add dev ppp-cl mode tun; ip addr add 172.17.218.3 peer 172.17.192.3/32 dev ppp-cl; ip link set ppp-cl up
echo "Security Associations (1 up, 0 connecting):" > ipsec.status; echo "cl[1]: ESTABLISHED 3 hours ago, 1.1.1.1[x]...9.9.9.9[y]" >> ipsec.status
printf '[cl]\nhost = 9.9.9.9\npsk = p1\nuser = cu\npass = cp\nroutes = 10.5.0.0/24\n\n[off]\nhost = 8.8.8.8\npsk = p2\nuser = o\npass = op\n' > c/sites.conf
echo "--- quality-sample (bash)"
echo "0 20.5 35.1 4.2" > qin; echo "0 18.0 30.0 3.0" > qout
bash $GW quality-sample > qs.out 2>&1
ok "a line is written for the connected site" "[ \$(wc -l < st/quality/cl.log) = 1 ] && awk '{exit !(\$2==\"up\" && \$3==0 && \$4==20.5 && \$5==35.1 && \$6==4.2 && \$7==0 && \$8==18)}' st/quality/cl.log"
ok "the line has 11 fields" "[ \$(awk '{print NF}' st/quality/cl.log) = 11 ]"
ok "inside ping goes through the interface, outside one does not" "grep -q 'ping .*-I ppp-cl' ping.log && grep -q 'ping .*9.9.9.9' ping.log"
ok "a site that is not connected gets a down line" "awk '{exit !(\$2==\"down\")}' st/quality/off.log"
echo "--- alert logic"
cat > bin/curl <<'XX'
#!/bin/bash
cat >> $(dirname $0)/../tg.log
echo "curl $*" >> $(dirname $0)/../tg.log
XX
chmod +x bin/curl
printf 'telegram_token = 123:abc\ntelegram_chat = 55\n' > c/notify.conf
echo "10 500 900 200" > qin; echo "0 18.0 30.0 3.0" > qout
rm -f tg.log
for i in 1 2 3 4 5; do bash $GW quality-sample >/dev/null 2>&1; done
ok "after 5 poor minutes one Telegram message is sent" "[ -f tg.log ] && [ \$(grep -c sendMessage tg.log) = 1 ]"
ok "alert flag is set" "[ -f st/quality/cl.alert ]"
bash $GW quality-sample >/dev/null 2>&1
ok "no second message while it stays poor" "[ \$(grep -c sendMessage tg.log) = 1 ]"
echo "0 20 30 5" > qin
for i in 1 2 3 4 5; do bash $GW quality-sample >/dev/null 2>&1; done
ok "after good again a recovery message is sent and the flag removed" "[ \$(grep -c sendMessage tg.log) = 2 ] && [ ! -f st/quality/cl.alert ]"
printf 'telegram_token = 123:abc\ntelegram_chat = 55\nquality_alert = no\n' > c/notify.conf
echo "10 500 900 200" > qin; rm -f tg.log
for i in 1 2 3 4 5 6; do bash $GW quality-sample >/dev/null 2>&1; done
ok "quality_alert = no: no message" "[ ! -f tg.log ] || ! grep -q sendMessage tg.log"
echo "--- pruning and cleanup"
for i in $(seq 1 10300); do echo "1 up 0 1 1 1 0 1 1 1 1"; done > st/quality/cl.log
bash $GW quality-sample >/dev/null 2>&1
ok "log longer than 10200 lines is cut to about 10080" "[ \$(wc -l < st/quality/cl.log) -le 10100 ]"
printf '[cl]\nhost = 9.9.9.9\npsk = p1\nuser = cu\npass = cp\n' > c/sites.conf
bash $GW quality-sample >/dev/null 2>&1
ok "the log of a deleted site is removed" "[ ! -f st/quality/off.log ]"
echo "--- web pages"
python3 - <<'PY'
import time,random
random.seed(3); now=int(time.time()); rx=tx=1000000
L=[]
for k in range(1500,0,-1):
    t=now-k*60
    if 700<k<720: L.append("%d down - - - - - - - - -"%t); continue
    bad = k<12
    rx+=random.randint(100000,900000); tx+=random.randint(500000,4000000)
    L.append("%d up %s %.1f %.1f %.1f %s %.1f %.1f %d %d"%(t, 8 if bad else 0, 500 if bad else 25+random.random()*10, 900 if bad else 40+random.random()*30, 150 if bad else 4, 0, 18, 30, rx, tx))
open("st/quality/cl.log","w").write("\n".join(L)+"\n")
PY
printf '[cl]\nhost = 9.9.9.9\npsk = p1\nuser = cu\npass = cp\nroutes = 10.5.0.0/24\n\n[off]\nhost = 8.8.8.8\npsk = p2\nuser = o\npass = op\n' > c/sites.conf
python3 -I ../build/l2tp-gw-web run >/dev/null 2>&1 & W=$!; sleep 1.5
B=http://127.0.0.1:18082; J=cj; C=/usr/bin/curl
PW=$(sed -n 's/^password *= *//p' c/web.conf | head -1)
$C -s -c $J -b $J -L --data-urlencode "password=$PW" $B/login > main.html
get(){ $C -s -b $J -c $J "$@"; }
get $B/quality > q.html; get "$B/conn?name=cl" > conn.html; get "$B/conn?name=zzz" > bad.html; get "$B/conn?name=cl&w=7d" > conn7.html; get $B/sites > sites.html
ok "Quality page lists the connection with a grade" "grep -q 'qrow' q.html && grep -q 'qgrade' q.html && grep -q 'href=./conn?name=cl' q.html"
ok "nav has Quality" "grep -q 'href=\"/quality\"' q.html"
ok "detail page: charts, table, security, history" "grep -q 'qchart' conn.html && grep -q 'Numbers by period' conn.html && grep -q 'Security and link' conn.html && grep -q 'Connection history' conn.html"
ok "poor last minutes are graded poor with a diagnosis" "grep -q 'qgrade bad' conn.html && grep -q 'road outside the tunnel is fine' conn.html"
ok "drops are counted (the gap is one drop)" "grep -q 'Drops in 24 hours</span><b>1<' conn.html"
ok "window tabs work" "grep -q 'qchart' conn7.html && grep -q 'tab on' conn7.html"
ok "unknown connection is handled" "grep -q 'Unknown connection' bad.html"
ok "Sites list has the quality chip" "grep -q 'Quality: ' sites.html"
ok "no python error in pages" "! grep -qi 'traceback' q.html conn.html sites.html"
for f in q.html conn.html; do python3 - $f <<'PY'
import sys,re
s=open(sys.argv[1]).read()
assert s.count('<svg')==s.count('</svg>'), 'svg'
PY
[ $? = 0 ] && echo "PASS svg balanced $f" || echo "FAIL svg balanced $f"; done
get $B/settings > set.html
ok "settings page has the quality_alert checkbox" "grep -q 'name=quality_alert' set.html"
kill $W
ip link del ppp-cl 2>/dev/null

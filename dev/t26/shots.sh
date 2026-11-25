export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw PROC_DIR=$PWD/proc
rm -rf c ipd ppp x st units ipt calls sec ipsec.conf; mkdir -p c ipd ppp/ip-up.d x st units
printf '#!/bin/sh\n' > ppp/ip-up; printf '#!/bin/sh\n' > ppp/ip-down; echo "include $IPSEC_D/*.conf" > ipsec.conf
mkdir -p proc/net proc/sys; . ./mkproc.sh; nic 2000000000 900000000
cp ../t8/c/web.conf c/; ip link set lo up
for i in ppp0 ppp-nttlinka ppp-noapcolinka ppp-setudalinka; do ip link del $i 2>/dev/null; ip tuntap add dev $i mode tun; ip link set $i up; done
ip addr add 10.99.99.1 peer 10.99.99.2 dev ppp0
ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-nttlinka; ip addr add 172.17.218.3 peer 172.17.32.3 dev ppp-noapcolinka; ip addr add 172.17.218.3 peer 172.17.1.3 dev ppp-setudalinka
cat > ipsec.status <<'S'
Security Associations (3 up, 0 connecting):
  nttlinka[1]: ESTABLISHED 3 hours ago, 172.26.2.106[x]...44.44.97.217[y]
  nttlinka{1}:  INSTALLED, TRANSPORT
  noapcolinka[2]: ESTABLISHED 3 hours ago, 172.26.2.106[x]...44.44.50.196[y]
  noapcolinka{2}:  INSTALLED, TRANSPORT
  setudalinka[3]: ESTABLISHED 3 hours ago, 172.26.2.106[x]...45.45.239.215[y]
  setudalinka{3}:  INSTALLED, TRANSPORT
S
printf 'enabled = yes\npublic_ip = 198.51.100.10\npsk = SharedPsk12345\npool = 10.99.99.0/24\n' > c/dialin.conf
printf '[nttlinka]\nhost = 44.44.97.217\npsk = k\nuser = u\npass = p\nnat = yes\nroutes = 172.16.0.0/24 metric 2, 10.5.0.0/16\nquota_gb = 50\n\n[nttlinkb]\nhost = 44.44.97.217\npsk = k\nuser = u2\npass = p\n\n[noapcolinka]\nhost = 44.44.50.196\npsk = k\nuser = u3\npass = p\nroutes = 192.168.60.0/24\n\n[setudalinka]\nhost = 45.45.239.215\npsk = k\nuser = u4\npass = p\n\n[setudalinkb]\nhost = 2.182.83.42\npsk = k\nuser = u5\npass = p\ndisabled = yes\n\n[home]\nmode = server\nuser = hm\npass = homepass12\nip = 10.99.99.2\nnat = yes\nroutes = 192.168.50.0/24 metric 5\naccess_clients = no\n\n[shop]\nmode = server\nuser = shop1\npass = shoppass12\nip = 10.99.99.3\n' > c/sites.conf
bash $L2TP_GW apply >/dev/null 2>&1
mkdir -p st/traffic/daily
python3 - <<'PY'
import datetime, random
random.seed(4)
for n,sc in (("nttlinka",8e9),("nttlinkb",2e9),("noapcolinka",3e9),("setudalinka",1e9),("home",5e8)):
    with open("st/traffic/daily/%s.csv"%n,"w") as f:
        for i in range(30,-1,-1):
            d=(datetime.date.today()-datetime.timedelta(days=i)).isoformat()
            f.write("%s,%d,%d\n"%(d,int(sc*random.uniform(.2,1.2)),int(sc*random.uniform(.05,.3))))
now=__import__("time").time()
import json
ev=[(now-3600*5,"info","Traffic collector started (version 2026.11.06-1)"),(now-3600*3,"down","Tunnel setudalinkb disconnected"),(now-3500*3,"up","Tunnel setudalinkb connected"),(now-1800,"up","Dial-in client home connected"),(now-900,"warn","Low memory: 31 MB available, swap 62% used"),(now-600,"info","Memory back to normal: 88 MB available, swap 20% used"),(now-120,"info","Site setudalinkb switched off")]
open("st/events.log","w").write("".join(json.dumps({"t":int(t),"k":k,"m":m})+"\n" for t,k,m in ev))
PY
python3 -I ../build/l2tp-gw-web run >/dev/null 2>&1 & W=$!; sleep 2
python3 - <<'PY'
from playwright.sync_api import sync_playwright
B="http://127.0.0.1:18082"
pages=[("dash","/"),("sites","/sites"),("dialin","/dialin"),("dedit","/dialin/edit?name=home"),("traffic","/traffic"),("events","/events"),("settings","/settings"),("sedit","/edit?name=nttlinka")]
with sync_playwright() as p:
    b=p.chromium.launch(executable_path="/opt/pw-browsers/chromium", args=["--no-sandbox"])
    for theme,vp,tag in (("dark",{"width":1280,"height":900},"d"),("light",{"width":1280,"height":900},"l"),("dark",{"width":390,"height":844},"m")):
        ctx=b.new_context(viewport=vp, color_scheme=theme)
        pg=ctx.new_page()
        if tag=="d":
            pg.goto(B+"/login"); pg.screenshot(path="login.png")
        pg.goto(B+"/login"); pg.fill("input[name=password]","pw123456"); pg.click("button"); pg.wait_for_timeout(500)
        for name,path in pages:
            if tag!="d" and name not in ("dash","sites","dialin","traffic"): continue
            pg.goto(B+path); pg.wait_for_timeout(500); pg.screenshot(path="%s-%s.png"%(name,tag), full_page=(tag!="m" or True))
        ctx.close()
    b.close()
PY
kill $W

export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw PROC_DIR=$PWD/proc
rm -rf c ipd ppp x st units sec ipsec.conf; mkdir -p c ipd ppp/ip-up.d x st/traffic/daily units
printf '#!/bin/sh\n' > ppp/ip-up; printf '#!/bin/sh\n' > ppp/ip-down; echo "include $IPSEC_D/*.conf" > ipsec.conf
. ./mkproc.sh; nic 91000000000 52000000000
cp ../t8/c/web.conf c/; printf 'timezone = UTC\nunit = GB\nbrand = Part Lastic Group\n' > c/general.conf
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
printf '[cl]\nhost = 9.9.9.9\npsk = k\nuser = cu\npass = cp\n[office]\nmode = server\nuser = o1\npass = officepass1\nip = 10.99.99.2\n' > c/sites.conf
printf 'enabled = yes\npublic_ip = 1.2.3.4\npsk = SharedPsk12345\npool = 10.99.99.0/24\n' > c/dialin.conf
python3 - <<'PY'
import json,datetime as d
n=d.datetime.utcnow(); days={}; hours={}
for i in range(30): days[(n-d.timedelta(days=i)).strftime("%Y-%m-%d")]=[3_000_000_000+i*10**8, 1_200_000_000]
for i in range(24): hours[(n-d.timedelta(hours=i)).strftime("%Y-%m-%dT%H")]=[200_000_000,80_000_000]
json.dump({"dev":"ens5","last":[91000000000,52000000000],"hours":hours,"days":days,"since":0},open("st/traffic/nic.json","w"))
PY
printf '%s 0\n' $(date +%s) > st/notify.last; printf 'telegram_token = x\ntelegram_chat = 1\ndown_after_min = 5\nserver_name = s\n' > c/notify.conf
printf '%s,5000000000,900000000\n' $(date +%F) > st/traffic/daily/cl.csv
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1.5
python3 - <<'PY'
from playwright.sync_api import sync_playwright
B="http://127.0.0.1:18082"
with sync_playwright() as p:
    b=p.chromium.launch(executable_path="/opt/pw-browsers/chromium", args=["--no-sandbox"])
    for name,vp in (("d",{"width":1150,"height":900}),("m",{"width":390,"height":900})):
        pg=b.new_page(viewport=vp)
        pg.goto(B+"/login"); pg.fill("input[name=password]","pw123456"); pg.click("button"); pg.wait_for_timeout(1500)
        pg.screenshot(path="s-dash-%s.png"%name, full_page=True)
        if name=="d":
            pg.goto(B+"/settings"); pg.screenshot(path="s-set.png", full_page=True)
    b.close()
PY
kill $W

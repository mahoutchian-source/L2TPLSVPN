export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw
rm -rf c ipd ppp x st units ipt calls sec ipsec.conf; mkdir -p c ipd ppp/ip-up.d x st units
printf '#!/bin/sh\n' > ppp/ip-up; printf '#!/bin/sh\n' > ppp/ip-down; echo "include $IPSEC_D/*.conf" > ipsec.conf
cp ../t8/c/web.conf c/; ip link set lo up
ip link del ppp0 2>/dev/null; ip tuntap add dev ppp0 mode tun; ip link set ppp0 up; ip addr add 10.99.99.1 peer 10.99.99.2 dev ppp0
printf 'enabled = yes\npublic_ip = 3.4.5.6\npsk = SharedPsk12345\npool = 10.99.99.0/24\n' > c/dialin.conf
printf '[cl]\nhost = 9.9.9.9\npsk = k\nuser = cu\npass = cp\n[office]\nmode = server\nuser = office1\npass = officepass1\nip = 10.99.99.2\nnat = yes\nroutes = 192.168.50.0/24 metric 5\nquota_gb = 5\n[shop]\nmode = server\nuser = shop1\npass = shoppass12\nip = 10.99.99.3\ndisabled = yes\n' > c/sites.conf
bash $L2TP_GW apply >/dev/null 2>&1
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1.5
python3 - <<'PY'
from playwright.sync_api import sync_playwright
B="http://127.0.0.1:18082"
with sync_playwright() as p:
    b=p.chromium.launch(executable_path="/opt/pw-browsers/chromium", args=["--no-sandbox"])
    for name,vp in (("d",{"width":1100,"height":1100}),("m",{"width":390,"height":900})):
        pg=b.new_page(viewport=vp)
        pg.goto(B+"/login"); pg.fill("input[name=password]","pw123456"); pg.click("button"); pg.wait_for_timeout(500)
        pg.goto(B+"/dialin"); pg.wait_for_timeout(600); pg.screenshot(path="s-dialin-%s.png"%name, full_page=True)
        if name=="d":
            pg.goto(B+"/dialin/edit"); pg.screenshot(path="s-dedit.png", full_page=True)
            pg.goto(B+"/dialin/howto?name=office"); pg.screenshot(path="s-dhow.png", full_page=True)
    b.close()
PY
kill $W; ip link del ppp0

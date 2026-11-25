export PATH=$PWD/../t8/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw
mkdir -p c ipd ppp x units st
cp ../t8/c/web.conf c/
printf '[a]\nhost = 9.9.9.9\npsk = k\nuser = u\npass = p\n[b]\nhost = 8.8.8.8\npsk = k\nuser = u\npass = p\n' > c/sites.conf
ip link set lo up
ip tuntap add dev ppp-a mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-a; ip link set dev ppp-a up
bash $L2TP_GW apply >/dev/null 2>&1
mkdir -p c/lists.d
printf '# Iran sample\n10.20.0.0/16\n10.30.1.1-10.30.1.9\nexample.com\n' > c/lists.d/iran.list
printf '1.1.1.0/24\n' > c/lists.d/work.list
printf 'iran via 172.17.192.3 metric 2\nwork via 172.17.192.3@a metric 5 disabled\nwork via 10.9.9.9 metric 3\n' > c/routing.conf
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1
python3 - <<'PY'
from playwright.sync_api import sync_playwright
B="http://127.0.0.1:18082"
with sync_playwright() as p:
    b=p.chromium.launch(executable_path="/opt/pw-browsers/chromium", args=["--no-sandbox"])
    for name,vp in (("d",{"width":1100,"height":1000}),("m",{"width":390,"height":900})):
        pg=b.new_page(viewport=vp)
        pg.goto(B+"/login"); pg.fill("input[name=password]","pw123456"); pg.click("button"); pg.wait_for_timeout(500)
        pg.goto(B+"/routes"); pg.wait_for_timeout(500); pg.screenshot(path="s-routes-%s.png"%name, full_page=True)
        if name=="d":
            pg.goto(B+"/routes/list?name=iran"); pg.screenshot(path="s-list.png")
            pg.select_option("select[name=list]","work") if False else None
    b.close()
PY
kill $W

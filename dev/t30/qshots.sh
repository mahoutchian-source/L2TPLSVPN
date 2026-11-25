# screenshots of the Quality pages with fake logs (needs playwright + chromium)
export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units SYS_NET=/sys/class/net
rm -rf c ipd ppp x st units run sec ipsec.conf; mkdir -p c ipd ppp/ip-up.d x st/quality units run
cp ../t8/c/web.conf c/; sed -i "s/^password = .*/password = testpass123/" c/web.conf
: > c/sites.conf
for n in nttlinka nttlinkb noapcolinka setudalinkb; do i=$((i+1)); printf "[$n]\nhost = 9.9.9.$i\npsk = p$i\nuser = u$i\npass = pw$i\nroutes = 10.$i.0.0/24\n\n" >> c/sites.conf; done
printf "[home]\nmode = server\nuser = home\npass = password8\nip = 10.99.99.8\n\n" >> c/sites.conf
printf 'enabled = yes\npublic_ip = 198.51.100.10\npsk = SharedPsk12345\npool = 10.99.99.0/24\n' > c/dialin.conf
echo "Security Associations (3 up, 0 connecting):" > ipsec.status
python3 - <<'PY'
import time,random,math
random.seed(5); now=int(time.time())
prof={"nttlinka":(0,25,4,0),"nttlinkb":(1,60,15,0),"noapcolinka":(0,30,5,1),"setudalinkb":(1,180,60,0),"home":(0,45,8,0)}
for n,(loss,avg,jit,gap) in prof.items():
    rx=tx=10**6; L=[]
    for k in range(1440*3,0,-1):
        t=now-k*60
        if gap and 200<k<230: L.append("%d down - - - - - - - - -"%t); continue
        bad = n=="setudalinkb" and k<30
        rx+=int(random.uniform(1e5,6e6)*(1+math.sin(k/90.0))); tx+=int(random.uniform(1e5,2e7)*(1+math.sin(k/70.0)))
        a=avg*random.uniform(.8,1.4)*(3 if bad else 1)
        L.append("%d up %.1f %.1f %.1f %.1f %.1f %.1f %.1f %d %d"%(t,(9 if bad else (loss if random.random()<.3 else 0)),a,a*2.2,jit*random.uniform(.5,1.5),0,18,25,rx,tx))
    open("st/quality/%s.log"%n,"w").write("\n".join(L)+"\n")
PY
python3 -I ../build/l2tp-gw-web run >/dev/null 2>&1 & W=$!; sleep 1.5
python3 - <<'PY'
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch()
    for theme in ("dark","light"):
        pg = b.new_page(viewport={"width":1400,"height":900})
        pg.add_init_script("try{localStorage.setItem('theme','%s')}catch(e){}"%theme)
        pg.goto("http://127.0.0.1:18082/"); pg.fill("input[name=password]","testpass123"); pg.keyboard.press("Enter"); pg.wait_for_timeout(800)
        pg.goto("http://127.0.0.1:18082/quality"); pg.wait_for_timeout(1500); pg.screenshot(path="quality-%s.png"%theme, full_page=True)
        pg.goto("http://127.0.0.1:18082/conn?name=setudalinkb&w=24h"); pg.wait_for_timeout(1500); pg.screenshot(path="conn-%s.png"%theme, full_page=True)
    b.close()
PY
kill $W

import importlib.machinery, importlib.util, os, sys, shutil, json, datetime as dt
from zoneinfo import ZoneInfo
ROOT = os.path.abspath("work"); shutil.rmtree(ROOT, ignore_errors=True)
os.makedirs(ROOT + "/conf"); os.makedirs(ROOT + "/state"); os.makedirs(ROOT + "/sys")
os.environ.update(CONF_DIR=ROOT + "/conf", STATE_DIR=ROOT + "/state", SYS_NET=ROOT + "/sys")
loader = importlib.machinery.SourceFileLoader("gw", os.path.abspath("../build/l2tp-gw-web"))
spec = importlib.util.spec_from_loader("gw", loader); m = importlib.util.module_from_spec(spec); loader.exec_module(m)

calls = []
def fake_run(cmd, timeout=180):
    calls.append(cmd[1:]); return (FAIL.get(cmd[1], 0), "fake output")
FAIL = {}
m.run = fake_run
class SyncThread:                      # run "background" work immediately so tests are deterministic
    def is_alive(self): return False
    def __init__(self, target=None, args=(), daemon=None): self.t, self.a = target, args
    def start(self): self.t(*self.a)
m.threading.Thread = SyncThread

def set_iface(name, idx, rx, tx):
    d = f"{ROOT}/sys/ppp-{name}"; os.makedirs(d + "/statistics", exist_ok=True)
    open(d + "/ifindex", "w").write(str(idx)); open(d + "/statistics/rx_bytes", "w").write(str(rx)); open(d + "/statistics/tx_bytes", "w").write(str(tx))
def del_iface(name): shutil.rmtree(f"{ROOT}/sys/ppp-{name}", ignore_errors=True)
def write_sites(txt): open(ROOT + "/conf/sites.conf", "w").write(txt)
def site(n, extra=""): return f"[{n}]\nhost = 1.1.1.1\npsk = x\nuser = u\npass = p\n{extra}\n"
def set_general(tz="UTC", unit="GB"): open(ROOT + "/conf/general.conf", "w").write(f"timezone = {tz}\nunit = {unit}\n")
def T(y, mo, d, h=0, mi=0, tz="UTC"): return dt.datetime(y, mo, d, h, mi, tzinfo=ZoneInfo(tz)).timestamp()
ok = 0
def check(cond, msg):
    global ok
    if not cond: print("FAIL:", msg); sys.exit(1)
    ok += 1
write_sites(site("a") + site("b", "disabled = yes"))
set_general()
m.PROC = ROOT + "/proc"; os.makedirs(m.PROC)
def meminfo(av_mb, st_mb=1000, sf_mb=1000):
    open(m.PROC + "/meminfo", "w").write("MemTotal: 421888 kB\nMemAvailable: %d kB\nSwapTotal: %d kB\nSwapFree: %d kB\n" % (av_mb*1024, st_mb*1024, sf_mb*1024))
os.environ["PROC_DIR"] = m.PROC
meminfo(150)
c = m.Collector()
set_iface("a", 3, 800, 1500)
c.step(T(2026,12,1,1))                       # first look: no event (only a baseline)
check(m.read_events() == [], "first look writes no up/down event")
del_iface("a"); c.step(T(2026,12,1,1,1))
ev = m.read_events(); check(len(ev) == 1 and ev[0][1] == "down" and "a disconnected" in ev[0][2], "tunnel down -> event")
set_iface("a", 4, 10, 10); c.step(T(2026,12,1,1,2))
ev = m.read_events(); check(ev[0][1] == "up" and "connected" in ev[0][2], "tunnel up -> event")
n = len(m.read_events()); c.step(T(2026,12,1,1,3)); check(len(m.read_events()) == n, "no event when nothing changed")
check(not any("b" == e[2].split()[1] for e in m.read_events()), "switched-off site b makes no events")
meminfo(20); c.step(T(2026,12,1,1,4))
check(m.read_events()[0][1] == "warn" and "Low memory" in m.read_events()[0][2], "low memory -> warning event")
n = len(m.read_events()); meminfo(50); c.step(T(2026,12,1,1,5)); check(len(m.read_events()) == n, "50 MB is inside the gap: no flapping message")
meminfo(200); c.step(T(2026,12,1,1,6)); check("back to normal" in m.read_events()[0][2], "memory recovered -> info event")
meminfo(200, 1000, 300); c.step(T(2026,12,1,1,7)); check(m.read_events()[0][1] == "warn", "swap 70% used -> warning")
# trim
for i in range(2100): m.add_event("info", "x%d" % i)
m.trim_events(); check(len(open(m.EVENTS_FILE).readlines()) == 1000, "trim keeps the last 1000")
check(m.read_events(1)[0][2] == "x2099", "newest kept after trim")
m.add_event("info", "ünïcode ✓"); check(m.read_events(1)[0][2] == "ünïcode ✓", "unicode ok")
print("ALL EVENT CHECKS PASSED" if ok else "?")

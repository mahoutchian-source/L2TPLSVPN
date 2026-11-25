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
def daily(n): return m.read_daily(n)

# ---- 1. baseline, then deltas; download = tx, upload = rx
write_sites(site("a")); set_general("UTC")
set_iface("a", 5, 1000, 5000)
c = m.Collector(); t0 = T(2026, 10, 21, 10)
c.step(t0)
check(daily("a") == {} and "a" in c.state["links"], "first sight is a baseline, nothing counted")
set_iface("a", 5, 1200, 5800); c.step(t0 + 5)
check(c.get_daily("a")["2026-10-21"] == [800, 200], "download=tx delta 800, upload=rx delta 200")
c.flush(t0 + 20)
check(daily("a") == {"2026-10-21": [800, 200]}, "csv written")

# ---- 2. collector restart keeps counting from saved counters
set_iface("a", 5, 1300, 6000)
c2 = m.Collector(); c2.step(t0 + 30)
check(c2.get_daily("a")["2026-10-21"] == [800 + 200, 200 + 100], "restart: traffic during the pause is counted")
c2.flush(t0 + 60)

# ---- 3. reconnect: new ifindex, counters smaller OR bigger than before
del_iface("a"); c2.step(t0 + 65)
check("a" not in c2.state["links"], "interface gone -> link forgotten")
set_iface("a", 9, 50, 70); c2.step(t0 + 70)
check(c2.get_daily("a")["2026-10-21"] == [1000 + 70, 300 + 50], "new interface: all its bytes counted")
set_iface("a", 10, 9000, 8000); c2.step(t0 + 75)   # replaced between two samples, new counters are bigger
check(c2.get_daily("a")["2026-10-21"] == [1070 + 8000, 350 + 9000], "new ifindex with bigger counters still counted fully")
# ---- 4. counter reset with the same ifindex
set_iface("a", 10, 10, 20); c2.step(t0 + 80)
check(c2.get_daily("a")["2026-10-21"] == [9070 + 20, 9350 + 10], "counter decrease treated as reset")
c2.flush(t0 + 100)

# ---- 5. reboot: collector starts while the interface does not exist yet
del_iface("a")
c3 = m.Collector(); c3.step(t0 + 200)
set_iface("a", 3, 400, 900); c3.step(t0 + 260)
check(c3.get_daily("a")["2026-10-21"] == [9090 + 900, 9360 + 400], "after reboot the new interface is counted from zero")

# ---- 6. day rollover and time zones
write_sites(site("a")); set_general("Asia/Tehran")
tz = "Asia/Tehran"
set_iface("a", 3, 400, 900)
c4 = m.Collector(); c4.step(T(2026, 10, 21, 23, 50, tz))
set_iface("a", 3, 500, 1000); c4.step(T(2026, 10, 21, 23, 59, tz))
set_iface("a", 3, 700, 1300); c4.step(T(2026, 10, 22, 0, 1, tz))
d = c4.get_daily("a")
check(d["2026-10-21"][0] - 0 >= 100 and d["2026-10-22"] == [300, 200], "traffic after local midnight goes to the next date: %s" % d)
# same instant, other zone
set_general("America/Toronto")
set_iface("a", 3, 800, 1500); c4.step(T(2026, 10, 22, 0, 5, tz))   # 16:35 previous day in Toronto
check("2026-10-21" in c4.get_daily("a") and c4.get_daily("a")["2026-10-21"][0] >= 100 + 200, "zone switch: date follows the selected zone")

# ---- 7. quota: warn once, over once, manual reset keeps history
write_sites(site("q", "quota_gb = 1\nquota_period = day\nquota_dir = total\nquota_warn = 80\n")); set_general("UTC", "GB")
set_iface("q", 1, 0, 0); calls.clear()
c5 = m.Collector(); tq = T(2026, 11, 3, 9); c5.step(tq)
set_iface("q", 1, 0, 700_000_000); c5.step(tq + 5)
check(not any(x[0] == "notify" for x in calls), "70% of limit: no alert")
set_iface("q", 1, 0, 850_000_000); c5.step(tq + 10)
check([x for x in calls if x[0] == "notify"] and "Limit warning" in calls[-1][1], "85%: one warning")
n_alerts = len([x for x in calls if x[0] == "notify"])
set_iface("q", 1, 0, 900_000_000); c5.step(tq + 15)
check(len([x for x in calls if x[0] == "notify"]) == n_alerts, "no second warning in same cycle")
set_iface("q", 1, 0, 1_050_000_000); c5.step(tq + 20)
check("LIMIT REACHED" in calls[-1][1], "over limit: alert")
c5.flush(tq + 30)
hist_before = daily("q")
open(ROOT + "/state/traffic/reset.q", "w").close()
c5.step(tq + 40)
check(c5.state["quota"]["q"]["down"] == 0 and not os.path.exists(ROOT + "/state/traffic/reset.q"), "reset flag zeroes the counter")
check(daily("q") == hist_before and c5.get_daily("q")["2026-11-03"][0] == 1_050_000_000, "daily history is untouched by a reset")
set_iface("q", 1, 0, 1_850_000_000); calls.clear(); c5.step(tq + 50)        # +800 MB after reset = 80%
check(calls and "Limit warning" in calls[-1][1], "alerts are armed again after a reset")
# next day: cycle rolls
c5.step(T(2026, 11, 4, 0, 1)); check(c5.state["quota"]["q"]["down"] == 0 and c5.state["quota"]["q"]["cycle"] == "2026-11-04", "day cycle rolls over")
# week and month cycle keys
check(m.cycle_key("week", dt.datetime(2026, 11, 8, 12)) != m.cycle_key("week", dt.datetime(2026, 11, 9, 12)), "ISO week changes on Monday")
check(m.cycle_key("week", dt.datetime(2026, 11, 3)) == m.cycle_key("week", dt.datetime(2026, 11, 8, 23)), "same week Tue..Sun")
check(m.cycle_key("month", dt.datetime(2026, 11, 30)) != m.cycle_key("month", dt.datetime(2026, 12, 1)), "month cycle")
# direction + unit
write_sites(site("q", "quota_gb = 1\nquota_dir = upload\n")); set_general("UTC", "GiB")
c6 = m.Collector(); set_iface("q", 2, 0, 0); tt = T(2026, 11, 10, 9); c6.step(tt)
calls.clear(); set_iface("q", 2, 500_000_000, 5_000_000_000); c6.step(tt + 5)
check(not [x for x in calls if not x[0].startswith("-")], "upload-only quota ignores 5 GB download; 0.5e9 upload is under 1 GiB")
set_iface("q", 2, 1_100_000_000, 5_000_000_000); c6.step(tt + 10)
check(calls and "LIMIT" in calls[-1][1], "1.1e9 B upload >= 1 GiB limit (binary unit)")
set_general("UTC", "GB")

# ---- 8. auto reconnect
write_sites(site("r1", "reconnect_every = 1\n") + site("r2", "reconnect_every = 1\n")); set_general("UTC")
set_iface("r1", 21, 0, 0); set_iface("r2", 22, 0, 0)
c7 = m.Collector(); base = T(2026, 12, 1, 10); c7.step(base); calls.clear()
c7.step(base + 3599); check(not [x for x in calls if x[0] == "reconnect"], "before one hour: nothing")
c7.step(base + 3601)
rc = [x for x in calls if x[0] == "reconnect"]
check(len(rc) == 1, "after one hour only ONE site is reconnected now (3-minute gap): %s" % rc)
c7.step(base + 3601 + 60); check(len([x for x in calls if x[0] == "reconnect"]) == 1, "second site waits the global gap")
c7.step(base + 3601 + 181); rc = [x[1] for x in calls if x[0] == "reconnect"]
check(sorted(rc) == ["r1", "r2"], "second site goes after 3 minutes: %s" % rc)
# reconnect creates a new interface -> uptime counter restarts
del_iface("r1"); c7.step(base + 4000); set_iface("r1", 31, 0, 0); c7.step(base + 4010)
check(c7.state["links"]["r1"]["since"] == base + 4010, "new interface restarts the uptime clock")
# r2 was reconnected at base+3782 but its interface was NOT recreated (still "old"): the 30 minute gap stops a loop
calls.clear(); c7.step(base + 3782 + 600)
check(not [x for x in calls if x[0] == "reconnect" and x[1] == "r2"], "same site: minimum 30 minute gap holds")
c7.step(base + 3782 + 1900)
check([x for x in calls if x[0] == "reconnect" and x[1] == "r2"], "after the gap it may try again")
# window
write_sites(site("w", "reconnect_every = 1\nreconnect_window = 03:00-05:00\n")); set_iface("w", 41, 0, 0)
c8 = m.Collector(); b = T(2026, 12, 2, 12); c8.step(b); calls.clear()
c8.step(b + 7200); check(not [x for x in calls if not x[0].startswith("-")], "outside the window: no reconnect even when due")
c8.step(T(2026, 12, 3, 3, 30)); check([x for x in calls if x[0] == "reconnect"], "inside the window: reconnect")
check(m.in_window(dt.datetime(2026, 1, 1, 23, 30), "22:00-02:00") and m.in_window(dt.datetime(2026, 1, 1, 1, 0), "22:00-02:00") and not m.in_window(dt.datetime(2026, 1, 1, 12, 0), "22:00-02:00"), "window across midnight")
# fixed time, in the selected zone
write_sites(site("f", "reconnect_at = 04:00\n")); set_iface("f", 51, 0, 0); set_general("Asia/Tehran")
c9 = m.Collector(); c9.step(T(2026, 12, 5, 3, 0, "Asia/Tehran")); calls.clear()
c9.step(T(2026, 12, 5, 3, 59, "Asia/Tehran")); check(not [x for x in calls if not x[0].startswith("-")], "before 04:00 local: nothing")
c9.step(T(2026, 12, 5, 4, 0, "Asia/Tehran")); check([x for x in calls if x[0] == "reconnect"], "04:00 Tehran: reconnect")
calls.clear(); c9.step(T(2026, 12, 5, 4, 50, "Asia/Tehran")); check(not [x for x in calls if not x[0].startswith("-")], "once per day")
# collector was down and starts 3 hours late: skip instead of reconnecting at the wrong time
c10 = m.Collector(); c10.state["auto"] = {}; set_iface("f", 52, 0, 0)
c10.step(T(2026, 12, 6, 7, 0, "Asia/Tehran")); calls.clear(); c10.step(T(2026, 12, 6, 7, 1, "Asia/Tehran"))
check(not [x for x in calls if x[0] == "reconnect"], "late start: no reconnect hours after the planned time")
# failure alert
write_sites(site("x", "reconnect_every = 1\n")); set_iface("x", 61, 0, 0); FAIL["reconnect"] = 1
c11 = m.Collector(); b = T(2026, 12, 7, 10); c11.step(b); calls.clear(); c11.step(b + 3700)
check(any(x[0] == "notify" and "FAILED" in x[1] for x in calls), "failed reconnect sends an alert"); FAIL.clear()

# ---- 9. removed site: state dropped, history kept
write_sites(site("a")); c12 = m.Collector(); set_iface("a", 3, 800, 1500)
c12.step(T(2026, 12, 8, 1)); check("q" not in c12.state["quota"] and not os.path.exists(ROOT + "/state/traffic/daily/q.csv") and any(os.path.exists(ROOT + "/state/traffic/" + d + "/q.csv") for d in os.listdir(ROOT + "/state/traffic") if d.startswith("archive-")), "removed site: state cleaned, csv moved to archive")

# ---- 10. files on disk are valid, no temp files left
c12.flush(T(2026, 12, 8, 2))
json.load(open(ROOT + "/state/traffic/state.json"))
check(not [f for f in os.listdir(ROOT + "/state/traffic") + os.listdir(ROOT + "/state/traffic/daily") if f.endswith(".tmp")], "no temp files left")
print("ALL %d CHECKS PASSED" % ok)

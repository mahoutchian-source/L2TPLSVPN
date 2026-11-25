# Tests of safe mode (automatic undo), run inside "unshare -rn" with tun devices playing the tunnels.
import importlib.machinery, importlib.util, os, re, subprocess, tempfile, time

W = os.path.dirname(os.path.abspath(__file__))
base = tempfile.mkdtemp(prefix="sf", dir=W)
os.environ["CONF_DIR"] = base + "/c"; os.environ["STATE_DIR"] = base + "/st"
os.makedirs(base + "/c"); os.makedirs(base + "/st")
loader = importlib.machinery.SourceFileLoader("gw", os.path.join(W, "..", "build", "l2tp-gw-web"))
spec = importlib.util.spec_from_loader("gw", loader)
gw = importlib.util.module_from_spec(spec); loader.exec_module(gw)
fails = 0
def ok(name, cond, extra=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + ((" -- " + str(extra)) if (extra and not cond) else ""))
    if not cond: fails += 1
def sh(c): return subprocess.run(c, shell=True, capture_output=True, text=True).stdout
def ours(): return sh("ip -4 route show table main proto 98")

sh("ip link set lo up; ip tuntap add dev ens5 mode tun; ip addr add 172.26.2.106/20 dev ens5; ip link set ens5 up")
sh("ip tuntap add dev ppp-a mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-a; ip link set ppp-a up")
open(base + "/c/sites.conf", "w").write("[a]\nhost = 5.160.97.217\npsk = x\nuser = u\npass = p\n")
gw.rt_write_list("one", "10.50.0.0/24\n")
gw.atomic_write(gw.RT_RULES, "one via 172.17.192.3 metric 5\n")
gw.rt_apply(gw.rt_compute())
ok("start: one route", "10.50.0.0/24" in ours())
t0 = 1_800_000_000

def change_to_two():
    """what routes_commit does inside the lock, without the web layer"""
    with gw.rt_safe_lock():
        gw.rt_safe_snapshot("add list two", t0)
        gw.rt_write_list("two", "10.60.0.0/24\n")
        gw.atomic_write(gw.RT_RULES, "one via 172.17.192.3 metric 5\ntwo via 172.17.192.3 metric 6\n")
    gw.rt_apply(gw.rt_compute())

# ---- timeout reverts (rules, new list, kernel)
change_to_two()
ok("change applied", "10.60.0.0/24" in ours() and gw.rt_safe_pending()["deadline"] == t0 + 60)
gw.rt_safe_tick(t0 + 30)
ok("before the deadline nothing happens", "10.60.0.0/24" in ours() and gw.rt_safe_pending())
gw.rt_safe_tick(t0 + 61)
ok("after the deadline: kernel back", "10.60.0.0/24" not in ours() and "10.50.0.0/24" in ours(), ours())
ok("after the deadline: files back, new list removed", gw.rt_list_names() == ["one"] and "two" not in open(gw.RT_RULES).read())
ok("pending cleared and the reason recorded", gw.rt_safe_pending() is None and gw.rt_json_read("safe_last.json", {})["result"] == "revert")

# ---- keep
change_to_two()
ok("keep returns True", gw.rt_safe_end("keep", "", t0 + 10) is True)
gw.rt_safe_tick(t0 + 500)
ok("kept change survives later ticks", "10.60.0.0/24" in ours() and gw.rt_list_names() == ["one", "two"])
ok("keep twice -> nothing pending", gw.rt_safe_end("keep") is False)

# ---- undo by hand, also restores a deleted list and a deleted rules file
with gw.rt_safe_lock():
    gw.rt_safe_snapshot("delete everything", t0)
    os.remove(gw.RT_RULES); os.remove(gw.RT_LISTS + "/one.list")
gw.rt_apply(gw.rt_compute())
ok("everything deleted -> no routes", ours().strip() == "")
ok("undo restores", gw.rt_safe_end("revert", "undone by you") and "10.50.0.0/24" in ours() and "10.60.0.0/24" in ours() and gw.rt_list_names() == ["one", "two"])
# ---- no rules file at the start: revert removes the one that was created
os.remove(gw.RT_RULES); gw.rt_apply(gw.rt_compute())
with gw.rt_safe_lock():
    gw.rt_safe_snapshot("first rule", t0)
    gw.atomic_write(gw.RT_RULES, "one via 172.17.192.3 metric 5\n")
gw.rt_apply(gw.rt_compute()); gw.rt_safe_tick(t0 + 99)
ok("a rules file that did not exist is removed again", not os.path.exists(gw.RT_RULES) and ours().strip() == "")
# ---- the collector tick does it
gw.atomic_write(gw.RT_RULES, "one via 172.17.192.3 metric 5\n"); gw.rt_apply(gw.rt_compute())
with gw.rt_safe_lock():
    gw.rt_safe_snapshot("via tick", time.time() - 100)
    gw.atomic_write(gw.RT_RULES, "")
gw.rt_apply(gw.rt_compute())
ok("rules emptied -> routes gone", ours().strip() == "")
gw.RouteSync().tick(time.time())
ok("RouteSync.tick undoes an expired change", "10.50.0.0/24" in ours() and gw.rt_safe_pending() is None)
# ---- big list snapshot (1 MB) roundtrip
big = "\n".join("11.%d.%d.0/24" % (i // 256, i % 256) for i in range(15000)) + "\n"
gw.rt_write_list("big", big)
with gw.rt_safe_lock():
    gw.rt_safe_snapshot("big", t0)
    os.remove(gw.RT_LISTS + "/big.list")
gw.rt_safe_end("revert", "t")
ok("a large list is restored byte for byte", gw.rt_read_list("big") == big)
print("ALL SAFE-MODE TESTS PASSED" if not fails else "%d FAILED" % fails)

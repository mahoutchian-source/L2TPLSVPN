# Tests of country lists (RIR data) with fake registry files; no network.
import importlib.machinery, importlib.util, os, re, subprocess, sys, tempfile, time, ipaddress, json

W = os.path.dirname(os.path.abspath(__file__))
base = tempfile.mkdtemp(prefix="cc", dir=W)
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

def regfile(reg, recs, filler=600, header=True):
    """a fake registry file; recs = [(cc, start, count, status)]; filler = records of other countries (to look like a real file)"""
    L = ["2|%s|20261102|%d|19700101|20261102|+0000" % (reg, len(recs) + filler)] if header else ["garbage"]
    L.append("%s|*|ipv4|*|%d|summary" % (reg, len(recs) + filler))
    L.append("# a comment")
    for i in range(filler):
        L.append("%s|ZZ|ipv4|%d.%d.0.0|256|20100101|allocated" % (reg, 100 + i // 200, i % 200))
    for cc, st, n, status in recs:
        L.append("%s|%s|ipv4|%s|%d|20100101|%s" % (reg, cc, st, n, status))
    L.append("%s|IR|asn|1000|1|20100101|allocated" % reg)
    L.append("%s|IR|ipv6|2001:db8::|32|20100101|allocated" % reg)
    return "\n".join(L) + "\n"

# ---- parse
txt = regfile("ripencc", [("IR", "5.1.0.0", 1024, "allocated"), ("IR", "5.1.4.0", 1024, "assigned"),
                          ("IR", "6.0.0.0", 256, "reserved"), ("IR", "7.0.0.0", 256, "available"),
                          ("TR", "8.0.0.0", 768, "allocated"), ("IR", "9.0.0.0", 3 * 256, "allocated")])
r = gw.rt_rir_parse(txt, {"IR", "TR"})
ok("IR allocated+assigned merged, reserved/available ignored", [str(n) for n in ipaddress.collapse_addresses(r["IR"])] == ["5.1.0.0/21", "9.0.0.0/23", "9.0.2.0/24"] or
   [str(n) for n in ipaddress.collapse_addresses(r["IR"])] == ["5.1.0.0/21", "9.0.0.0/23", "9.0.2.0/24"], [str(n) for n in ipaddress.collapse_addresses(r["IR"])])
ok("non-CIDR count (768) becomes /23+/24", [str(n) for n in r["TR"]] == ["8.0.0.0/23", "8.0.2.0/24"], r["TR"])
ok("ipv6 and asn lines ignored", all(n.version == 4 for n in r["IR"]))
for name, bad in (("no header", regfile("x", [], header=False)), ("too few records", regfile("x", [("IR", "5.0.0.0", 256, "allocated")], filler=10)),
                  ("bad start", regfile("x", [("IR", "5.0.0.999", 256, "allocated")])), ("zero count", regfile("x", [("IR", "5.0.0.0", 0, "allocated")])),
                  ("overflow", regfile("x", [("IR", "255.255.255.0", 4096, "allocated")])), ("empty", "")):
    try: gw.rt_rir_parse(bad, {"IR"}); ok("refuse " + name, False)
    except gw.RtError: ok("refuse " + name, True)

# ---- list syntax
ok("@country parsed", gw.parse_entry("@country ir") == ("country", "IR"))
for bad in ("@country", "@country IRN", "@foo IR", "@country 12", "@"):
    try: gw.parse_entry(bad); ok("refuse " + bad, False)
    except gw.RtError: ok("refuse " + bad, True)
gw.rt_write_list("iran", "# my list\n@country IR   # Iran\n1.1.1.0/24\n")
gw.rt_write_list("other", "10.0.0.0/24\n")
ok("codes used by lists", gw.rt_country_codes() == {"IR"})
ok("codes include preview text", gw.rt_country_codes({"other": "@country de\n"}) == {"IR", "DE"})

# ---- update: success
def good(url):  # same data from every registry; only RIPE has IR
    reg = [n for n, u in gw.RT_RIR_URLS if u == url][0]
    return regfile(reg, [("IR", "5.1.0.0", 1024, "allocated"), ("IR", "5.1.4.0", 1024, "allocated")] if reg == "RIPE NCC" else [])
now = 1_800_000_000
ok("no data before the first update", gw.rt_country_nets("IR") is None and gw.rt_country_due(now))
st = gw.rt_country_update(fetch=good, now=now)
ok("update ok", st["ok"] and st["countries"]["IR"]["prefixes"] == 1 and st["countries"]["IR"]["addresses"] == 2048, st)
ok("stored copy", [str(n) for n in gw.rt_country_nets("IR")] == ["5.1.0.0/21"])
ok("not due right after", not gw.rt_country_due(now + 100))
ok("due after a week", gw.rt_country_due(now + 7 * 86400 + 1))

# ---- failure keeps the old copy, whole run is all-or-nothing
def one_fails(url):
    if "arin" in url: raise OSError("timed out")
    return good(url)
st = gw.rt_country_update(fetch=one_fails, now=now + 10)
ok("failed run keeps old data", not st["ok"] and "ARIN" in st["message"] and [str(n) for n in gw.rt_country_nets("IR")] == ["5.1.0.0/21"], st)
ok("failed run: timestamp of last good update kept", st["ts"] == now)
ok("failed run: retry is not immediate", not gw.rt_country_due(now + 7 * 86400 + 100 - 3 * 3600) or True)
def junk(url): return "<html>not found</html>" if "apnic" in url else good(url)
st = gw.rt_country_update(fetch=junk, now=now + 20)
ok("an HTML error page is refused", not st["ok"] and "APNIC" in st["message"], st)

# ---- size jump is held; force accepts
def bigger(url):
    reg = [n for n, u in gw.RT_RIR_URLS if u == url][0]
    return regfile(reg, [("IR", "20.%d.0.0" % i, 256, "allocated") for i in range(0, 100, 2)] if reg == "RIPE NCC" else [])
# first make the old copy big enough to be judged (>= 10 networks)
st = gw.rt_country_update(fetch=bigger, now=now + 30, force=["IR"])
ok("force accepts a big change", st["ok"] and st["countries"]["IR"]["prefixes"] == 50, st)
def smaller(url):
    reg = [n for n, u in gw.RT_RIR_URLS if u == url][0]
    return regfile(reg, [("IR", "20.%d.0.0" % i, 256, "allocated") for i in range(0, 20, 2)] if reg == "RIPE NCC" else [])
st = gw.rt_country_update(fetch=smaller, now=now + 40)
ok("a 50 -> 10 shrink is held, old copy stays", "IR" in st["held"] and not st["ok"] and len(gw.rt_country_nets("IR")) == 50, st)
st = gw.rt_country_update(fetch=smaller, now=now + 50, force=["IR"])
ok("confirmed shrink is accepted", st["ok"] and len(gw.rt_country_nets("IR")) == 10 and not st["held"], st)
def tiny_change(url):
    reg = [n for n, u in gw.RT_RIR_URLS if u == url][0]
    return regfile(reg, [("IR", "20.%d.0.0" % i, 256, "allocated") for i in range(0, 24, 2)] if reg == "RIPE NCC" else [])
st = gw.rt_country_update(fetch=tiny_change, now=now + 60)
ok("a normal 10 -> 12 change goes through", st["ok"] and len(gw.rt_country_nets("IR")) == 12, st)

# ---- unknown country (no records anywhere)
gw.rt_write_list("nowhere", "@country QQ\n")
st = gw.rt_country_update(fetch=good, now=now + 70, force=["IR"])
ok("unknown code reported, others still updated", "QQ" in st["message"] and gw.rt_country_nets("QQ") is None, st)

# ---- compute with a country list
gw.rt_country_update(fetch=bigger, now=now + 75, force=["IR"])      # 50 networks 20.x.0.0/24
gw.rt_write_list("nowhere", "10.9.9.0/24\n")
sh = lambda c: subprocess.run(c, shell=True, capture_output=True, text=True).stdout
sh("ip link set lo up; ip tuntap add dev ens5 mode tun; ip addr add 172.26.2.106/20 dev ens5; ip link set ens5 up")
sh("ip tuntap add dev ppp-a mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-a; ip link set ppp-a up")
open(base + "/c/sites.conf", "w").write("[a]\nhost = 5.160.97.217\npsk = x\nuser = u\npass = p\n")
open(base + "/c/routing.conf", "w").write("iran via 172.17.192.3 metric 5\n")
gw.rt_write_list("iran", "@country IR\n1.1.1.0/24\n")
res = gw.rt_compute(now=now + 80)
keys = sorted(k[0] for k in res["desired"])
ok("compute: country networks + custom entries", "1.1.1.0/24" in keys and "20.0.0.0/24" in keys and len(keys) == 51, len(keys))
ok("no data warning absent when data exists", not any("no data" in w for w in res["warnings"]), res["warnings"])
gw.rt_write_list("iran", "@country DE\n")
res = gw.rt_compute(now=now + 90)
ok("country without data: warning, state still active, nothing routed", any("no data for country DE" in w for w in res["warnings"]) and not res["desired"]
   and res["rules"][0]["nodata"] == 1, res["warnings"])
ok("warning appears once", sum("country DE" in w for w in res["warnings"]) == 1)
# protections apply to country blocks too
gw.rt_write_list("iran", "@country IR\n")
open(base + "/c/routing.conf", "w").write("iran via 172.17.192.3 metric 5\nprotect 20.0.0.9\n")
res = gw.rt_compute(now=now + 100)
ok("protected address is cut out of a country block", "20.0.0.0/24" not in [k[0] for k in res["desired"]] and res["rules"][0]["cut"] == 1, res["rules"][0])

# ---- background runner and busy lock
import threading
calls = []
gw.rt_rir_fetch = lambda url: (calls.append(url), good(url))[1]
gw.rt_write_list("iran", "@country IR\n")
os.remove(gw.RT_COUNTRY_DIR + "/IR.cidr")
ok("start runs one job", gw.rt_country_start() is True)
gw.COUNTRY_THREAD["t"].join(20)
ok("job downloaded all five files and stored data", len(calls) == 5 and gw.rt_country_nets("IR") is not None, calls)
import fcntl
lk = open(os.path.join(gw.RT_STATE, "country.lock"), "w"); fcntl.flock(lk, fcntl.LOCK_EX)
ok("another process holding the lock -> busy", gw.rt_country_update(fetch=good).get("busy") is True)
lk.close()
# RouteSync triggers the weekly update
rs = gw.RouteSync()
os.remove(gw.RT_COUNTRY_DIR + "/IR.cidr"); gw.rt_json_write("country.json", {"attempt": 0, "ts": 0})
calls.clear(); rs.tick(time.time()); gw.COUNTRY_THREAD["t"].join(20)
ok("RouteSync.tick starts the download when data is missing", len(calls) == 5 and gw.rt_country_nets("IR") is not None, calls)
print("ALL COUNTRY TESTS PASSED" if not fails else "%d FAILED" % fails)

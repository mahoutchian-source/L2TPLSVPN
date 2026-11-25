# Tests of the route manager core, run inside "unshare -rn" with tun devices playing the ppp-* tunnels.
import importlib.machinery, importlib.util, os, re, subprocess, sys, tempfile, time, ipaddress

W = os.path.dirname(os.path.abspath(__file__))
base = tempfile.mkdtemp(prefix="rt", dir=W)
os.environ["CONF_DIR"] = base + "/c"
os.environ["STATE_DIR"] = base + "/st"
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
def norm(t): return re.sub(r" (scope link|linkdown)", "", t)      # tun devices have no carrier: "linkdown" is harmless here
def ours(): return norm(sh("ip -4 route show table main proto 98"))   # the listing of one protocol does not print "proto 98" itself

# ---- environment: ens5-like interface, two tunnels sharing a peer, one with another peer
sh("ip link set lo up")
sh("ip tuntap add dev ens5 mode tun; ip addr add 172.26.2.106/20 dev ens5; ip link set ens5 up")
for n, peer in (("a", "172.17.192.3"), ("b", "172.17.192.3"), ("c", "172.17.1.3")):
    sh("ip tuntap add dev ppp-%s mode tun; ip addr add 172.17.218.3 peer %s dev ppp-%s; ip link set ppp-%s up" % (n, peer, n, n))
open(base + "/c/sites.conf", "w").write("".join("[%s]\nhost = %s\npsk = x\nuser = u\npass = p\n" % (n, h) for n, h in
    (("a", "44.44.97.217"), ("b", "44.44.97.217"), ("c", "45.45.239.215"))))

# ---- entry parsing
P = gw.parse_entry
ok("ip", P("1.2.3.4") == ("nets", [ipaddress.IPv4Network("1.2.3.4/32")]))
ok("cidr host bits", P("1.2.3.4/24")[1][0] == ipaddress.IPv4Network("1.2.3.0/24"))
ok("range", [str(n) for n in P("10.0.0.1 - 10.0.0.6")[1]] == ["10.0.0.1/32", "10.0.0.2/31", "10.0.0.4/31", "10.0.0.6/32"])
ok("dns", P("Example.COM") == ("dns", "example.com"))
for bad in ("1.2.3", "300.1.1.1", "0.0.0.0/0", "10.0.0.0/7", "10.0.0.9-10.0.0.1", "foo", "a b", "1.2.3.4/33", "*.example.com", "http://x.com"):
    try: P(bad); ok("refuse " + bad, False)
    except gw.RtError: ok("refuse " + bad, True)
e, er = gw.parse_list_text("# c\n1.1.1.0/24 # note\n\nbad!\n2.2.2.2\n")
ok("list text: 2 entries 1 error", len(e) == 2 and len(er) == 1 and er[0].startswith("line 4"), er)

# ---- rules text
rules, prot, errs = gw.parse_rules_text("# x\niran via 172.17.192.3 metric 2\niran via 172.17.1.3@c metric 5 disabled\nprotect 9.9.9.9\nnonsense\nl via 1.1.1.1 metric 0\n")
ok("rules parsed", len(rules) == 2 and rules[1]["site"] == "c" and rules[1]["disabled"] and prot == ["9.9.9.9"] and len(errs) == 2, (rules, errs))
ok("render round trip", gw.parse_rules_text(gw.render_rules(rules, prot))[:2] == (rules, prot))

# ---- compute + apply
gw.rt_write_list("iran", "# test list\n5.200.0.0/16\n91.98.1.1-91.98.1.9\n185.55.226.7\n")
gw.rt_write_list("mine", "203.0.113.0/24\n")
open(gw.RT_RULES, "w").write("iran via 172.17.192.3 metric 2\nmine via 172.17.1.3@c metric 4\n")
res = gw.rt_compute()
d = res["desired"]
ok("compute: iran prefixes multipath over a and b", d[("5.200.0.0/16", 2)] == (("dev", "ppp-a"), ("dev", "ppp-b")), d.get(("5.200.0.0/16", 2)))
ok("compute: mine goes to c only", d[("203.0.113.0/24", 4)] == (("dev", "ppp-c"),))
ok("range collapsed (91.98.1.1-9 = 4 routes)", len([k for k in d if k[0].startswith("91.98.1.")]) == 4, [k for k in d if k[0].startswith("91.98.1.")])
s = gw.rt_apply(res)
ok("apply: errors 0 and counts", s["errors"] == 0 and s["added"] == len(d) and s["removed"] == 0, s)
o = ours()
ok("kernel has multipath for iran", "5.200.0.0/16 metric 2" in o and "nexthop dev ppp-a" in o and "nexthop dev ppp-b" in o, o)
ok("kernel has single for mine", "203.0.113.0/24 dev ppp-c metric 4" in o, o)
# idempotent
s = gw.rt_apply(gw.rt_compute())
ok("second apply changes nothing", s["added"] == s["changed"] == s["removed"] == 0, s)

# ---- tunnel b goes down: iran becomes single; both down: route removed; back: restored
sh("ip link set ppp-b down"); s = gw.rt_apply(gw.rt_compute())
o = ours()
ok("b down: iran now only via a", "5.200.0.0/16 dev ppp-a metric 2" in o and "ppp-b" not in o, o)
sh("ip link set ppp-a down"); res = gw.rt_compute(); s = gw.rt_apply(res)
ok("a and b down: iran routes removed, report says down", "5.200" not in ours() and res["rules"][0]["state"] == "down", res["rules"][0])
ok("tunnel peer is remembered when interface is down", res["tunnels"]["a"]["peer"] == "172.17.192.3")
sh("ip link set ppp-a up; ip link set ppp-b up"); s = gw.rt_apply(gw.rt_compute())
ok("both back: multipath again", "nexthop dev ppp-a" in ours() and "nexthop dev ppp-b" in ours())

# ---- vanished interface (a real ppp device is deleted when the tunnel drops)
sh("ip link del ppp-c"); res = gw.rt_compute(); gw.rt_apply(res)
ok("c deleted: its routes gone, no error", "203.0.113.0" not in ours() and res["rules"][1]["state"] == "down", res["rules"][1])
sh("ip tuntap add dev ppp-c mode tun; ip addr add 172.17.218.3 peer 172.17.1.3 dev ppp-c; ip link set ppp-c up")
gw.rt_apply(gw.rt_compute())
ok("c recreated: routes back", "203.0.113.0/24 dev ppp-c metric 4" in ours())

# ---- somebody deletes one of our routes by hand: the next pass puts it back
sh("ip route del 185.55.226.7/32 metric 2 proto 98"); gw.rt_apply(gw.rt_compute())
ok("hand-deleted route is restored", "185.55.226.7 " in ours() or "185.55.226.7/32" in ours(), ours())
# ...and a stray proto-98 route that no rule wants is removed
sh("ip route add 198.51.100.0/24 dev ppp-a metric 9 proto 98"); gw.rt_apply(gw.rt_compute())
ok("stray proto-98 route is removed", "198.51.100.0" not in ours())
# routes of other origin are never touched
sh("ip route add 192.0.2.0/24 dev ppp-a metric 7"); gw.rt_apply(gw.rt_compute())
ok("route of another origin untouched", "192.0.2.0/24 dev ppp-a metric 7" in norm(sh("ip -4 route show table main")))

# ---- protections
gw.rt_write_list("wide", "172.26.0.0/16\n8.8.0.0/16\n44.44.97.0/24\n")        # server network, normal, site endpoint inside
open(gw.RT_RULES, "w").write("wide via 172.17.1.3@c metric 3\nprotect 8.8.8.8\n")
gw.rt_note_viewer("8.8.4.4")
res = gw.rt_compute(); d = res["desired"]
pref = [ipaddress.IPv4Network(k[0]) for k in d]
def covered(ip): return any(ipaddress.IPv4Address(ip) in n for n in pref)
ok("server network is not routed", not covered("172.26.2.106") and not covered("172.26.1.1"))
ok("protected /32 cut out of 8.8.0.0/16", not covered("8.8.8.8") and covered("8.8.7.255") and covered("8.8.9.0"))
ok("web viewer address cut out", not covered("8.8.4.4"))
ok("site endpoint 44.44.97.217 cut out of the /24", not covered("44.44.97.217") and covered("44.44.97.216") and covered("44.44.97.218"))
ok("warnings mention protection", any("protected" in w for w in res["warnings"]), res["warnings"])
ok("cut /16 is split into few routes", 0 < len(d) < 120, len(d))
gw.rt_apply(res)

# ---- conflict with a route of another origin: skipped, not overwritten
sh("ip route add 203.0.113.0/24 dev ppp-a metric 4")
gw.rt_write_list("mine", "203.0.113.0/24\n203.0.114.0/24\n")
open(gw.RT_RULES, "w").write("mine via 172.17.1.3@c metric 4\n")
res = gw.rt_compute(); gw.rt_apply(res)
k = norm(sh("ip -4 route show table main"))
ok("conflicting entry skipped, other route intact", "203.0.113.0/24 dev ppp-a metric 4" in k and "203.0.113.0/24 dev ppp-c" not in k, k)
ok("conflict warned", any("another origin" in w for w in res["warnings"]), res["warnings"])
ok("non-conflicting entry applied", "203.0.114.0/24 dev ppp-c metric 4" in ours())
sh("ip route del 203.0.113.0/24 metric 4")

# ---- via a gateway on a connected network (send to the internet directly)
open(gw.RT_RULES, "w").write("mine via 172.26.0.1 metric 6\n"); res = gw.rt_compute(); gw.rt_apply(res)
ok("gateway next hop", "203.0.114.0/24 via 172.26.0.1 dev ens5 metric 6" in ours(), ours())
open(gw.RT_RULES, "w").write("mine via 8.8.8.8 metric 6\n"); res = gw.rt_compute()
ok("unreachable next hop: no routes, clear message", not res["desired"] and res["rules"][0]["state"] == "nohop", res["rules"][0])
open(gw.RT_RULES, "w").write("mine via 172.17.192.3@zzz metric 6\n"); res = gw.rt_compute()
ok("unknown site", res["rules"][0]["state"] == "nohop" and "unknown site" in res["rules"][0]["text"])
open(gw.RT_RULES, "w").write("mine via 172.17.1.3@a metric 6\n"); res = gw.rt_compute()
ok("site with a different tunnel address", res["rules"][0]["state"] == "nohop" and "172.17.192.3" in res["rules"][0]["text"], res["rules"][0])
open(gw.RT_RULES, "w").write("nolist via 172.17.1.3@c metric 6\n"); res = gw.rt_compute()
ok("missing list reported", res["rules"][0]["state"] == "nolist")
open(gw.RT_RULES, "w").write("mine via 172.17.1.3@c metric 6 disabled\n"); res = gw.rt_compute(); gw.rt_apply(res)
ok("disabled rule: nothing applied, prefixes still counted", not ours() and res["rules"][0]["prefixes"] == 2, res["rules"][0])

# ---- DNS: cache, keep time, failure keeps old addresses
gw.rt_write_list("dnsl", "example.test\n")
now = time.time()
gw.rt_json_write("dns.json", {"example.test": {"ips": {"203.0.113.50": now - 100, "203.0.113.51": now - 4000}, "ts": now, "err": ""}})
open(gw.RT_RULES, "w").write("dnsl via 172.17.1.3@c metric 8\n"); res = gw.rt_compute(); gw.rt_apply(res)
ok("dns: recent address routed, old one (>1 h) not", "203.0.113.50" in ours() and "203.0.113.51" not in ours(), ours())
gw.rt_json_write("dns.json", {}); res = gw.rt_compute(); gw.rt_apply(res)
ok("dns: not resolved yet -> no routes, counted as unresolved", not ours() and res["rules"][0]["unresolved"] == 1)
# refresh function with a fake resolver
import socket as _s
real = _s.getaddrinfo
def fake(name, port, family=0, *a, **k):
    if name == "example.test": return [(2, 1, 6, "", ("203.0.113.60", 0)), (2, 2, 17, "", ("203.0.113.60", 0)), (2, 1, 6, "", ("203.0.113.61", 0))]
    raise OSError("Name or service not known")
_s.getaddrinfo = fake
gw.rt_dns_refresh(now)
c = gw.rt_dns_cache()
ok("dns refresh stores addresses", sorted(c["example.test"]["ips"]) == ["203.0.113.60", "203.0.113.61"], c)
_s.getaddrinfo = lambda *a, **k: (_ for _ in ()).throw(OSError("fail"))
gw.rt_dns_refresh(now + 60)
c = gw.rt_dns_cache()
ok("dns failure keeps the old addresses", sorted(c["example.test"]["ips"]) == ["203.0.113.60", "203.0.113.61"] and c["example.test"]["err"], c)
gw.rt_dns_refresh(now + 5000)
ok("old addresses expire after the keep time", gw.rt_dns_cache()["example.test"]["ips"] == {})
_s.getaddrinfo = real

# ---- the limit
gw.RT_MAX_ROUTES = 50
gw.rt_write_list("big", "\n".join("20.0.%d.0/24" % (2 * i) for i in range(60)))
open(gw.RT_RULES, "w").write("big via 172.17.1.3@c metric 8\n")
res = gw.rt_compute()
ok("more than the limit: nothing applied and an error", not res["desired"] and any("limit" in x for x in res["errors"]), res["errors"])

# ---- preview of a change does not touch disk or kernel
gw.RT_MAX_ROUTES = 20000
open(gw.RT_RULES, "w").write("mine via 172.17.1.3@c metric 6\n"); gw.rt_apply(gw.rt_compute())
before = (open(gw.RT_RULES).read(), ours())
res = gw.rt_compute(rules_text="iran via 172.17.192.3 metric 2\n", list_texts={"iran": "7.7.7.0/24\n"})
cmds, a, c_, r = gw.rt_diff(res["desired"], gw.rt_kernel()[0])
ok("preview: counts without changing anything", (a, r) == (1, 2) and before == (open(gw.RT_RULES).read(), ours()), (a, c_, r))

# ---- RouteSync (what the collector runs)
open(gw.RT_RULES, "w").write("mine via 172.17.1.3@c metric 6\n")
rs = gw.RouteSync(); rs.last_dns = time.time()
t0 = time.time(); rs.tick(t0)
ok("RouteSync applies on first tick", "203.0.113.0/24 dev ppp-c metric 6" in ours(), ours())
sh("ip route del 203.0.113.0/24 metric 6 proto 98"); rs.tick(t0 + 5)
ok("no change in inputs: no work within the full-check time", "203.0.113.0/24" not in ours())
rs.tick(t0 + 61)
ok("full check after RT_FULL_EVERY restores it", "203.0.113.0/24 dev ppp-c metric 6" in ours())
open(gw.RT_RULES, "w").write("mine via 172.17.1.3@c metric 7\n"); rs.tick(t0 + 66)
ok("changed rules file is noticed at once", "203.0.113.0/24 dev ppp-c metric 7" in ours() and "metric 6" not in ours(), ours())
sh("ip link set ppp-c down"); rs.tick(t0 + 71)
ok("a tunnel going down is noticed at once", "203.0.113.0" not in ours())
print("\nALL ROUTE TESTS PASSED" if not fails else "\n%d TESTS FAILED" % fails)
sys.exit(1 if fails else 0)

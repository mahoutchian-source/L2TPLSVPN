# Changelog

Newest first. Rule: every change adds a line here (what, why, where in the code) and bumps VERSION in
`bin/l2tp-gw` AND `bin/l2tp-gw-web`. Bugs found and their fixes go to KNOWN-ISSUES.md.

## 1.1.0 (2026-11-25)
Connection quality monitoring (users complained about slow/choppy links that get better after a reconnect).
- **Measuring every minute** (`l2tp-gw quality-sample`, called by the watcher): 5 quick pings through each tunnel (`-I ppp-NAME`, to the peer address) and 5 pings outside the tunnel to the router's real address (dial-in client: the one IPsec peer, when there is exactly one). One line per site and minute in `/var/lib/l2tp-gw/quality/NAME.log`: `time up|down loss avg max jitter outloss outavg outmax rx_bytes tx_bytes`. 7 days are kept (pruned at 10200 lines); the log of a deleted site is removed with it. A tunnel that is down gets a `down` line. (gw: `pingstat`, `quality_cb`, `cmd_quality_sample`, `cmd_watch`)
- **Speed** comes from the interface byte counters (average and busiest minute per window), not from a speed test: it shows what the users really use, not the top speed of the line.
- **Grade per tunnel** good / fair / poor from loss, average delay and delay swing (fair from 1 % / 150 ms / 40 ms, poor from 5 % / 400 ms / 120 ms) over 5 min, 1 h, 24 h and 7 d, with a plain diagnosis: outside road bad = internet path or filter; outside road fine = look inside the tunnel (IPsec, L2TP, MTU, router load). (web: `q_read`, `q_stats`, `q_grade`, `q_diag`)
- **New pages** `/quality` (all connections: grade, loss, delay, swing, small graph, speed, connected for, drops in 24 h) and `/conn?name=NAME` (one connection: verdict, delay + loss graph and speed graph with 1h/6h/24h/7d tabs, numbers by period, security and link (encryption, IPsec age and ciphers, ipsec_mode, interface, address, MTU set / link now, packet size check), connection history (connected for, last drop, drops in 24 h), recent events from the watcher log). Menu item "Quality"; a quality chip (link) on Sites and Dial-in rows. (web: `quality_page`, `conn_page`, `q_chart`, `q_speed_chart`, `q_spark`, `q_chip`, CSS `.qrow`, `.qchart`, `.qkv`)
- **Telegram:** a message when a connection has been poor for 5 minutes (with the outside-road verdict) and one when it is good again, once per episode (flag file `quality/NAME.alert`). Switch: Settings > "quality alert" (`quality_alert = yes|no` in `notify.conf`, default yes). (gw: `quality_alert`; web: settings page, `read_notify`/`write_notify`/`check_notify`)
- Fix found by the test: a site without an interface made `quality-sample` stop (`ip addr show` failed under `pipefail`) -> `|| true`.
- Tests: new `dev/t31/run.sh` (23 checks: lines, down state, alerts on/off, pruning, cleanup, pages, settings); t27/t28/t29 still pass.

## 1.0.6 (2026-11-25)
MTU: the routing table decides the way, and two different problems get two colours.
- **Measuring follows the routing table.** For an address `mtu-test` asks the routing table (most specific route wins) and prints the route, e.g. "the routing table sends 10.1.0.5 by the route 10.1.0.0/24 (metric 2) through: ppp-a". If that way is a tunnel of ours, it says which site, and the road to its router and the router's own limit count. A multipath route (several tunnels share the traffic) is measured way by way, each with its own result; the panel shows each way with its own "Use N for NAME" button. An address that leaves through the network card is said so (no tunnel wrapping). Forcing an interface is still possible (optional field / second argument) but is no longer the normal way. (gw: `route_devs`, `cmd_mtu_test`, `mtu_measure`, `mtu_find_cb`; web: `mtu_page`) `RESULT` lines now end with `site=NAME prefix=ROUTE` when known.
- **Two problems, two colours** (chip on Sites/Dial-in, list on the Measure MTU page, `mtu-status` states): amber = the router asked for less than set (`lowered`, "MTU 1400: router allows 1360"); red = the size the tunnel really uses does not get through (`bad`, "MTU 1400 does not pass"); both at once = two chips (state `both`); green = passes; plain = could not be checked. `mtu-verify` tests the smaller of "set" and "link now", so the two causes are not mixed up. (gw: `mtu_verify_cb`; web: `mtu_chip`, CSS `.mtured`)
- Tests: t29 has 57 checks (routes, multipath, both-states, chip colours).

## 1.0.5 (2026-11-25)
MTU: is the SET value really passing, and what does the router allow?
- **Check of the set MTU (`l2tp-gw mtu-verify [NAME]`):** for every connected tunnel it sends one ping of exactly the set size (DF, through the tunnel, the link is not touched). States in `/var/lib/l2tp-gw/mtu-status`: `ok` (passes), `bad` (the set size does NOT pass now), `lowered` (the router asked for a smaller size when the tunnel came up), `unknown` (no answer even to a tiny ping: no false alarm). The watcher runs it every 5 minutes (parallel, about 10 s at most); the panel ignores results older than 20 minutes. (gw: `mtu_verify_cb`, `cmd_mtu_verify`, `cmd_watch`)
- **Panel:** the MTU chip on Sites and Dial-in is green when the size passes, amber when it does not pass or when the router allows less ("MTU 1400: router allows 1360"), plain when it cannot be checked. The Measure MTU page lists the state of every connection and has a "Check now" button. (web: `mtu_status`, `mtu_chip`, `/mtu/verify`)
- **Measuring shows the router's own limit (MRU):** when a tunnel came up with a smaller link MTU than the one set here, the peer asked for less (pppd takes the smaller). `mtu-test` says so and never suggests more than that. Before, the test raised the link to 1500 and hid it. `RESULT` has the new field `lowered=` (0 = not lowered). Not possible: reading the router's MRU when it is equal to or bigger than what is set here; then we only know it is not smaller. MRRU belongs to multilink only, which is not used: keep it off on the MikroTik.
- Tests: t29 has 51 checks.

## 1.0.4 (2026-11-25)
Fix: the MTU of a dial-in client was not kept after the client reconnected, and the Dial-in page did not show it.
- **Cause:** the ip-up hook that sets the MTU (`mtu-apply`, new in 1.0.3) is written only by `l2tp-gw apply`. After an update without `apply` the old hook stayed, so a reconnect went back to 1280. **Fix:** `dialin-sync` (also run by every Dial-in save in the panel) now rewrites the hooks too; it touches no tunnel. (gw: `cmd_dialin_sync` calls `write_route_hooks`)
- **Dial-in page:** each client now shows an "MTU N" chip (1280 when empty), like the Sites page. (web: dial-in rows)
- **MTU measuring was too optimistic (found by Ali: it said 1500 while the other end was limited to 1400).** Cause: a big packet can pass INSIDE the tunnel only because the outside packets are cut into pieces on the internet road; the ping still gets an answer, so "no limit" was reported. **Fix:** for a named tunnel `mtu-test` now also measures the road to the far router (outgoing site: its address; dial-in client: its public address, only when exactly one is connected over IPsec; otherwise 1500 is assumed and said) and suggests the smaller of "passes inside" and "road minus 101 bytes of wrapping (IPsec + L2TP + PPP)". With a 1500 road this gives 1399, close to the usual 1400. The text says clearly why. `RESULT` has two new fields `inner=` and `outer=` (outer=0: not measured). A plain address is measured as before (no wrapping). The measurement still cannot see a smaller limit that the MikroTik itself sets (max-mtu / MRU): use the MikroTik command shown on the page to make both ends agree. (gw: `cmd_mtu_test`, `mtu_find_cb`; web: `mtu_page`)
- Tests: t29 has 8 more checks (42): hook rewritten by dialin-sync, live MTU applied, reconnect puts the MTU back, chip on the Dial-in page.
- To get the fix on a running server after the update: `l2tp-gw dialin-sync` (no tunnel is interrupted). The MTU of an outgoing site still needs the next reconnect or `l2tp-gw apply`.

## 1.0.3 (2026-11-25)
MTU: measure the right packet size and set it per connection.
- **MTU per connection** (option `mtu`, 576 to 1500, empty = 1280): outgoing sites pass it to pppd (`mtu`/`mru`; used at the next connect), dial-in clients get it on the live link at once (`ip link set dev pppN mtu X` by the ip-up hook and by `dialin-sync`). The TCP MSS clamp already in the firewall follows the link MTU. Panel: new "Packet size (MTU)" box in Edit site and Edit client, and an "MTU 1400" chip on the Sites page. (gw: `reset_site`, parser, validation, `gen_site`, `mtu_apply_cb`, `cmd_mtu_apply`; web: `KEYS`, edit forms, `save`, `dialin_save`, `site_rows`)
- **MTU measurement:** `l2tp-gw mtu-test NAME|ADDRESS [IFACE]` sends pings that may not be fragmented (`ping -M do`) and searches for the largest size that passes. For a connected site or client it uses the tunnel; for any IPv4 address it uses the normal route (or the given interface). A ppp link is raised to 1500 for the test and always put back. It only suggests a value, nothing is changed. Last line: `RESULT addr=... dev=... current=... max=... suggested=...`. (gw: `cmd_mtu_test`)
- **Panel page "Measure MTU"** (menu, `/mtu`): choose a connection or type an address, measure, press "Use N for NAME" to save it, and see the matching MikroTik command (`/interface l2tp-client set ... max-mtu=N max-mru=N` for a dial-in client, `/interface l2tp-server server set max-mtu=N max-mru=N` for an outgoing site). (web: `mtu_page`, `mtu_run`, `mtu_set`)
- Tests: new `dev/t29/run.sh` (34 checks, also the dashboard map and a syntax check of the page script, uses a `ping` stub with a size limit).
- **New look (dashboard and Sites page; other pages get the glass cards and glow automatically):** soft glow background, translucent "glass" cards, rounder corners, gradient main button; works in the dark and the light theme. Dashboard top: a **live network map** (outgoing sites left, gateway in the middle, dial-in clients right; line colour = state: green up, red connected WITHOUT IPsec / down, amber IPsec allowed-or-waiting, grey dial-in not connected or switched off; a moving dot runs on working lines, hidden when the system asks for reduced motion), a **health donut** (tunnels up of all active) with the two counts, and a **traffic chart** (download and upload of all tunnels). Sites page: a small **speed graph per tunnel**. The graphs are drawn in the browser from the speed numbers it already polls every 2 s, so they start empty when the page opens and fill within a minute or two (nothing is stored). (web: `CSS`, `JS`, `site_class`, `map_svg`, `dash_html`, `site_rows`)
- **Version note:** 1.0.2 (shorter `status`/Sites output) was never uploaded on its own; everything of it is included here.
- **Docs:** new `docs/PROJECT-MEMORY.md` (project memory for the next session: what the project is, how we work, versions, open items, lessons; no secrets) and a line in the README.
- Visual check tool: `dev/t30/shots.sh` (fixture with 7 sites and 3 dial-in clients, fake traffic, screenshots of both pages in both themes; needs playwright).

## 1.0.2 (2026-11-24)
- **Bug fix (my mistake in 1.0.1): the Sites page and `l2tp-gw status` became thousands of lines long and froze the browser.** 1.0.1 listed every multipath route under every tunnel, and the route manager (country lists, proto 98) creates thousands of them. Now `status` shows a multipath route once, in ONE line (`172.17.192.0/22 metric 2 via ppp-a, ppp-b`) under each of its tunnels, and routes of the route manager only as a count ("N routes of the route manager ... see the Routes page"). The routing table is also read once instead of once per tunnel. (gw: `cmd_status`; test t28 now builds 200 such routes and checks the output stays under 60 lines)

## 1.0.1 (2026-11-24)
Tunnel stability and honesty about encryption. Backup of 1.0.0 kept (`l2tp-gw-1.0.0-backup-*.tar.gz`).
- **`ipsec_mode = require` now really blocks plain L2TP:** UDP 1701 from the router's address is dropped unless it arrived inside IPsec (iptables chain `L2TPGW-REQ`, rebuilt on every apply, empty when no site uses `require`). `heal` and `allow` sites are never touched. `check` reports the rule. (gw: `apply_require_fw`, `check_site`)
- **PPP keep-alive on outgoing tunnels** (site option `lcp_echo = on|off`, default on): the server asks every 30 s and redials after 6 missed answers (3 min), so a tunnel that died silently is found. Panel: Edit site > IPsec. (gw: `gen_site`; web: edit form, `save`)
- **IPsec is read a second time before an alert or repair** (an IKE re-key can hide the SA for a moment) – fewer false "tunnel without IPsec" alerts. Test setting: `IPSEC_RECHECK_WAIT` (default 3 s). (gw: `watch_ipsec`)
- **Panel shows the real state of each outgoing site:** "IPsec up/down · PPP up/down · Encryption: IPsec / MPPE only / none". (web: `site_rows`)
- **MPPE checkbox renamed** "PPP-level encryption (MPPE), not IPsec" with an explanation (it never forced IPsec; the router shows `mppe128` for it and `cbc(aes)` for IPsec). (web: edit form)
- **Bug fix: a password with non-ASCII characters (e.g. Persian) caused a server error** at login and in Settings > Panel password (`compare_digest` accepts only ASCII text). Now compared as bytes. (web: `same_secret`)
- **`l2tp-gw status` lists multipath routes** under every tunnel that is one of their next hops (they were hidden before). (gw: `cmd_status`)
- **`check` warns when two active dial-in clients have the same network and the same distance** (traffic is split between them; usually a typo like 248 instead of 242). (gw: `check_dup_routes`)
- **One-command install from GitHub** (`install.sh` in the repository root): downloads the newest files, checks both programs for syntax errors and the versions for equality, builds the single-file installer and runs it; nothing is changed if a check fails. Options `--restore FILE`, `--no-setup`, `--no-web` are passed on. Test settings: `L2TPGW_SRC`, `L2TPGW_URL`.
- **Installer fix:** the checksum list no longer includes itself (it could make the installer stop with "Checksum failed" depending on timing). (dev: `make-installer.sh`)
- Tests: new `dev/t28/run.sh` (20 checks); t20 firewall check updated for the new chain.

## 1.0.0 – stable (2026-11)
First numbered release: a consolidation of everything built before (earlier versions were date-stamped, last one 2026.11.06-1).
New in this step compared with 2026.11.06-1:
- **Web redesign:** dark dashboard (light theme via "Theme"), left side bar, tunnel health strip, two-column dashboard, mobile top bar. (web: `CSS`, `page()`, `dash_html`)
- **Change panel password in the web** (Settings > Panel password; other sessions are logged out). (web: `/settings/password`)
- **DNS cache flush** every 30 min (setting `dns_flush_min`, 0 = off) and before the DDNS check of a down tunnel. (gw: `dns_flush*`)
- **Events page paging** (25 per page, Newer/Older). (web: `events_page`, `pager`)
- **Firewall status** on the dashboard (Firewall and Access rules rows). (web: `firewall_state`)
- **Clock** at the top of every page (server time, chosen time zone).
- **Settings file to Telegram** when it changes (option `tg_send_config`, off by default). (gw: `cfg_send_check`)
- **One-file installer** (`l2tp-gw-install.sh`) incl. `--restore`.
- Version numbers are now simple (1.0.0, 1.1.0 ...).

Features that already existed (built in this order, see KNOWN-ISSUES for the problems met):
1. Outgoing tunnels (strongSwan IKEv1 transport + xl2tpd + pppd), sites file, apply/restart, NAT, routes per site.
2. Health check, backup/restore, per-site logs, reconnect, Telegram alerts (watch timer every minute), DDNS re-apply.
3. Traffic collector: daily usage per site, limits with warning, scheduled/auto reconnect, CSV download.
4. Web panel (first version), IPsec policy per site (heal/allow/require), auto repair of tunnels without IPsec.
5. Route manager: country lists from RIR data, custom lists, priority rules with metric, safe mode (auto undo).
6. Dial-in server mode: per-client user/password/fixed IP/routes/NAT/quota, shared IPsec secret, live `dialin-sync`.
7. Dashboard: CPU/RAM/disk, network card history, services, kernel health, Telegram state, brand name, time zone and unit settings.
8. Journald size cap (200M, a manual command), automatic daily backup (7 copies), RAM/swap warning, event log.
9. Reset of a single site's numbers with archive of old reports; deleted sites' reports are archived too (Traffic > Archive).
10. Access control per dial-in client and per outgoing site (internet / other dial-in clients / outgoing sites), chain `L2TPGW-ACC`, live `access-sync`.

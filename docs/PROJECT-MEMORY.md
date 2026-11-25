# Project memory (read this first in every new session)

Purpose: a new Claude session (or a person) opens this file and knows what the project is, how we work, what is done,
what is open, and what went wrong before. Keep it current: every session that changes something adds a line to the log
at the bottom. No passwords, keys or secrets in this file (the repository is public).

## 1. Who and what
- Owner: Ali (Persian speaker, good with MikroTik, weaker with Linux). Talk to him in simple Persian, short, plain words, no jargon
  (see section 3). He pastes commands over SSH and uploads files to GitHub by hand in the web page.
- The project: one AWS Lightsail server (Ubuntu 24.04) that is an L2TP/IPsec gateway between MikroTik routers.
  - Outgoing sites (the server dials them): nttlinka, nttlinkb, noapcolinka, noapcolinkb, setudalinka, setudalinkb, setudalink3.
  - Dial-in clients (routers dial the server, for sites behind NAT): home, millionex, hamidca.
- Two programs, always the same VERSION:
  - `bin/l2tp-gw` (bash): config generation, apply, status, check, watchdog, firewall, routes, MTU tools.
  - `bin/l2tp-gw-web` (python): the web panel and the traffic collector.
- Stack: strongSwan (IKEv1 transport) + xl2tpd (L2TPv2 only) + pppd. Routes are multipath (ECMP); the route manager's routes carry `proto 98`.

## 2. Install, update, go back
- Repository (public): https://github.com/mahoutchian-source/L2TPLSVPN
- One-command install or update on any fresh Linux (needs the repo public):
  `curl -fsSL https://raw.githubusercontent.com/mahoutchian-source/L2TPLSVPN/main/install.sh | bash`
  Options after `-s --`: `--restore FILE`, `--no-setup`, `--no-web`. It downloads the newest files, checks syntax of both programs and that the versions are equal, builds the single-file installer and runs it. Nothing changes when a check fails.
- Check the result: `l2tp-gw version` (must show the new version) and `l2tp-gw check` (all OK).
- Paths on the server: config `/etc/l2tp-gw/`, state `/var/lib/l2tp-gw/`, backups `/var/backups/l2tp-gw`, programs `/usr/local/bin`.
  The installer saves the old programs in `/root/l2tp-gw-old-DATE`. A backup of 1.0.0 was made and sent to Ali (`l2tp-gw-1.0.0-backup-*.tar.gz`).
- If the repository is made private, the install needs a token; the one-command install works only while it is public.

## 3. How we work (rules the owner asked for)
- Reply in Persian when he writes Persian; use Persian words where they exist; short and clear; do not make things up.
- Request clear -> just do it. Before changing a file or recording a decision: restate simply, ask "is this what you mean?", act after he confirms; then do all approved steps and report once.
- Any change to important documents needs his permission, a reason and a log entry. Every file change is logged: `docs/CHANGELOG.md` (what, why, where in the code) and the log at the bottom of this file.
- Disagree once with a reason, then follow his decision.
- Every new version: bump VERSION in BOTH programs, add a CHANGELOG entry, rebuild the installer (`bash dev/make-installer.sh`), run the tests, send an upload zip.
- Upload to GitHub is manual (web page): fewer than 100 files per upload, per folder; commit message = the version number (`1.0.3`). Commit messages so far were mislabelled (1.0.1 / 1.0.4) - only a label, the files decide the version.
- The upload zip contains only changed files, in their folders. Give a NEW file name for every zip (a same-name zip is cached and the old one gets opened). After he uploads, fetch the public repo (`git fetch` in the clone) and compare every file with the working copy.
- Work in `/home/claude/proj/l2tp-gw-1.0.0` (working copy), `/home/claude/repo` (clean upload tree), the repo clone `/home/claude/mahoutchian-source/l2tplsvpn`. These sandbox folders may be gone in a new session: then clone the public repo and work from it.

## 4. Version history (details in CHANGELOG.md)
- 1.0.0: first numbered release (consolidation; dark panel, DNS flush, paging, panel password change).
- 1.0.1: `ipsec_mode = require` really blocks plain UDP 1701 (chain `L2TPGW-REQ`); PPP keep-alive `lcp_echo`; IPsec re-checked before an alert; honest per-site state text; Persian password bug fixed; duplicate-network warning; one-command `install.sh`; installer checksum fix.
- 1.0.2: `status`/Sites output made short (1.0.1 printed thousands of route lines and froze the browser).
- 1.0.3: MTU per connection (empty = 1280), `l2tp-gw mtu-test NAME|ADDRESS [IFACE]`, panel page "Measure MTU" with the matching MikroTik command; new look (glass cards, live network map, health donut, traffic chart, per-tunnel sparkline) for the Dashboard and Sites pages.
  MTU details: outgoing sites pass it to pppd (applies at the next reconnect); dial-in clients get it on the live link at once (ip-up hook `mtu-apply` and `dialin-sync`). Measuring uses `ping -M do -s N` with a halving search; a ppp link is raised to 1500 for the test and always restored; last line `RESULT addr=.. dev=.. current=.. max=.. suggested=..`. It only suggests.
- 1.0.4: fix: MTU measuring also checks the outside road (a ping can pass inside the tunnel because outside packets get fragmented; suggestion = min(inside, road - 101)); fix: `dialin-sync` rewrites the ip-up hooks (so the MTU of a dial-in client survives a reconnect even if `apply` was not run after the update); MTU chip on the Dial-in page.
- 1.0.5: `mtu-verify` (is the SET MTU really passing; watcher every 5 min; amber chip), MRU of the router shown (link MTU lower than set = router asked for less), "Check now".
- 1.4.0: automatic MTU (`mtu = auto`, range `mtu_min`/`mtu_max`/`mtu_margin`, MRU-aware, two matching measurements, daily cap), road/UDP diagnostics (`mtu-road/NAME`, health lines, conn page rows), `l2tp-gw mtu-auto [NAME]`. Real server not yet verified.
- 1.3.0: quality limits per connection + defaults (`quality.conf`, Settings page) and automatic reconnect of a link that stays poor (`quality_reconnect`, off by default).
- 1.2.1: MSS chain `L2TPGW-MSS` (both directions per tunnel, `mss-apply`), health lines for MSS and ICMP, MSS/UDP rows on the connection page. Open: Ali reports services that stall on ALL tunnels; waiting for his tcpdump (`-Q in`/`-Q out` SYN MSS) and MikroTik DF-ping results to know if MSS was the cause or UDP/ICMP/MRU.
- 1.2.0: Health check merged into Quality (health line per connection + "Server and services" card; /check redirects); Traffic page rebuilt (overview table + chart, detail page `/traffic?name=`, traffic card on /conn).
- 1.1.0: quality monitoring: `quality-sample` every minute (pings inside + outside the tunnel, byte counters) -> `quality/NAME.log`; pages `/quality` and `/conn?name=`; Telegram alert (switch `quality_alert`). Ping measures delay/loss, NOT the top speed of a line (a manual bandwidth test could come later).
- 1.0.6: `mtu-test ADDRESS` follows the routing table (multipath: each way separately, shows route + tunnel); amber = router allows less (MRU), red = does not pass, two chips when both.

## 5. Behaviour to remember (how things work)
- `ipsec_mode`: `heal` (default: alert after 120 s, reconnect up to 3 times 10 min apart, then give up) | `allow` (no alert, no repair) | `require` (30 s grace, repair every 2 min, plus the firewall chain).
- `lcp_echo` on|off for outgoing sites (default on, every 30 s, 6 misses = redial). Dial-in clients: lcp-echo 30/4.
- Light changes (dial-in, access boxes, MTU of a dial-in client) use `dialin-sync` and interrupt no tunnel; a normal save runs `apply`.
- Graphs in the panel are drawn in the browser from the 2-second speed polling; nothing is stored, they start empty when the page opens.
- Tests: `cd dev/t29 && bash run.sh` (57 checks), `dev/t28`, `dev/t27`; everything: `cd dev && bash allt.sh`. Run each test from its own folder. Visual check: `dev/t30/shots.sh` (playwright). Test setup: stub `bin/` folders, `ip tuntap` devices (no dummy type in the sandbox), port 18082 for the test web server, `pkill -f l2tp-gw-web` before tests, `apt-get install iproute2` if `ip` is missing, call the real curl as `/usr/bin/curl` (the stub folder shadows it).
- Known test failures that are only the sandbox: t17 (1), t18 (4), t21 (13), t24 (1), t20 (1: "nothing listens on UDP 1701"). Old folders t8, t13, t16, t19 print text without PASS/FAIL; t13 needs a folder that no longer exists.

## 6. Open items (nothing here is decided unless it says so)
- NOT proven: the real cause of tunnel flapping, "up without encryption" and the panel-vs-MikroTik mismatch. 1.0.1 only reduces symptoms. Evidence to save when it happens again: `l2tp-gw check`, `ipsec statusall`, `/var/lib/l2tp-gw/watch.log`, the MikroTik log.
- Filtering/ISP problem: Ali believes L2TP v2 / IPsec is blocked while L2TPv3 passes. MikroTik can do L2TPv3 (RouterOS 7.1+, also with PPP user/password), but Linux has no ready daemon for v3 control with PPP (not verified further). Ideas discussed, NOTHING built, no decision: first test UDP reachability, then WireGuard on UDP 443, or Xray/REALITY, or SSTP. Both ends are Linux machines he can set up if needed.
- Next planned: give the new look to the other pages (Dial-in, Traffic, Events, Routes, Settings, Check, Backup) after Ali has checked Dashboard/Sites on the real server.
- On the server: run `l2tp-gw apply` in a quiet hour so the PPP keep-alive reaches the existing tunnels (existing tunnels keep their old options until then); test the MTU measuring and the access boxes on real tunnels.
- Security: rotate the IPsec secret and the PPP password of dial-in client `home` (they appeared in screenshots); close port 80 in the cloud firewall if not needed; make the repository private later (see section 2); connect Telegram alerts and test them; static IP and a domain; ask Setuda/NTT to allow new IPs.
- Stored graph history needs the collector to keep samples (not built).

## 7. Mistakes and lessons (do not repeat)
- Do not claim L2TPv3 is always Ethernet-only: MikroTik's l2tp-client supports v3 with PPP.
- Pasting part files into nano added blank lines; check size and md5 ("file + 1 byte"); `sed -i '/^$/d'` fixed it.
- The installer's MD5SUMS used to list itself (flaky "Checksum failed") - fixed in 1.0.1.
- GitHub web upload: loses executable bits and symlinks (after clone/upload run `chmod +x bin/* dev/t*/bin/* && ln -sfn ../bin dev/build`), fewer than 100 files at a time, a file can land in the wrong folder (`run.sh` once went to `bin/` instead of `dev/t28/`), `__pycache__` can sneak in.
- The `add_repo` / `list_repos` tools said "no GitHub account linked"; work-around: read the public repo, hand over zips for manual upload. The sandbox shell cannot download from GitHub (403); WebFetch/`git fetch` of the public repo worked.
- A page script with a syntax error silently kills clock, speed and graphs: `t29` now checks the script with node.
- Python `%`-formatting of big HTML strings: a stray `%` or an unquoted SVG attribute like `r=50/>` breaks the page silently; check the rendered page.
- The 1.0.1 `status` change listed every route per tunnel -> thousands of lines (fixed in 1.0.2). Always test with large route tables (the route manager).
- Fixture traps in tests: dial-in test passwords must be 8-64 characters; do not reuse 203.0.113.0/24 outside t15; tun devices only count traffic when a process reads them (`dev/t30/traffic.py`).

- A DF ping through a tunnel proves nothing about the outside road: the outer packets may be fragmented. Measure inside AND outside, and say what was assumed. The measurement cannot see the peer's own MRU/max-mtu limit.

## Ideas agreed but not built yet
- Finance section (Ali, 2026-11-25): cost per day / week / month for each link, a price per megabyte for each link (download and upload separate), base currency Canadian dollars, with conversion to other currencies later. To be discussed with Ali before building.
- Quality: tunnels that share the same local AND remote address cannot be measured one by one (the reply may return through the other tunnel). Ali is giving every tunnel its own local address on the MikroTik side and will report. Possible later: a warning in the panel for shared addresses; a manual bandwidth test (needs the MikroTik bandwidth server).

## 8. How to start the next session
Tell Claude: "Read docs/PROJECT-MEMORY.md and docs/CHANGELOG.md in the repo, then continue." Claude must first clone the public repo
(https://github.com/mahoutchian-source/L2TPLSVPN), read these two files and docs/KNOWN-ISSUES.md, check `bin/l2tp-gw` and `bin/l2tp-gw-web`
have the same VERSION, and ask Ali what he wants next (usual options: look of the other pages, anti-filtering tunnel, the open items above).

## Where the tests are
All test folders (t8 ... t35, allt.sh, screenshot scripts) are packed in `dev-tests.tar.gz` at the repo root (reason: GitHub web upload takes 100 files at a time, and Ali uploads a full package every time). To use them: `mkdir -p dev && tar xzf dev-tests.tar.gz -C dev && ln -s ../bin dev/build`. `dev/make-installer.sh` and `dev/installer-head.sh` stay as plain files (install.sh downloads them). Run each test from its own folder; do not use `pkill -f l2tp-gw-web` inside a command that contains that text; killed test runs leave tun devices (`ppp-*`) behind, delete them first.

## Log of changes to this file
- 2026-11-25: created (reason: Ali asked for a project memory so a new session understands the files without the old conversation).
- 2026-11-25: added version 1.0.4 (MTU of dial-in clients after reconnect, found by Ali on the real server). Lesson: an update that adds a hook needs the hook rewritten without `apply`; test the "updated but not applied" state.
- 2026-11-25: MTU measuring fixed (road check), found by Ali on the real server (said 1500 where the router was capped at 1400).
- 2026-11-25: version 1.0.5 (MTU verification and router MRU), requested by Ali: real ceiling per tunnel and amber warning when the set MTU does not pass.
- 2026-11-25: version 1.4.0, requested by Ali: automatic MTU inside a range, MRU care, alarms, UDP answer. Lesson: a ppp link size set by us looks like "router asked for less" to the next check; remember what WE set (`mtu-auto/NAME.applied`) to tell a fresh negotiation from our own change.
- 2026-11-25: version 1.3.0, requested by Ali: poor limits per connection with defaults, automatic reconnect after N minutes of poor (per connection), cooldown, daily cap, time window.
- 2026-11-25: version 1.2.1, requested by Ali: stalls on all tunnels -> MSS rules per tunnel in both directions, checks, UDP/MSS info. Lesson: `--clamp-mss-to-pmtu` uses the OUTGOING interface only; a test stub whose last line is `exit 0` makes every `-C` succeed (it hid two bugs).
- 2026-11-25: version 1.2.0, requested by Ali: Health check merged into Quality, Traffic page rebuilt. Lesson: `%` binds tighter than `+` in Python, so an `+ extra +` inside a formatted string breaks the argument count (give the extra as a `%s` argument).
- 2026-11-25: version 1.1.0, requested by Ali: connection quality monitoring (loss, delay, jitter, speed, grade, diagnosis, two new pages, Telegram alert on/off). Lessons: under `set -o pipefail` a failing `ip addr show` ends the script (use `|| true`); a literal `%` inside a `%`-formatted HTML string breaks the page (write `%%`); never run `pkill -f l2tp-gw-web` from a command line that contains that text; killed test runs leave tun devices behind (delete `ppp-*` before re-running).
- 2026-11-25: version 1.0.6, requested by Ali: measure along the routing table (not a forced interface), show the way out, two colours for two different MTU problems.
- 2026-11-25: tests packed into dev-tests.tar.gz (Ali's wish: one full package per upload instead of copying folders by hand); added section "Where the tests are" and section "Ideas agreed but not built yet" (finance section, shared-address note).

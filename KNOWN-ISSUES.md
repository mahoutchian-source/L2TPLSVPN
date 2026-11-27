# Known issues, limits and lessons (so they are not repeated)

## Limits (by design or not yet tested)
- Access control (`L2TPGW-ACC`) was tested with virtual interfaces and network namespaces, **not** with a real PPP/MikroTik tunnel. Only forwarded traffic is filtered, not traffic the server itself starts.
- A new dial-in session has a few-millisecond gap before the ppp ip-up hook sets its interface rules.
- Backups (daily copies and the settings file sent to Telegram) hold all passwords. The daily copies are on the same disk; Telegram is not end-to-end encrypted.
- DNS flush empties only the local cache (systemd-resolved/nscd). An upstream resolver keeps an old answer until the DNS record's TTL ends.
- The web panel has no HTTPS unless `tls = on` (self-signed). Default bind is 127.0.0.1.
- IPv4 only. ESP counters of sites that share one IKE SA can be attributed to the wrong site; traffic counting uses ppp counters, so it is not affected.
- Possible IP change of the Setuda sites seen in status: never verified in logs.

- (1.4.5) The server has ONE address on every dial-in link (`local`): pppd gets the local address from the shared `[lns]` option and xl2tpd chooses `[lns]` only by the caller address. A different server-side address per client would need a way to give pppd a per-user local address; none was found (not testable in the sandbox). Ali asked for it on 2026-11-27: open.
- (1.4.5) The DNS name of the public address is checked every `dns_every` minutes, but a re-apply caused by it runs at most once in 10 minutes (the old DDNS guard).
- MTU and quality tests (1.4.4) are tested only with stubs (dev/t37, t29, t31, t34, t36). Real-server proof is still missing for: `ip l2tp show tunnel` (the public address of a dial-in client), the pppd pid file `/var/run/IFACE.pid`, the real answer of a MikroTik to a DF ping bigger than its limit (silent drop or "Frag needed"), and the cut commands on live tunnels.
- **A DF ping through the tunnel cannot see splitting outside the tunnel** (the wrapped packet may be split by the road and still arrive). The 1.4.3 "+101" warning was removed on Ali's decision; the test only says whether a packet of the size passes through the tunnel.
- **Silent black holes:** many routers never send "packet too big". So the trigger is "too-big message OR (small packets >= 71% and size-packets < 71%)". A tunnel that loses many small packets too gets "no usable answer" and is not stepped.
- **Nothing is changed by the test.** The suggested MTU is only shown; to use it set `mtu` on the connection (outgoing) or the inbound default in Settings; the tunnel is then cut once.
- **Dial-in clients cannot each get their own number.** pppd offers its size (`mtu`/`mru` in the shared file `options.l2tpd.dialin`) before it knows who calls, and xl2tpd picks a file only by the caller's IP address. So one inbound number for all (Settings). What a router really uses is the smaller of that and its own max-mtu / max-mru; to give one router less, lower it on the MikroTik. A per-client number would need the client's fixed public address (one `[lns]` section per client).
- A structural save of an outgoing site (host, secrets, routes ...) still runs `apply`, which restarts strongSwan and xl2tpd (all tunnels reconnect). Only the number/test/access/alert changes use the light `site-sync` and the one-time cut of that tunnel.
- Load of the test: with the defaults (test every minute, 10 pings, two addresses, DF pings of full size) every connection sends about 40 packets a minute; raise `test_every` for many connections.
- The test packets (ICMP) of a firewalled far end can be blocked: then the circles are black and the size result "no answer"; the own test address (a host behind the far end that answers) is meant for that.
- Old test folders t8, t13, t16, t19 print text (no PASS/FAIL words); t13 needs a folder that does not exist any more: read by eye or skip.
- Parked (not built): Finance section, manual bandwidth test, anti-filtering tunnel; open: Telegram never tested on the real server (probably why no alert arrived during the long outage), rotate the secrets of `home`, make the repo private later, a static IP.

## Open items
- The new graphs (1.0.3) only show data since the page was opened (nothing is stored on the server). A stored history would need the collector to keep samples; not built.
- MTU measuring (1.0.3) was tested with a ping stub, not on a real tunnel. It measures one direction (this server toward the address); the other direction may differ. Replies can be dropped by some routers (ICMP blocked): then "No answer" is shown and nothing is guessed. A new MTU on an outgoing site is used after the next reconnect.
- Cause of the "up without encryption" / "panel down but router still shows it" episodes is NOT proven. 1.0.1 only reduces the symptoms (re-check, PPP keep-alive, firewall for `require`, clearer panel). If it happens again, save `l2tp-gw check`, `ipsec statusall`, `/var/lib/l2tp-gw/watch.log` and the router's log at that moment.
- Some ISPs/filters seem to block L2TP/IPsec (UDP 500/4500, ESP) while L2TPv3 passes; the server (xl2tpd) speaks L2TPv2 only. Ideas (WireGuard on UDP 443, Xray/REALITY, SSTP) are discussed but NOT built; no decision yet.
- `ipsec_mode = require` blocks only incoming plain UDP 1701; outgoing plain packets are already held back by strongSwan's policy while no SA exists (not verified on a real server).
- Rotate the IPsec secret and the PPP password of dial-in client `home` (they appeared in screenshots).
- Close port 80 in the cloud firewall if not needed; connect Telegram; test Disable/Enable of a dial-in client on a real server; test the access boxes on a real tunnel (`iptables -S L2TPGW-ACC`).

## Mistakes made and how they were fixed
- A Persian panel password gave a server error (500): `secrets.compare_digest` raises TypeError for non-ASCII `str` -> compare UTF-8 bytes (1.0.1).
- t28 needs the `ip` command; a fresh sandbox may lack it (`apt-get install iproute2`), dummy interfaces are not available there (use `ip tuntap`).
- Leftover test web servers on port 18082 gave wrong results -> always `pkill -f l2tp-gw-web` before tests.
- `set -e -o pipefail` in `l2tp-gw`: a pipeline with an empty `ls` aborted `backup-auto` -> add `|| true`.
- CSP blocked the `data:` icon images -> `img-src 'self' data:` in the CSP header.
- Test posted `nat=no` (a non-empty value = "true") -> in the sites file only "yes"/"no" strings count; do not post arbitrary values.
- netns lab: veth name clashes (create with temporary names, rename inside the namespace), `ping` missing (apt iputils-ping), a test grep for `-A` matched `L2TPGW-ACC` (use `'^-A'`).
- nano adds one trailing newline when a patch file is pasted -> size and md5 are checked as "file + 1 byte".
- Helper `sed -n 1,16p run.sh` started a test web server by accident -> read test headers with lines 1-13.
- A site removed from `sites.conf` used to lose its traffic history -> now archived (Traffic > Archive).

- Quality (1.1.0): ping measures delay and loss, not the top speed; the speed numbers are what users really used. A router that does not answer ping shows "No answer to ping" and no grade. History is kept 7 days (one line per minute).

- Quality (1.1.0/1.2.0): two tunnels with the same local and remote address share the reply path, so loss and the MTU check can differ between them for no real reason. Give each tunnel its own address.
- Traffic (1.2.0): the forecast of the traffic limit is a straight-line guess from the counter since the last reset; it is shown only after one hour of data.

- MSS (1.2.1): the per-tunnel rules fix TCP only. UDP traffic that is bigger than the tunnel allows is split (no DF) or lost (DF set and ICMP blocked). The fix is a correct MTU per tunnel and ICMP "packet too big" not blocked (see the health lines).

- Automatic reconnect (1.3.0): a dial-in client is only disconnected; it comes back only if the MikroTik redials by itself. The 5-minute blocks need at least 3 answered minutes; a tunnel that is down is not counted as poor (the watcher's own down handling takes over).

- 1.4.4 lesson: a lock file descriptor (`exec 6>`) is inherited by every background job started after it; close it (`6>&-`) for jobs that outlive the run, or the next run silently skips (found by test t34). A test that calls a once-a-minute routine many times in a second must force it (`Q_FORCE=1`).
- 1.4.4 lesson: Ali's examples show his logic; write all rules back to him as a numbered list and get a yes before coding (22 rules, 2026-11-26).

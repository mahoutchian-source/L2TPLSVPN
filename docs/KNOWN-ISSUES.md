# Known issues, limits and lessons (so they are not repeated)

## Limits (by design or not yet tested)
- Access control (`L2TPGW-ACC`) was tested with virtual interfaces and network namespaces, **not** with a real PPP/MikroTik tunnel. Only forwarded traffic is filtered, not traffic the server itself starts.
- A new dial-in session has a few-millisecond gap before the ppp ip-up hook sets its interface rules.
- Backups (daily copies and the settings file sent to Telegram) hold all passwords. The daily copies are on the same disk; Telegram is not end-to-end encrypted.
- DNS flush empties only the local cache (systemd-resolved/nscd). An upstream resolver keeps an old answer until the DNS record's TTL ends.
- The web panel has no HTTPS unless `tls = on` (self-signed). Default bind is 127.0.0.1.
- IPv4 only. ESP counters of sites that share one IKE SA can be attributed to the wrong site; traffic counting uses ppp counters, so it is not affected.
- Possible IP change of the Setuda sites seen in status: never verified in logs.

## Open items
- The new graphs (1.0.3) only show data since the page was opened (nothing is stored on the server). A stored history would need the collector to keep samples; not built.
- Old test folders t8, t13, t16, t19 print results as text (no PASS/FAIL words) and t13 needs a `c` folder that no longer exists: read them by eye or skip; t29 covers the web panel.
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

# Development guide – where to start

Two programs, no other dependencies:

| File | Language | What it is |
|---|---|---|
| `bin/l2tp-gw` | bash | Everything that touches the system: parses `sites.conf`, writes strongSwan/xl2tpd/ppp config, iptables, `apply`, `watch` (timer), backup, check, setup. |
| `bin/l2tp-gw-web` | python3 | Web panel (`run`), traffic collector + events (`collect`), `install`, `setpass`. Calls `l2tp-gw` for every change. |

Rule: the web never edits system config itself; it edits `/etc/l2tp-gw/*` and calls `l2tp-gw apply` / `site-sync` /
`dialin-sync` / `access-sync`. Full `apply` restarts services (tunnels flap); the `*-sync` commands do not.

## Find things (grep the section markers, line numbers change)

| Topic | `l2tp-gw` | `l2tp-gw-web` |
|---|---|---|
| Sites file keys | `reset_site`, `load_site`, `for_each_site` | `KEYS`, `OPTIONAL`, `load_sites`, `save_sites` |
| Generated config | `gen_site`, `apply_*` | – |
| Firewall / NAT | `apply_dialin_fw` (`L2TPGW-IN`), `apply_client_access` (`L2TPGW-ACC`), NAT chain `L2TPGW-NAT` | `firewall_state` |
| Alerts, DDNS, DNS flush, config to Telegram | `notify_send`, `cmd_watch`, `watch_site`, `dns_flush*`, `cfg_send_check` | `settings_page`, `read_notify` |
| Backups | `cmd_backup`, `cmd_backup_auto`, `cmd_restore` | backup page |
| Dial-in | `dialin-*`, `cmd_dialin_sync` | section "dial-in" |
| Traffic, limits, reconnect, events, memory warning | – | section "traffic collector", `add_event`, `check_memory`, `archive_orphans` |
| Route manager | – | section "route manager" (lists, rules, country data, safe mode) |
| Look and feel | – | `CSS`, `JS`, `page()`, `dash_html`, `THEME_BOOT` |
| HTTP routes | – | `do_GET`, `do_POST` in section "http" |
| Commands | `cmd_*`, dispatcher at the end | `cmd_run`, `cmd_collect`, `cmd_install`, `cmd_setpass` |

## Files on the server

- `/etc/l2tp-gw/`: `sites.conf` (all sites + secrets), `dialin.conf`, `web.conf` (password, bind, port, tls), `notify.conf` (Telegram, dns_flush_min, tg_send_config), `general.conf` (time zone, unit, brand), route files.
- `/var/lib/l2tp-gw/` (state): `events.log`, `traffic/` (daily CSV, archives, reset flags), `down-*`/`alerted-*`/`ddns-*` per site, `last-dns-flush`, `cfg-sent.md5`, `watch.log`, `notify.last`.
- `/var/backups/l2tp-gw/`: 7 daily copies of the sites + dial-in settings.
- systemd: `l2tp-gw-web`, `l2tp-gw-collect`, `l2tp-gw-watch.timer` (every minute).
- Flags between web and collector: empty files in the traffic dir (`reset.NAME`, `reset-site.NAME`).

## Test

`dev/` holds the sandbox tests (stub programs for ipsec/iptables/systemctl, fake /proc, a netns lab). Layout matters:
`dev/build` is a link to `bin/`. Files uploaded through the GitHub web page lose the executable bit and the link: after a fresh clone/download run
`chmod +x bin/* dev/t*/bin/* && ln -sfn ../bin dev/build` before the tests (the installers do not need this).

    cd dev && bash allt.sh            # most suites, output in allt.out (expect 1 known FAIL in t20: nothing listens on UDP 1701 in a sandbox)
    cd dev/t11 && python3 test_collector.py    # 41 checks
    cd dev/t21 && bash run.sh   # access control, backup, events      (t22: dashboard, ~100 s, run alone)
    cd dev/t24 && bash run.sh   # site access   cd dev/t25 && bash lab.sh && bash t.sh   # netns lab, needs root
    cd dev/t27 && bash run.sh   # 1.0.0 features (password, DNS flush, events paging, config to Telegram)
    cd dev/t28 && bash run.sh   # 1.0.1 features (require firewall, PPP keep-alive, IPsec re-check, multipath status, duplicate networks, Persian password); needs `ip` (apt install iproute2)
    cd dev/t29 && bash run.sh   # 1.0.3 MTU (per-connection mtu, mtu-apply, mtu-test with a ping stub, panel page); needs `ip`
    cd dev/t30 && bash shots.sh   # screenshots of Dashboard and Sites (dark + light) with fake traffic; needs playwright and chromium
    cd dev/t26 && bash shots.sh # screenshots (needs playwright/chromium)

Kill leftover test servers first: `pkill -f l2tp-gw-web` (they use port 18082 and give wrong results if left running).
Write a new test in the newest `tNN` folder by copying `t29/run.sh` (it shows how to log in and post with CSRF).

## Shipping a change

1. Edit `bin/*`, add tests, run `allt.sh`.
2. Bump VERSION in both files, add a line to `docs/CHANGELOG.md`.
3. Build the installer: `bash dev/make-installer.sh` (creates `l2tp-gw-install.sh`).
4. On the server run the installer again (upgrade, settings kept). Small fixes can also be sent as a `diff -u` patch.

## Style rules used so far

Comment every function in plain words; never print or log secrets (tokens go to curl through stdin); changes that
could cut working tunnels must use the live `*-sync` paths or ask first; label untested parts honestly.

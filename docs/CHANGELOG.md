# Changelog

Newest first. Rule: every change adds a line here (what, why, where in the code) and bumps VERSION in
`bin/l2tp-gw` AND `bin/l2tp-gw-web`. Bugs found and their fixes go to KNOWN-ISSUES.md.

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

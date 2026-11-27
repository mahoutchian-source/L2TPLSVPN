# l2tp-gw 1.4.4 (stable)

An Ubuntu/Debian server that acts as an **L2TP/IPsec gateway** for MikroTik routers:

- **Outgoing sites:** this server dials the MikroTik (one tunnel per site).
- **Dial-in sites:** routers without a public address dial in to this server (fixed IP per site, routes, NAT, access rules).
- A **web panel** (dashboard, sites, dial-in, traffic reports, events, routes, health check, backup, settings).
- A **traffic collector** (usage, limits, auto reconnect) and a **watcher** (Telegram alerts, DDNS check, daily backup).

**For a new Claude session or a new maintainer: read `docs/PROJECT-MEMORY.md` first.**

## Install (fresh Ubuntu/Debian server, as root)

One command, always the newest version from GitHub (the same command also upgrades; settings are kept):

    curl -fsSL https://raw.githubusercontent.com/mahoutchian-source/L2TPLSVPN/main/install.sh | bash

With a settings backup (move to a new server): add `-s -- --restore /root/l2tp-gw-sites-XXXX.conf` after `bash`.
The script downloads the files, checks both programs for syntax errors and only then installs.

Or from the single installer file (no internet needed on the server):

    bash l2tp-gw-install.sh

It installs the packages, prepares the server, installs the programs and the web panel and prints the
panel password. Running it again later **upgrades** the programs and keeps all settings and tunnels.

Move to a new server with your old settings:

    bash l2tp-gw-install.sh --restore /root/l2tp-gw-sites-XXXX.conf

(the file is made by `l2tp-gw backup`, or by the web panel Backup page; the server also keeps 7 daily copies in /var/backups/l2tp-gw)

## Open the web panel

By default the panel listens only on the server itself (127.0.0.1:8080). From your computer:

    ssh -L 8080:127.0.0.1:8080 USER@SERVER_IP        then open  http://127.0.0.1:8080

To open it directly instead, set `bind = 0.0.0.0` (and `tls = on` for HTTPS) in /etc/l2tp-gw/web.conf, run
`systemctl restart l2tp-gw-web` and restrict the port in your cloud firewall to your own address.
Change the password in the panel (Settings) or with `l2tp-gw-web setpass`.

## Cloud firewall (e.g. Lightsail)

Dial-in needs UDP 500 and UDP 4500 open from anywhere. UDP 1701 is blocked by the server itself unless it arrives inside IPsec.

## Everyday commands

    l2tp-gw add | remove NAME | list | edit | apply | status | check | reconnect NAME | logs [NAME]
    l2tp-gw mtu-test NAME|ADDRESS [INTERFACE] | mtu-verify [NAME] | cut NAME | cut-all in|out
    l2tp-gw backup [FILE] | restore FILE | version
    l2tp-gw-web setpass

## More

- `docs/CHANGELOG.md` – what each version added or changed
- `docs/DEVELOPMENT.md` – where things are in the code, how to test, how to ship a change
- `docs/KNOWN-ISSUES.md` – mistakes made so far, limits and open items

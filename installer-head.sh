#!/bin/bash
# l2tp-gw @VERSION@ installer - one file: the programs are inside (after the line __PAYLOAD__).
#
#   bash l2tp-gw-install.sh                    install on a fresh Ubuntu/Debian server, or upgrade (settings are kept)
#   bash l2tp-gw-install.sh --restore FILE     also restore a settings backup (made by "l2tp-gw backup")
#   bash l2tp-gw-install.sh --no-setup         do not install packages / prepare the server (programs only)
#
# Testing only: PREFIX=/some/dir changes where programs go (default /usr/local); --no-web skips the web service.
set -euo pipefail
VERSION="@VERSION@"
PREFIX=${PREFIX:-/usr/local}
BIN="$PREFIX/bin"; DOC="$PREFIX/share/doc/l2tp-gw"
CONF_DIR=${CONF_DIR:-/etc/l2tp-gw}
RESTORE=""; DO_SETUP=1; DO_WEB=1

die() { echo "ERROR: $*" >&2; exit 1; }
say() { echo "== $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --restore) [ $# -ge 2 ] || die "--restore needs a file name"; RESTORE=$2; shift 2 ;;
    --no-setup) DO_SETUP=0; shift ;;
    --no-web) DO_WEB=0; shift ;;
    -h|--help) sed -n 2,8p "$0"; exit 0 ;;
    *) die "Unknown option: $1 (see: bash $0 --help)" ;;
  esac
done

[ "$(id -u)" -eq 0 ] || die "Run as root (type: sudo -i)"
[ -z "$RESTORE" ] || [ -f "$RESTORE" ] || die "Restore file not found: $RESTORE"
if [ "$DO_SETUP" -eq 1 ]; then
  command -v apt-get >/dev/null 2>&1 || die "This installer needs Ubuntu or Debian (apt-get was not found)."
fi

# ---- unpack the payload to a temporary folder and check it ----
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
say "Unpacking l2tp-gw $VERSION"
sed -n '/^__PAYLOAD__$/,$p' "$0" | tail -n +2 | base64 -d | tar xzf - -C "$TMP" || die "The installer file is damaged (copy it again)."
( cd "$TMP" && md5sum -c --quiet MD5SUMS ) || die "Checksum failed: the installer file is damaged (copy it again)."

# ---- install the programs (an older copy is kept in /root/l2tp-gw-old-DATE) ----
UPGRADE=0
if [ -x "$BIN/l2tp-gw" ]; then
  UPGRADE=1
  OLD=/root/l2tp-gw-old-$(date +%Y%m%d-%H%M%S); mkdir -p "$OLD"
  cp -p "$BIN/l2tp-gw" "$OLD/" ; [ -f "$BIN/l2tp-gw-web" ] && cp -p "$BIN/l2tp-gw-web" "$OLD/"
  say "Existing installation found (old programs saved in $OLD): upgrading, settings are kept"
fi
mkdir -p "$BIN" "$DOC"
install -m 755 "$TMP/bin/l2tp-gw" "$TMP/bin/l2tp-gw-web" "$BIN/"
install -m 644 "$TMP"/docs/*.md "$DOC/"
say "Programs installed in $BIN, documents in $DOC"

# ---- fresh server: packages, forwarding, NAT (l2tp-gw setup) ----
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
if [ "$DO_SETUP" -eq 1 ] && [ ! -f "$CONF_DIR/sites.conf" ]; then
  say "Preparing the server (packages, forwarding, NAT). This takes a minute"
  "$BIN/l2tp-gw" setup
elif [ "$DO_SETUP" -eq 1 ]; then
  say "Server already prepared: skipping setup"
fi

# ---- optional: restore settings from a backup file (validates it, applies it, undoes it if it fails) ----
if [ -n "$RESTORE" ]; then
  say "Restoring settings from $RESTORE"
  "$BIN/l2tp-gw" restore "$RESTORE"
fi

# ---- web panel, traffic collector and the 1-minute watch timer ----
if [ "$DO_WEB" -eq 1 ]; then
  say "Installing the web panel and the traffic collector"
  "$BIN/l2tp-gw-web" install
  "$BIN/l2tp-gw" timer || true
fi

echo
say "Done. l2tp-gw $VERSION is installed."
if [ "$UPGRADE" -eq 0 ]; then
  cat <<TXT

Next steps
  1. Open the web panel (it listens only on this server). From your computer:
       ssh -L 8080:127.0.0.1:8080 USER@THIS_SERVER_IP      then browse to  http://127.0.0.1:8080
     Log in with the password printed above (change it later in Settings).
  2. Add your sites in the panel (Sites / Dial-in) or with:  l2tp-gw add
  3. For dial-in routers open UDP 500 and 4500 in your cloud firewall.
  Help: $DOC/README.md
TXT
else
  echo "Tunnels and settings were not touched. Reload the panel with Ctrl+F5."
fi
exit 0

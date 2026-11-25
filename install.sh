#!/bin/bash
# l2tp-gw one-command installer / updater.  Run as root on Ubuntu or Debian:
#
#   curl -fsSL https://raw.githubusercontent.com/mahoutchian-source/L2TPLSVPN/main/install.sh | bash
#
# With options (restore settings from a backup file, or install only the programs):
#
#   curl -fsSL https://raw.githubusercontent.com/mahoutchian-source/L2TPLSVPN/main/install.sh | bash -s -- --restore /root/backup.conf
#   curl -fsSL https://raw.githubusercontent.com/mahoutchian-source/L2TPLSVPN/main/install.sh | bash -s -- --no-setup
#
# It downloads the newest files from the repository, checks them (syntax of both programs) and only then installs.
# Settings and tunnels of an existing server are kept. Options are passed on to the real installer
# (--restore FILE, --no-setup, --no-web). Environment: L2TPGW_REPO (owner/name), L2TPGW_REF (branch or tag, default main),
# L2TPGW_SRC (a local folder instead of the download) and L2TPGW_URL (another download address): for tests.
set -euo pipefail
REPO=${L2TPGW_REPO:-mahoutchian-source/L2TPLSVPN}
REF=${L2TPGW_REF:-main}
die() { echo "ERROR: $*" >&2; exit 1; }
say() { echo "== $*"; }

[ "$(id -u)" -eq 0 ] || die "Run as root (type: sudo -i)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

if [ -n "${L2TPGW_SRC:-}" ]; then
  [ -d "$L2TPGW_SRC/bin" ] || die "L2TPGW_SRC has no bin folder"
  mkdir -p "$T/src"; cp -r "$L2TPGW_SRC"/. "$T/src/"
  SRC=$T/src
else
  command -v curl >/dev/null 2>&1 || { command -v apt-get >/dev/null 2>&1 && apt-get install -y curl >/dev/null 2>&1; } || true
  command -v curl >/dev/null 2>&1 || die "curl is needed (apt-get install curl)"
  say "Downloading $REPO ($REF)"
  curl -fsSL --retry 3 --connect-timeout 15 -o "$T/src.tar.gz" "${L2TPGW_URL:-https://github.com/$REPO/archive/$REF.tar.gz}" \
    || die "Download failed. Check the internet connection of this server and the repository name ($REPO)."
  tar xzf "$T/src.tar.gz" -C "$T" || die "The downloaded file is damaged (try again)."
  SRC=$(find "$T" -mindepth 1 -maxdepth 1 -type d | head -n1)
  [ -n "$SRC" ] || die "The downloaded archive is empty."
fi

# ---- check before touching anything ----
for f in bin/l2tp-gw bin/l2tp-gw-web dev/make-installer.sh dev/installer-head.sh docs/CHANGELOG.md README.md; do
  [ -f "$SRC/$f" ] || die "The repository is incomplete: $f is missing. Nothing was changed."
done
bash -n "$SRC/bin/l2tp-gw" || die "bin/l2tp-gw has a syntax error. Nothing was changed."
command -v python3 >/dev/null 2>&1 && { python3 -I -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$SRC/bin/l2tp-gw-web" || die "bin/l2tp-gw-web has a syntax error. Nothing was changed."; }
V1=$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$SRC/bin/l2tp-gw")
V2=$(sed -n 's/^VERSION = "\(.*\)"/\1/p' "$SRC/bin/l2tp-gw-web")
[ -n "$V1" ] && [ "$V1" = "$V2" ] || die "The two programs have different versions (l2tp-gw=$V1, l2tp-gw-web=$V2). Nothing was changed."
say "Version $V1 downloaded and checked"

# ---- build the single-file installer from these files and run it ----
bash "$SRC/dev/make-installer.sh" "$T/l2tp-gw-install.sh" >/dev/null || die "Could not build the installer."
bash "$T/l2tp-gw-install.sh" "$@"

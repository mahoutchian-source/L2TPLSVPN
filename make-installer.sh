#!/bin/bash
# Builds ONE file, l2tp-gw-install.sh, that contains the programs and docs and installs them.
# Usage (from anywhere):  bash dev/make-installer.sh [OUTPUT_FILE]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-$ROOT/l2tp-gw-install.sh}
VER=$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$ROOT/bin/l2tp-gw")
VERW=$(sed -n 's/^VERSION = "\(.*\)"/\1/p' "$ROOT/bin/l2tp-gw-web")
[ "$VER" = "$VERW" ] || { echo "VERSION differs: l2tp-gw=$VER l2tp-gw-web=$VERW" >&2; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/p/bin" "$T/p/docs"
cp "$ROOT"/bin/l2tp-gw "$ROOT"/bin/l2tp-gw-web "$T/p/bin/"
cp "$ROOT"/README.md "$ROOT"/docs/*.md "$T/p/docs/"
( cd "$T/p" && find . -type f ! -name MD5SUMS | sort | xargs md5sum > MD5SUMS )
{ sed "s/@VERSION@/$VER/g" "$ROOT/dev/installer-head.sh"; echo "__PAYLOAD__"; tar czf - -C "$T/p" . | base64; } > "$OUT"
chmod 755 "$OUT"
echo "Built $OUT  (version $VER)  $(wc -c < "$OUT") bytes  md5 $(md5sum < "$OUT" | cut -d' ' -f1)"

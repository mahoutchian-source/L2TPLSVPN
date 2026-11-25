#!/bin/bash
# Builds ONE file, l2tp-gw-install.sh, that contains the programs and docs and installs them.
# Works with two layouts: FLAT (every file in one folder, the way the repository is kept now) and
# FOLDERS (bin/, docs/, dev/ - the older layout). Usage:  bash make-installer.sh [OUTPUT_FILE]
set -euo pipefail
D=$(cd "$(dirname "$0")" && pwd)
if [ -f "$D/l2tp-gw" ]; then        # flat
  ROOT=$D; BIN=$D; DOCS=$D; HEAD=$D/installer-head.sh
elif [ -f "$D/../bin/l2tp-gw" ]; then   # folders (this script is in dev/)
  ROOT=$(cd "$D/.." && pwd); BIN=$ROOT/bin; DOCS=$ROOT/docs; HEAD=$D/installer-head.sh
else
  echo "Cannot find l2tp-gw next to this script or in ../bin" >&2; exit 1
fi
OUT=${1:-$ROOT/l2tp-gw-install.sh}
VER=$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$BIN/l2tp-gw")
VERW=$(sed -n 's/^VERSION = "\(.*\)"/\1/p' "$BIN/l2tp-gw-web")
[ "$VER" = "$VERW" ] || { echo "VERSION differs: l2tp-gw=$VER l2tp-gw-web=$VERW" >&2; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/p/bin" "$T/p/docs"
cp "$BIN"/l2tp-gw "$BIN"/l2tp-gw-web "$T/p/bin/"
cp "$ROOT"/README.md "$T/p/docs/"
for f in CHANGELOG.md DEVELOPMENT.md KNOWN-ISSUES.md PROJECT-MEMORY.md; do cp "$DOCS/$f" "$T/p/docs/"; done
( cd "$T/p" && find . -type f ! -name MD5SUMS | sort | xargs md5sum > MD5SUMS )
{ sed "s/@VERSION@/$VER/g" "$HEAD"; echo "__PAYLOAD__"; tar czf - -C "$T/p" . | base64; } > "$OUT"
chmod 755 "$OUT"
echo "Built $OUT  (version $VER)  $(wc -c < "$OUT") bytes  md5 $(md5sum < "$OUT" | cut -d' ' -f1)"

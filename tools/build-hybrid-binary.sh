#!/bin/bash
# build-hybrid-binary.sh — Phase 9: produce the Racket-Zig hybrid binary bundle.
#
# Steps:
#   1. Build runtime/libprologos-runtime-hybrid.so via zig build-lib
#   2. Compile racket/prologos/preduce-hybrid-main.rkt via raco exe
#   3. Bundle via raco distribute into dist/prologos-hybrid/
#   4. Copy libprologos-runtime-hybrid.so into dist/prologos-hybrid/lib/
#   5. Smoke-test the bundle against examples/preduce-lite/01-int-add.prologos
#
# Output: dist/prologos-hybrid/  — directory bundle that ships the
# Racket runtime + the user's compiled program + the Zig kernel .so.
# Run: dist/prologos-hybrid/bin/prologos-hybrid <PROGRAM.prologos>
#
# Usage: tools/build-hybrid-binary.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

RACKET="${RACKET:-/home/user/racket-src/racket/bin/racket}"
RACO="${RACO:-/home/user/racket-src/racket/bin/raco}"
ZIG="${ZIG:-/usr/local/lib/python3.11/dist-packages/ziglang/zig}"

echo "[1/5] Building Zig kernel: runtime/libprologos-runtime-hybrid.so"
(cd runtime && "$ZIG" build-lib -dynamic prologos-runtime-hybrid.zig -O ReleaseFast)

echo "[2/5] Building Racket executable: racket/prologos/preduce-hybrid-main.rkt"
mkdir -p dist
"$RACO" exe \
  --orig-exe \
  -o dist/prologos-hybrid \
  racket/prologos/preduce-hybrid-main.rkt

echo "[3/5] Distributing into dist/prologos-hybrid-bundle/"
rm -rf dist/prologos-hybrid-bundle
"$RACO" distribute dist/prologos-hybrid-bundle dist/prologos-hybrid

echo "[4/6] Copying Zig kernel .so into bundle"
mkdir -p dist/prologos-hybrid-bundle/lib
cp runtime/libprologos-runtime-hybrid.so dist/prologos-hybrid-bundle/lib/

echo "[5/6] Copying prologos standard library into bundle (share/prologos/lib/)"
mkdir -p dist/prologos-hybrid-bundle/share/prologos
cp -r racket/prologos/lib dist/prologos-hybrid-bundle/share/prologos/lib

echo "[6/6] Writing launcher script: dist/prologos-hybrid-bundle/bin/prologos"
cat > dist/prologos-hybrid-bundle/bin/prologos <<'LAUNCHER'
#!/bin/bash
# Launcher for the Racket-Zig hybrid Prologos binary.
# Sets LD_LIBRARY_PATH so ffi-lib finds libprologos-runtime-hybrid.so,
# and PROLOGOS_LIB_DIR so driver.rkt finds the standard library.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export LD_LIBRARY_PATH="$DIR/lib:${LD_LIBRARY_PATH:-}"
export PROLOGOS_LIB_DIR="$DIR/share/prologos/lib"
exec "$DIR/bin/prologos-hybrid" "$@"
LAUNCHER
chmod +x dist/prologos-hybrid-bundle/bin/prologos

echo
echo "=== Bundle built: dist/prologos-hybrid-bundle/ ==="
echo
ls -la dist/prologos-hybrid-bundle/bin dist/prologos-hybrid-bundle/lib
echo
echo "Smoke test:"
echo "  dist/prologos-hybrid-bundle/bin/prologos racket/prologos/examples/preduce-lite/01-int-add.prologos"

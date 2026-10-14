#!/bin/sh
# Build nexts.nex, run it headless in zx_go's test harness, verify against expected images.
# Needs: sjasmplus, Go, python3 + Pillow, a zx_go checkout with cmd/nexts_run
#   (branch nexts-headless-runner) and the Next ROMs installed for zx_go.
set -e
cd "$(dirname "$0")/.."
SJASM=${SJASM:-sjasmplus}
ZXGO=${ZXGO:-../zx_go-nexts}
OUT=${OUT:-build/run}
mkdir -p build "$OUT"
(cd src && "$SJASM" --zxnext --nologo nexts.asm)
(cd "$ZXGO" && go build -o "$OLDPWD/build/nexts_run" ./cmd/nexts_run)
./build/nexts_run -nex build/nexts.nex -out "$OUT" -frames "${FRAMES:-600}" > "$OUT/results.json"
python3 tools/verify.py "$OUT" | tee "$OUT/report.md"

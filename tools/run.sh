#!/bin/sh
# Build nexts.nex, run it headless in zx_go with the GUI compositor
# (zx_go --nexts-run, branch nexts-headless-runner), verify against expected images.
set -e
cd "$(dirname "$0")/.."
SJASM=${SJASM:-sjasmplus}
ZXGO=${ZXGO:-../zx_go-nexts}
OUT=${OUT:-build/run}
mkdir -p build "$OUT"
(cd src && "$SJASM" --zxnext --nologo nexts.asm)
(cd "$ZXGO" && go build -o "$OLDPWD/build/zx_go_nexts" ./cmd/zx_go)
./build/zx_go_nexts -nexts-run build/nexts.nex -nexts-out "$OUT" -nexts-frames "${FRAMES:-600}"
python3 tools/verify.py "$OUT" | tee "$OUT/report.md"

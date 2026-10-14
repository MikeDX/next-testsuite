#!/usr/bin/env python3
"""Generate doc-derived expected images for the visual phases of nexts.nex and
compare them against screenshots captured by a runner.

Expected pixels come ONLY from the rules quoted in manifest.json (wiki.specnext.dev).
No emulator is consulted. Colours are compared at RGB333 precision: an actual
8-bit channel v is quantised as round(v*7/255) (the 3-bit -> 8-bit DAC curve is
not documented, so this is the least-assumption comparison).

Usage: verify.py RUN_DIR [--gen-only]
  RUN_DIR holds phase_XX.png (320x240, display at x=32,y=24) and results.json.
"""
import json, os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
EXP = os.path.join(ROOT, "expected")
DX, DY = 32, 24          # display origin inside the runner screenshot (zx_go harness frame)

def rgb333(c8):
    """NR $41: RRRGGGBB, 'the lower blue bit of the 9-bit colour will be a logical OR of blue bits 1 and 0'"""
    r, g, b2 = (c8 >> 5) & 7, (c8 >> 2) & 7, c8 & 3
    return (r, g, (b2 << 1) | (1 if b2 else 0))

def to8(c333):
    return tuple(round(v * 255 / 7) for v in c333)

RED, GREEN, BLUE = 0xE0, 0x1C, 0x03
COL40 = [(c * 37 + 5) & 0xFF for c in range(40)]
SPR_PAL = [((o * 61 + i * 29 + 7) & 0xFF) for o in range(4) for i in range(16)]

def img(fn):
    """fn(xd, yd) -> 8-bit colour or a set of acceptable colours, or None (don't care)"""
    return [[fn(x, y) for x in range(256)] for y in range(192)]

def phase11(x, y): return RED if x < 128 else GREEN
def phase12(x, y): return BLUE if x < 128 else GREEN
def phase13(x, y): return RED

def scroll_col(xs, off, direction):
    return (((xs + off) if direction > 0 else (xs - off)) % 320) // 8

def phase2(clip, direction):
    def f(x, y):
        xs, ys = x + 32, y + 32
        if clip and not (40 <= xs <= 279 and 40 <= ys <= 215):
            return RED
        return COL40[scroll_col(xs, 264, direction)]
    return f

PAT = [[(6 if (r == 0 and c == 0) else (1 if r < 8 and c < 8 else 2 if r < 8 else 4 if c < 8 else 5))
        for c in range(16)] for r in range(16)]

def phase31(x, y):
    for i, (xm, ym) in enumerate([(0, 0), (1, 0), (0, 1), (1, 1)]):
        sx, sy = 16 + 32 * i, 16
        if sx <= x < sx + 16 and sy <= y < sy + 16:
            c, r = x - sx, y - sy
            if xm: c = 15 - c
            if ym: r = 15 - r
            return SPR_PAL[i * 16 + PAT[r][c]]
    return RED

PHASES = {
    "11": ("test1", phase11), "12": ("test1", phase12), "13": ("test1", phase13),
    "21a": ("test2", phase2(False, +1)), "21b": ("test2", phase2(False, -1)),
    "22a": ("test2", phase2(True, +1)), "22b": ("test2", phase2(True, -1)),
    "31": ("test3", phase31),
}

def gen():
    os.makedirs(EXP, exist_ok=True)
    grids = {}
    for k, (_, fn) in PHASES.items():
        g = img(fn)
        grids[k] = g
        im = Image.new("RGB", (256, 192))
        im.putdata([to8(rgb333(g[y][x])) for y in range(192) for x in range(256)])
        im.save(os.path.join(EXP, f"phase_{k}.png"))
    return grids

def compare(grid, shot, ula_only=None):
    """returns (total mismatches, mismatches where expected pixel is NOT the ULA colour)"""
    bad = nonula = 0
    for y in range(192):
        for x in range(256):
            a = shot.getpixel((DX + x, DY + y))[:3]
            q = tuple(round(v * 7 / 255) for v in a)
            if q != rgb333(grid[y][x]):
                bad += 1
                if grid[y][x] != RED or ula_only:
                    nonula += 1
    return bad, nonula

def main():
    grids = gen()
    if len(sys.argv) < 2 or "--gen-only" in sys.argv:
        return
    run = sys.argv[1]
    rows = []
    def shot(p):
        f = os.path.join(run, f"phase_{p}.png")
        return Image.open(f).convert("RGB") if os.path.exists(f) else None
    for p in ["11", "12", "13", "21", "22", "31"]:
        s = shot(p)
        if s is None:
            rows.append((p, "not captured", "")); continue
        if p in ("21", "22"):
            (ba, na), (bb, nb) = compare(grids[p + "a"], s), compare(grids[p + "b"], s)
            v = "PASS" if min(ba, bb) == 0 else "FAIL"
            note = f"mismatch px: dir+ {ba} ({na} non-ULA), dir- {bb} ({nb} non-ULA); scroll direction undocumented, either accepted"
        else:
            b, n = compare(grids[p], s)
            v = "PASS" if b == 0 else "FAIL"
            note = f"mismatch px: {b} / 49152 ({n} where expected is not ULA $E0)"
        rows.append((p, v, note))
    res = json.load(open(os.path.join(run, "results.json")))
    print("| phase | verdict | note |\n|---|---|---|")
    for r in rows: print(f"| {r[0]} | {r[1]} | {r[2]} |")
    print("\n| test | result byte | detail |\n|---|---|---|")
    names = {0: "not run", 1: "PASS", 2: "FAIL", 3: "visual (see phases)"}
    for r in res["results"]:
        print(f"| {r['test']} | {r['result']} ({names.get(r['result'], '?')}) | 0x{r['detail']:02X} |")

if __name__ == "__main__":
    main()

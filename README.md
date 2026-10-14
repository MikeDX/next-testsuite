# next-testsuite

A small ZX Spectrum Next SDK (sjasmplus assembler) and a hardware test `.nex`
whose expected results are derived **only** from the official Next documentation
(see `REFERENCES.md`). Its job is to find gaps in emulators such as zx_go and to
make games that rely on documented behaviour.

Synthetic patterns only. No ROMs or ROM-derived data are in this repository.

## Layout
- `sdk/next.inc`, `sdk/next.asm`: NextReg read/write, palette, clip, tilemap, sprites, layer 2
- `src/nexts.asm`: the test program, which builds `build/nexts.nex`
- `tools/verify.py`: makes the doc-derived expected images in `expected/` and compares screenshots against them
- `tools/run.sh`: builds, runs headless in zx_go, then verifies
- `manifest.json`: tests, phases, expected images and doc quotes

## Results table (fixed RAM, bank 2)
| addr | meaning |
|---|---|
| $8000 | `NXTS` magic |
| $8004 | version (1) |
| $8005 | number of tests |
| $8006 | visual phase currently on screen ($11,$12,$13,$21,$22,$31; $FF = finished) |
| $8007 | ack: a headless runner writes the phase id here after capturing it (on hardware each phase times out after about 2 s) |
| $8010+2(n-1) | result for test n: 0 not run, 1 pass, 2 fail, 3 visual (verdict from expected images) |
| $8011+2(n-1) | detail byte |

The final screen shows one 2-cell block per test on attribute row 0, starting at
column 2: green = pass, red = fail, white = visual, black = not run.

## Running
    make                       # needs sjasmplus
    ZXGO=../zx_go-nexts tools/run.sh

`cmd/nexts_run` lives on the zx_go branch `nexts-headless-runner`. It uses zx_go's
`pkg/testharness` with LoadNEX, RunFrames and SaveScreenshot, and prints the table as JSON.

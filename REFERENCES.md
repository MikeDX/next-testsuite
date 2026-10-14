# References

Rule: **only official ZX Spectrum Next documentation decides expected behaviour.**
No emulator (zx_go, CSpect, ZEsarUX, MAME, nexrun) or emulator source was used to
derive any expected value. zx_go is only the device under test. Where the docs are
silent the item is marked **undocumented** and the test accepts every reading the
docs allow (or does not check it).

## Sources

| Source | URL | Used for |
|---|---|---|
| SpecNext wiki – Tilemap | https://wiki.specnext.dev/Tilemap | NR $6B, $6C, $1B, $2F, $30, $31, $43, $68, tile attributes |
| SpecNext wiki – Clip Window Tilemap Register | https://wiki.specnext.dev/Clip_Window_Tilemap_Register | NR $1B coordinate system, doubling, inclusivity, read behaviour |
| SpecNext wiki – Tilemap Transparency Index Register | https://wiki.specnext.dev/Tilemap_Transparency_Index_Register | NR $4C |
| SpecNext wiki – Tilemap Base Address Register | https://wiki.specnext.dev/Tilemap_Base_Address_Register | NR $6E address + read-back |
| SpecNext wiki – Tile Definitions Base Address Register | https://wiki.specnext.dev/Tile_Definitions_Base_Address_Register | NR $6F |
| SpecNext wiki – Fallback Colour Register | https://wiki.specnext.dev/Fallback_Colour_Register | NR $4A |
| SpecNext wiki – Sprites | https://wiki.specnext.dev/Sprites | 4-bit patterns, palette offset, attr 2/3/4, ports $303B/$57/$5B, NR $15, $19, $41, $43, $4B, coordinates |
| Official distro (tbblue) docs, incl. nextreg list | https://gitlab.com/thesmog358/tbblue (docs/) | Primary source the wiki pages are written from. Not yet cross-checked line by line in milestone 1. |
| sjasmplus (toolchain, `SAVENEX`, Z80N `nextreg`) | https://github.com/z00m128/sjasmplus | Assembler / .nex writer only, no behaviour |

Toolchain choice: sjasmplus 1.20.3 (already on the M2) because it writes .nex files
natively (`SAVENEX`) and assembles Z80N opcodes; z88dk is not installed and is not
needed for an assembler-only SDK. A z88dk C binding can be added later.

## Register semantics each test relies on (quoted)

### Shared set-up
- NR $41: "Format is RRRGGGBB – the lower blue bit of the 9-bit colour will be a logical OR of blue bits 1 and 0 of this 8-bit value." (Sprites page) – used to compute every expected RGB333 colour.
- NR $43: "bits 6-4: Select palette for reading or writing: 000 = ULA first palette … 010 = Sprites first palette … 011 = Tilemap first palette" (Tilemap page). Every palette entry a test uses is programmed explicitly; **no default palette is assumed**.
- NR $40 (ULA): "INKs are mapped to indices 0-7 … PAPERs to indices 16-23" (Sprites page). Test ULA screen = ink 2/paper 2, both programmed to $E0.
- NR $15: "bit 0 = Sprites visible (1 = visible)", "000 – S L U" (Sprites page).
- **Undocumented:** the 3-bit → 8-bit DAC curve. The verifier compares at RGB333 precision (actual 8-bit value quantised with round(v·7/255)).

### Test 1 – tilemap compositing, NR $68 bit 7, attribute bit 0
- NR $6B: "bit 7: 0=disable tilemap, 1=enable tilemap", "bit 6: 0=40x32", "bit 5: 0=attributes in tilemap", "bit 1: 0=256 tile mode", "bit 0: 1=tilemap over ULA". Value used $81.
- NR $6E: "offset into 16K bank 5 … placed at any multiple of 256 bytes" → $2C = $6C00. NR $6F likewise → $20 = $6000.
- Tile description: "Each tile description is a 32 byte block of 4-bit values describing the indices of each pixel of a tile in row major order."
- NR $4C: "The pixel index (bottom 4 bits) from tile graphics is compared before the palette offset is applied" (value $0F → tile 0, all index 15, is transparent).
- Tile attribute: "bit 0: In 256-tile mode ULA over tilemap".
- NR $68: "bit 7: 1 to disable ULA output".
- NR $4A: "8-bit colour to be used when all layers contain transparent pixel." (set to $03).
- Clip NR $1B: "origin [0,0] is 32 pixels left and above the top-left ULA pixel" → tilemap column c covers ULA x = 8c-32.
- Expected: 1a ($68=$00) left half $E0 (ULA through transparent tile), right half $1C. 1b ($68=$80) left half $03 fallback, right $1C. 1c (attr bit 0 set on right half) whole display $E0.

### Test 2 – 9-bit X scroll + clip window
- NR $2F: "bits 1-0: MSB X Offset. Meaningful Range is 0-319 in 40 char mode"; NR $30: "bits 7-0: LSB X Offset". Offset written: 264 ($2F=1, $30=8) – the 9th bit matters (264 ≠ 8).
- Tile attribute: "bits 7-4: palette offset" – each of the 40 columns gets a unique palette entry.
- **Undocumented:** the scroll direction (whether offset N shows map pixel x+N or x−N at screen x). The verifier accepts either direction; both differ from the 8-bit-truncated offset, so the 9th-bit check stays meaningful.
- NR $1B: "The X coordinates are internally doubled (40x32 mode)", "The displayed area is 'inclusive', i.e. for default values full 320x256 … is displayed" with defaults "0,159,0,255". Hence visible x = 2·X1 … 2·X2+1, y = Y1 … Y2, in the 320×256 origin. Clip used 20,139,40,215 → x 40…279, y 40…215; outside, tilemap is absent and ULA ($E0) shows.
- NR $1C: "bit 3 – reset the tilemap clip index".

### Test 3 – 4-bit sprites, palette offset, X/Y mirror
- "The leftmost pixel is stored in the upper 4-bits and the rightmost pixel is stored in the lower 4-bits."; "These 128 bytes would be stored in pattern memory in left to right, top to bottom order."
- Palette offset: "4-bit Sprite PPPP0000 + 0000IIII = PPPPIIII".
- Attribute 2: "P P P P XM YM R X8/PR … XM = 1 to mirror the sprite image horizontally YM = 1 to mirror the sprite image vertically".
- Attribute 3: "V = 1 to make the sprite visible E = 1 to enable attribute byte 4".
- Attribute 4: "H = 1 if the sprite pattern is 4-bit N6 = 7th pattern bit".
- NR $4B: "For 4-bit sprites only the bottom 4-bits are relevant." (set $E3 → index 3 transparent; pattern does not use 3).
- Coordinates: "sprite position is always in sprite coordinates with 32,32 corresponding to the top left corner of the ULA screen."
- Expected: four sprites at ULA (16+32i, 16), offsets 0–3, mirror none/X/Y/XY; quadrant indices 1/2/4/5 with a single index-6 marker pixel at pattern (0,0).

### Test 4 – NR $6E read-back (CPU self-check)
- "upon writing value $45 the read of this register will produce value $05". Detail byte = value read.

### Test 5 – NR $1B read does not advance (CPU self-check)
- "Read from register will only read currently selected coordinate, index is not modified (to read next coordinate, write the current coordinate value back, to increment index)." Detail bits: 0 first read ≠ X1, 1 second read ≠ X1, 2 read after write-back ≠ X2.

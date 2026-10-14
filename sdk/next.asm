; next.asm - minimal ZX Spectrum Next SDK routines
; All routines preserve nothing unless stated. Z80N 'nextreg' used for writes.

; nr_read: A = register number -> A = value (port interface)
nr_read:
        push bc
        ld bc,NR_SEL
        out (c),a
        inc b                   ; $253B
        in a,(c)
        pop bc
        ret

; nr_write: A = register, E = value
nr_write:
        push bc
        ld bc,NR_SEL
        out (c),a
        inc b
        out (c),e
        pop bc
        ret

; pal_load: A = NR$43 select value, E = first index, HL = src, B = count
; writes 8-bit RRRGGGBB colours via NR $41 (auto-increment)
pal_load:
        nextreg NR_PAL_CTRL,a   ; z80n: nextreg reg,a
        ld a,e
        nextreg NR_PAL_IDX,a
.l:     ld a,(hl)
        nextreg NR_PAL_VAL8,a
        inc hl
        djnz .l
        ret

; pal_set1: A = NR$43 select, E = index, D = colour
pal_set1:
        nextreg NR_PAL_CTRL,a
        ld a,e
        nextreg NR_PAL_IDX,a
        ld a,d
        nextreg NR_PAL_VAL8,a
        ret

; clip_set: A = clip register ($18/$19/$1A/$1B), HL -> 4 bytes x1,x2,y1,y2
; resets all clip indices first via NR $1C ($0F)
clip_set:
        nextreg NR_CLIP_CTRL,$0F
        ld b,4
        ld c,a
.l:     ld a,c
        ld e,(hl)
        call nr_write
        inc hl
        djnz .l
        ret

; tm_setup: A = NR$6B control value. Map at $6C00 (NR$6E=$2C), tiles at $6000 (NR$6F=$20)
tm_setup:
        nextreg NR_TM_BASE,$2C
        nextreg NR_TM_TILES,$20
        nextreg NR_TM_CTRL,a
        ret

; tm_scroll: HL = 9/10-bit X offset, A = Y offset
tm_scroll:
        nextreg NR_TM_Y,a
        ld a,h
        and 3
        nextreg NR_TM_XMSB,a
        ld a,l
        nextreg NR_TM_XLSB,a
        ret

; spr_pattern: A = port $303B value (pattern slot), HL = src, BC = byte count
spr_pattern:
        push bc
        ld bc,SPR_SEL
        out (c),a
        pop de
.l:     ld a,(hl)
        out (SPR_PAT),a
        inc hl
        dec de
        ld a,d
        or e
        jr nz,.l
        ret

; spr_attrs: A = first sprite, HL = src, B = byte count (4/5 per sprite)
spr_attrs:
        push bc
        ld bc,SPR_SEL
        out (c),a
        pop bc
.l:     ld a,(hl)
        out (SPR_ATTR),a
        inc hl
        djnz .l
        ret

; l2_setup: A = 16K bank for layer 2 (NR $12); enables layer 2 display
l2_setup:
        nextreg NR_L2_BANK,a
        ld bc,L2_PORT
        ld a,$02                ; bit 1 = layer 2 visible
        out (c),a
        ret

; l2_off
l2_off:
        ld bc,L2_PORT
        xor a
        out (c),a
        ret

; fill: HL = dst, BC = count, A = value
fill:
        ld (hl),a
        dec bc
        ld a,b
        or c
        ret z
        ld d,h
        ld e,l
        inc de
        ldir
        ret

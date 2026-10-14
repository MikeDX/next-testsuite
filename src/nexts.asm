; nexts.asm - ZX Spectrum Next hardware test suite, milestone 1
; Build: sjasmplus --zxnext --nologo src/nexts.asm   (writes build/nexts.nex)
; Results table (see README.md):
;   $8000 'NXTS'  $8004 version  $8005 test count
;   $8006 phase   (visual phase currently on screen, $FF = finished)
;   $8007 ack     (headless runner writes the phase id here when it has captured it)
;   $8010+2*(n-1) result byte (0 not run, 1 pass, 2 fail, 3 done-visual: verdict from manifest)
;   $8011+2*(n-1) detail byte
        DEVICE ZXSPECTRUMNEXT
        include "../sdk/next.inc"

RESULTS equ $8000
PHASE   equ $8006
ACK     equ $8007
NTESTS  equ 5
TILES   equ $6000
TMAP    equ $6C00

        org RESULTS
        db "NXTS", 1, NTESTS, 0, 0
        ds 8, 0
        ds NTESTS*2, 0

        org $8100
start:
        di
        ld sp,$BFF0
        nextreg NR_CPU_SPEED,0
        call reset_video
        call ula_init
        call tiles_init

        call test1_tm_composite
        call test2_tm_scroll_clip
        call test3_sprites
        call test4_nr6e_readback
        call test5_nr1b_noadvance

        call summary
        ld a,$FF
        ld (PHASE),a
.hang:  jr .hang

; ---------------------------------------------------------------
; result helpers: A = test number (1..), D = result, E = detail
set_result:
        dec a
        add a,a
        ld l,a
        ld h,0
        ld bc,RESULTS+$10
        add hl,bc
        ld (hl),d
        inc hl
        ld (hl),e
        ret

; show_phase: A = phase id. Publishes it and waits for runner ack or timeout (~2 s @3.5MHz)
show_phase:
        ld (PHASE),a
        ld c,a
        ld b,8
.outer: ld hl,0
.inner: ld a,(ACK)
        cp c
        ret z
        dec hl
        ld a,h
        or l
        jr nz,.inner
        djnz .outer
        ret

; ---------------------------------------------------------------
reset_video:
        call l2_off
        nextreg NR_SPR_LAYERS,$00       ; sprites off, SLU, no border
        nextreg NR_TM_CTRL,$00          ; tilemap off
        nextreg NR_ULA_CTRL,$00         ; ULA on, no stencil
        nextreg NR_GLOBAL_TRANS,$E3
        nextreg NR_TM_TRANS,$0F
        nextreg NR_SPR_TRANS,$E3
        nextreg NR_FALLBACK,$03         ; blue
        nextreg NR_TM_ATTR,$00
        ld hl,0
        xor a
        call tm_scroll
        ld a,NR_CLIP_TM
        ld hl,clip_tm_full
        call clip_set
        ld a,NR_CLIP_SPR
        ld hl,clip_spr_full
        call clip_set
        ld a,NR_CLIP_ULA
        ld hl,clip_spr_full
        call clip_set
        ret
clip_tm_full:   db 0,159,0,255
clip_spr_full:  db 0,255,0,191
clip_tm_test:   db 20,139,40,215

; ULA: bitmap 0, every attribute = $10|2 (paper red, ink red). ULA palette programmed.
ula_init:
        ld a,PAL_ULA1
        ld e,0
        ld hl,ula_pal
        ld b,8
        call pal_load
        ld a,PAL_ULA1
        ld e,16
        ld hl,ula_pal
        ld b,8
        call pal_load
        ld hl,$4000
        ld bc,6144
        xor a
        call fill
        ld hl,$5800
        ld bc,768
        ld a,$12
        call fill
        xor a
        out ($FE),a
        ret
ula_pal: db $00,$03,$E0,$C3,$1C,$1F,$FC,$FF   ; black blue red mag(not E3) green cyan yellow white

; tiles: 0 = all index 15 (transparent), 1 = all 1, 2..6 = all index (n-1) ... see manifest
tiles_init:
        ld hl,TILES
        ld bc,32
        ld a,$FF
        call fill
        ld b,1
.t:     push bc
        ld a,b
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,TILES
        add hl,de               ; HL = tile b
        ld a,b
        rlca
        rlca
        rlca
        rlca
        or b                    ; both nibbles = b
        ld bc,32
        call fill
        pop bc
        inc b
        ld a,b
        cp 6
        jr nz,.t
        ; tilemap palette: index 1 = green
        ld a,PAL_TM1
        ld e,1
        ld d,$1C
        call pal_set1
        ret

; map_fill_halves: tile 0 for cols 0..19, tile 1 for cols 20..39; E = attr for right half
map_halves:
        ld hl,TMAP
        ld c,32
.row:   ld b,20
.l1:    ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        djnz .l1
        ld b,20
.l2:    ld (hl),1
        inc hl
        ld (hl),e
        inc hl
        djnz .l2
        dec c
        jr nz,.row
        ret

; ---------------------------------------------------------------
; Test 1: tilemap compositing + NR $68 bit 7 + attr bit 0 (ULA over tilemap)
test1_tm_composite:
        ld e,0
        call map_halves
        ld a,$81                ; enable, 40x32, attrs, primary pal, 256 tiles, tilemap over ULA
        call tm_setup
        ld a,$11
        call show_phase         ; 1a: left red (ULA), right green
        nextreg NR_ULA_CTRL,$80
        ld a,$12
        call show_phase         ; 1b: left blue (fallback), right green
        nextreg NR_ULA_CTRL,$00
        ld e,$01
        call map_halves
        ld a,$13
        call show_phase         ; 1c: all red (ULA over tilemap on right)
        ld a,1
        ld d,3
        ld e,3                  ; 3 visual phases
        call set_result
        nextreg NR_TM_CTRL,0
        ret

; ---------------------------------------------------------------
; Test 2: 9-bit X scroll (264) + clip window
; map column c: tile (c mod 5)+1, attr palette offset (c div 5) << 4
; tilemap palette entry off*16+t = colour table entry c
test2_tm_scroll_clip:
        ; palette
        ld ix,col40
        ld c,0                  ; c = column
.pal:   ld a,c
        call col_index          ; A = palette index for column c
        ld e,a
        ld d,(ix+0)
        ld a,PAL_TM1
        push bc
        call pal_set1
        pop bc
        inc ix
        inc c
        ld a,c
        cp 40
        jr nz,.pal
        ; map
        ld hl,TMAP
        ld b,32
.row:   push bc
        ld c,0
.col:   ld a,c
        call col_index          ; A = off<<4 | t
        ld d,a
        and $0F
        ld (hl),a               ; tile number t (1..5)
        inc hl
        ld a,d
        and $F0
        ld (hl),a               ; attribute: palette offset
        inc hl
        inc c
        ld a,c
        cp 40
        jr nz,.col
        pop bc
        djnz .row
        ld a,$81
        call tm_setup
        ld hl,264
        xor a
        call tm_scroll
        ld a,$21
        call show_phase         ; 2a: full clip
        ld a,NR_CLIP_TM
        ld hl,clip_tm_test
        call clip_set
        ld a,$22
        call show_phase         ; 2b: clip 20,139,40,215
        ld a,2
        ld d,3
        ld e,2
        call set_result
        nextreg NR_TM_CTRL,0
        ld hl,0
        xor a
        call tm_scroll
        ld a,NR_CLIP_TM
        ld hl,clip_tm_full
        call clip_set
        ret

; col_index: A = column 0..39 -> A = (c div 5)<<4 | ((c mod 5)+1)
col_index:
        ld b,0
.d:     cp 5
        jr c,.m
        sub 5
        inc b
        jr .d
.m:     inc a
        ld d,a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        or d
        ret

; colour per column: (vc*37+5) & $FF  (distinct for c<40), RRRGGGBB
col40:
vc DEFL 0
        DUP 40
        db (vc*37+5) & $FF
vc DEFL vc+1
        EDUP

; ---------------------------------------------------------------
; Test 3: 4-bit sprites, palette offsets 0..3, mirrors none/X/Y/XY
test3_sprites:
        ld a,0                  ; pattern slot 0 (N6=0)
        ld hl,pat4
        ld bc,128
        call spr_pattern
        ld a,PAL_SPR1
        ld e,0
        ld hl,spr_pal
        ld b,64
        call pal_load
        ld a,0
        ld hl,spr_attr
        ld b,20
        call spr_attrs
        nextreg NR_SPR_LAYERS,$01
        ld a,$31
        call show_phase
        ld a,3
        ld d,3
        ld e,1
        call set_result
        nextreg NR_SPR_LAYERS,$00
        ret

; 16x16 4-bit pattern: TL quadrant idx1, TR idx2, BL idx4, BR idx5, plus idx6 at pixel (0,0)
pat4:
        db $61,$11,$11,$11,$22,$22,$22,$22
        DUP 7
        db $11,$11,$11,$11,$22,$22,$22,$22
        EDUP
        DUP 8
        db $44,$44,$44,$44,$55,$55,$55,$55
        EDUP

; sprite palette 0..63: offset o (0..3) entry i -> spr_pal[o*16+i]
spr_pal:
vo DEFL 0
        DUP 4
vi DEFL 0
        DUP 16
        db ((vo*61 + vi*29 + 7) & $FF)
vi DEFL vi+1
        EDUP
vo DEFL vo+1
        EDUP

; 5-byte attrs: X, Y, P|XM|YM|R|X8, V|E|N, H|N6|T|XX|YY|Y8
spr_attr:
        db 32+16,  32+16, $00, $C0, $80    ; off 0, no mirror
        db 32+48,  32+16, $18, $C0, $80    ; off 1, X mirror
        db 32+80,  32+16, $24, $C0, $80    ; off 2, Y mirror
        db 32+112, 32+16, $3C, $C0, $80    ; off 3, X+Y mirror

; ---------------------------------------------------------------
; Test 4: NR $6E read-back. Doc: "upon writing value $45 the read of this register will produce value $05"
test4_nr6e_readback:
        nextreg NR_TM_BASE,$45
        ld a,NR_TM_BASE
        call nr_read
        ld e,a
        ld d,1
        cp $05
        jr z,.ok
        ld d,2
.ok:    ld a,4
        call set_result
        nextreg NR_TM_BASE,$2C
        ret

; ---------------------------------------------------------------
; Test 5: NR $1B reads do not advance the index; writing back advances it.
; detail: bit0 first read wrong, bit1 second read wrong, bit2 read after write-back wrong
test5_nr1b_noadvance:
        nextreg NR_CLIP_CTRL,$08        ; reset tilemap clip index
        nextreg NR_CLIP_TM,10
        nextreg NR_CLIP_TM,150
        nextreg NR_CLIP_TM,30
        nextreg NR_CLIP_TM,200
        nextreg NR_CLIP_CTRL,$08
        ld c,0
        ld a,NR_CLIP_TM
        call nr_read
        cp 10
        jr z,.r2
        set 0,c
.r2:    ld a,NR_CLIP_TM
        call nr_read
        cp 10
        jr z,.r3
        set 1,c
.r3:    nextreg NR_CLIP_TM,10
        ld a,NR_CLIP_TM
        call nr_read
        cp 150
        jr z,.r4
        set 2,c
.r4:    ld e,c
        ld d,1
        ld a,c
        or a
        jr z,.ok
        ld d,2
.ok:    ld a,5
        call set_result
        ld a,NR_CLIP_TM
        ld hl,clip_tm_full
        call clip_set
        ret

; ---------------------------------------------------------------
; Summary: attribute row 0, test n at columns 2n..2n+1:
;   green paper = pass, red = fail, white = visual (see runner), black = not run
summary:
        call reset_video
        ld hl,$5800
        ld bc,768
        ld a,$00                ; all black
        call fill
        ld ix,RESULTS+$10
        ld hl,$5802
        ld b,NTESTS
.l:     ld a,(ix+0)
        push hl
        ld hl,sum_attr
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        inc ix
        inc ix
        djnz .l
        ret
sum_attr: db $00, $20, $10, $38          ; not run, pass(green), fail(red), visual(white)

        include "../sdk/next.asm"

        SAVENEX OPEN "../build/nexts.nex", start, $BFF0
        SAVENEX CORE 3,0,0
        SAVENEX AUTO
        SAVENEX CLOSE

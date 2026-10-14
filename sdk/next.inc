; next.inc - minimal ZX Spectrum Next SDK (sjasmplus, --zxnext)
; Register meanings: see REFERENCES.md (wiki.specnext.dev only).
NR_SEL      equ $243B   ; TBBlue register select port
NR_DATA     equ $253B   ; TBBlue register access port
SPR_SEL     equ $303B   ; sprite/pattern slot select
SPR_ATTR    equ $57     ; sprite attribute upload
SPR_PAT     equ $5B     ; sprite pattern upload
L2_PORT     equ $123B   ; layer 2 access port

NR_CPU_SPEED    equ $07
NR_L2_BANK      equ $12
NR_GLOBAL_TRANS equ $14
NR_SPR_LAYERS   equ $15
NR_CLIP_L2      equ $18
NR_CLIP_SPR     equ $19
NR_CLIP_ULA     equ $1A
NR_CLIP_TM      equ $1B
NR_CLIP_CTRL    equ $1C
NR_TM_XMSB      equ $2F
NR_TM_XLSB      equ $30
NR_TM_Y         equ $31
NR_PAL_IDX      equ $40
NR_PAL_VAL8     equ $41
NR_PAL_CTRL     equ $43
NR_FALLBACK     equ $4A
NR_SPR_TRANS    equ $4B
NR_TM_TRANS     equ $4C
NR_ULA_CTRL     equ $68
NR_L2_CTRL      equ $69
NR_TM_CTRL      equ $6B
NR_TM_ATTR      equ $6C
NR_TM_BASE      equ $6E
NR_TM_TILES     equ $6F

; palette select values for NR $43 bits 6-4 (auto-increment on)
PAL_ULA1  equ $00
PAL_L21   equ $10
PAL_SPR1  equ $20
PAL_TM1   equ $30

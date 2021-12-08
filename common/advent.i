.macro ldxdword dword
    .local start
    .rodata
    start:
    .dword dword
    .code
    RW i16
    ldx #.loword(start)
.endmac

.macro printf str
    .local start
    .local end
    .rodata
    start:
    .byte str
    end:
    .code
    RW a16i16
    lda #.loword(start)
    ldy #.loword(end-start)
    jsl Print
.endmac
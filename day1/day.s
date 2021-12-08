.include "libSFX.i"
.include "../common/advent.i"

.importzp pfac
.export day_one

proc day_one
.segment "ROM1"
incbin datalz4, "data.txt.lz4"

.code
LZ4_decompress datalz4, EXRAM, x
lda #0
sta f:EXRAM,x

RW_forced a16i16
jsl ClearScreen
printf "Day One:"
jsl NextLine
printf "Performing Str -> Int..."
jsl NextLine

break
;break
lda #0
RW a8
ldx #0
ldy #0
jsr strcpy
loop:
phx
phy
ldx #.loword(strbuf)
jsl strbin
RW_forced a16i16
ply
lda pfac
sta numbuf, y
iny
iny
plx
RW a8
jsr strcpy
bne loop
RW_assume a8i16

ldx #0
stx strbuf
stx strbuf+2
stx strbuf+4
stx strbuf+6
stx strbuf+8

RW a16
break
printf "Part One: "

ldx #4000-2
ldy #0
:
lda numbuf+2, x
cmp numbuf, x
beq :+
bcc :+
iny
:
dex
dex
bpl :--
break
sty strbuf
stz strbuf+2

RW_forced a16i8 
lda #$80
RW a8i16
ldx #.loword(strbuf)
jsr printstr
jsl NextLine

cld

RW a16
break
printf "Part Two: "

ldx #4000-6
ldy #0
:
lda numbuf+6, x
cmp numbuf, x
beq :+
bcc :+
iny
:
dex
dex
bpl :--
break
sty strbuf
stz strbuf+2

RW_forced a16i8 
lda #$80
RW a8i16
ldx #.loword(strbuf)
jsr printstr
jsl NextLine

cld

rts
endproc

.segment "LORAM"
numbuf: .res 4000

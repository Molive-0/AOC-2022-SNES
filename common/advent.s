.include "libSFX.i"

.export strcpy
.export printstr
.import strbuf

proc strcpy
RW_forced a8i16
phy
pha
ldy #0
:
lda f:EXRAM, x
beq finished
sta strbuf, y
cmp #$0A
beq :+
inx
iny
bra :-
:
inx
lda #0
sta strbuf, y
pla
ply
rts
finished:
pla
ply
lda #0
rts
endproc

proc printstr
jsl binstr
RW_forced a8i16
RW a16
lda #.loword(strbuf)
jsl Print
rts
endproc
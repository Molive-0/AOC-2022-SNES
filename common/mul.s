.include "libSFX.i"

.export mult16x16
.export mult32x16
.export mult32x32
.export multbuf

; a*y -> multbuf,c
proc mult16x16
RW_assume a16i16
RW a8
tax
tya
sta $4202 ;d
txa
sta $4203 ;b
nop
xba
ldx $4216
sta $4203 ;a
stx z:multbuf ;db
nop
ldx $4216
sty $4201 ;c
sta $4203 ;a
nop
xba
ldy $4216
sta $4203 ;b
RW a16
sty z:multbuf+2
txa
clc
adc z:multbuf+1
sta z:multbuf+1
lda $4216
bcc :+
clc
adc z:multbuf+1
sta z:multbuf+1
RW a8
lda z:multbuf+3
adc #1
sta z:multbuf+3
RW a16
rts
: RW_assume a16i16
adc z:multbuf+1
sta z:multbuf+1
RW a8
lda z:multbuf+3
adc #0
sta z:multbuf+3
RW a16
rts
endproc

; &x * y -> multbuf,c
proc mult32x16
RW_assume a16i16
phy
phx
lda 2,x
jsr mult16x16
plx
ply
pei (multbuf+2)
pei (multbuf)
lda 0,x
jsr mult16x16
pla
clc
adc z:multbuf+2
sta z:multbuf+2
pla
adc #0
sta z:multbuf+4
rts
endproc

; stack: a:32, b:32 -> multbuf,c
proc mult32x32
RW_assume a16i16
lda 5,s
tay
lda 9,s
jsr mult16x16
pei (multbuf+2)
pei (multbuf)
lda 7,s
tay
lda 13,s
jsr mult16x16
pei (multbuf+2)
pei (multbuf)
lda 13,s
tay
lda 15,s
jsr mult16x16
pei (multbuf+2)
pei (multbuf)
lda 15,s
tay
lda 19,s
jsr mult16x16
pla
clc
adc z:multbuf+2
sta z:multbuf+2
pla
adc #0
sta z:multbuf+4
pla
adc z:multbuf+2
sta z:multbuf+2
pla
adc z:multbuf+4
sta z:multbuf+4
stz z:multbuf+6
rol z:multbuf+6
pla
adc z:multbuf+4
sta z:multbuf+4
pla
adc z:multbuf+6
sta z:multbuf+6
lda 1,s
tay
tsc
clc
adc #8
tcs
tya
sta 1,s
rts
endproc

multbuf = ZPAD
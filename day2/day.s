.include "libSFX.i"
.include "../common/advent.i"

.importzp pfac
.export day_two

proc day_two
.segment "ROM1"
incbin datalz4, "data.txt.lz4"

.zeropage
part1: .res 4
part2: .res 4

.code
LZ4_decompress datalz4, EXRAM, x
lda #0
sta EXRAM,x

RW_forced a16i16
stz part1
stz part1+2
stz part2
stz part2+2
printf "Day Two:"
jsl NextLine

ldx #0
loop:
;lda #0
RW a8
lda f:EXRAM, x
;check for empty line
beq done
cmp #$0A
beq done
sub #'A'
sta z:0
inx
inx
lda f:EXRAM, x
sub #'X'
asl
asl
add z:0
txy
RW a16
and #$00ff
tax
lda f:score_table1, x
and #$00ff
adc part1
sta part1
lda f:score_table2, x
and #$00ff
adc part2
sta part2
tyx
inx
inx
bra loop

done:
RW_assume a8i16
RW a16
break
printf "Part One: "

RW_forced a16i16
lda #$80
RW a8
ldx #.loword(part1)
jsr printstr
jsl NextLine

printf "Part Two: "

RW_forced a16i16
lda #$80
RW a8
ldx #.loword(part2)
jsr printstr
jsl NextLine

rts

score_table1:
.byte 1+3 ;A X
.byte 1+0 ;B X
.byte 1+6 ;C X
.byte $FF ;D X
.byte 2+6 ;A Y
.byte 2+3 ;B Y
.byte 2+0 ;C Y
.byte $FF ;D Y
.byte 3+0 ;A Z
.byte 3+6 ;B Z
.byte 3+3 ;C Z
.byte $FF ;D Z
score_table2:
.byte 3+0 ;A X
.byte 1+0 ;B X
.byte 2+0 ;C X
.byte $FF ;D X
.byte 1+3 ;A Y
.byte 2+3 ;B Y
.byte 3+3 ;C Y
.byte $FF ;D Y
.byte 2+6 ;A Z
.byte 3+6 ;B Z
.byte 1+6 ;C Z
.byte $FF ;D Z
endproc

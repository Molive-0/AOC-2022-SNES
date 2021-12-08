.include "libSFX.i"
.include "../common/advent.i"

.importzp pfac
.export day_seven

proc day_seven
.segment "ROM1"
incbin datalz4, "data.txt.lz4"

.code
LZ4_decompress datalz4, HIRAM, x
lda #0
sta f:EXRAM,x

RW_forced a16i16
printf "Day Two:"
jsl NextLine

RW a16
break
printf "Part One: "

ldx #0
loop:
lda #0
RW a8
lda f:EXRAM,x
beq end
cmp #'u'
beq up
cmp #'f'
beq forward
down:
RW_assume a8i16
lda f:EXRAM+5,x
RW a16
sub #'0'
add pos_one+pos1::ycoord
sta pos_one+pos1::ycoord
txa
add #7
tax
bra loop
up:
RW_assume a8i16
lda f:EXRAM+3,x
sub #'0'
RW a16
eor #$FFFF
adc pos_one+pos1::ycoord
sta pos_one+pos1::ycoord
txa
add #5
tax
bra loop
forward:
RW_assume a8i16
lda f:EXRAM+8,x
RW a16
sub #'0'
pha
add pos_one+pos1::xcoord
sta pos_one+pos1::xcoord
pla
ldy pos_one+pos1::ycoord
phx
jsr mult16x16
plx
lda multbuf
add pos_two+pos2::ycoord
sta pos_two+pos2::ycoord
lda multbuf+2
adc pos_two+pos2::ycoord+2
sta pos_two+pos2::ycoord+2
txa
add #10
tax
bra loop
end:
RW_assume a8i16
RW a16
lda pos_one+pos1::xcoord
ldy pos_one+pos1::ycoord
jsr mult16x16

lda multbuf
sta strbuf
lda multbuf+2
sta strbuf+2

lda #$80
RW a8i16
ldx #.loword(strbuf)
jsr printstr
jsl NextLine

printf "Part Two: $"

RW_forced a16i16
ldx #.loword(pos_two+pos2::ycoord)
ldy pos_one+pos1::xcoord
jsr mult32x16

lda multbuf
sta strbuf
lda multbuf+2
sta strbuf+2
lda multbuf+4
sta strbuf+4

RW a8i8
ldx #5
print_loop:
lda strbuf,x
phx
jsl PrintHex
RW_forced a8i8
plx
dex
bpl print_loop

:
bra :-
endproc

.zeropage
pos_one: .tag pos1
pos_two: .tag pos2

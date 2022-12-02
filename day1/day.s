.include "libSFX.i"
.include "../common/advent.i"

.importzp pfac
.export day_one

proc day_one
.segment "ROM1"
incbin datalz4, "data.txt.lz4"

.zeropage
first: .res 4
second: .res 4
third: .res 4
acc: .res 4

.code
;decompress input
LZ4_decompress datalz4, EXRAM, x
;null terminate
lda #0
sta f:EXRAM,x

RW_forced a16i16
jsl ClearScreen
printf "Day One:"
jsl NextLine

break
;break
lda #0
ldx #0
phx
bra clear
loop:
phx
;if null string perform max value comprehension
lda strbuf
beq get_maxes

;otherwise convert to int32
ldx #.loword(strbuf)
jsl strbin
RW_forced a16i16
;and add to accumulator
clc
lda pfac 
adc acc
sta acc
lda pfac+2
adc acc+2
sta acc+2
bra done

get_maxes:
RW_forced a16i16
;check if larger than first
lda acc+2
cmp first+2
bcc :+
bne first_set
lda acc
cmp first
bcs first_set
: ;check if larger than second
lda acc+2
cmp second+2
bcc :+
bne second_set
lda acc
cmp second
bcs second_set
: ;check if larger than third
lda acc+2
cmp third+2
bcc :+
bne third_set
lda acc
cmp third
bcs third_set
:
clear:
;clear accumulator
stz acc
stz acc+2
done:
RW a8
;copy next string into closer ram
plx
jsr strcpy
;if null terminator end
bne loop
jmp printing

;set first highest, move 2 and 3 down
first_set:
lda second
sta third
lda second+2
sta third+2
lda first
sta second
lda first+2
sta second+2
lda acc
sta first
lda acc+2
sta first+2
bra clear

;set second highest, move 3 down
second_set:
lda second
sta third
lda second+2
sta third+2
lda acc
sta second
lda acc+2
sta second+2
bra clear

;set third highest
third_set:
lda acc
sta third
lda acc+2
sta third+2
bra clear

printing:
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

RW_forced a16i8
lda #$80
RW a8i16
ldx #.loword(first)
jsr printstr
jsl NextLine

cld

RW a16
break
printf "Part Two: "

RW_forced a16i8
lda first
sta pfac
lda first + 2
sta pfac + 2
clc
lda second
adc pfac
sta pfac
lda second + 2
adc pfac + 2
sta pfac + 2
clc
lda third
adc pfac
sta pfac
lda third + 2
adc pfac + 2
sta pfac + 2

lda #$80
RW a8i16
ldx #.loword(pfac)
jsr printstr
jsl NextLine

cld

rts
endproc

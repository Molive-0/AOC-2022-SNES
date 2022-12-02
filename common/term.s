.include "libSFX.i"

VRAM_MAP1_LOC    =  $0000
VRAM_MAP2_LOC    =  $1000
VRAM_TILES_LOC   =  $2000
VRAM_TILES2_LOC  =  $6000

MAP1_MIRROR      =  $7FF000
MAP2_MIRROR      =  $7FF800

.rodata

incbin RES_FONT, "graphics/font.png.tiles.lz4"
incbin RES_FONT2, "graphics/font2.png.tiles.lz4"
incbin RES_FONTPAL, "graphics/font.png.palette"
incbin RES_ASCII_TABLE, "graphics/ascii_tiles.table"

.code
VBL_term:
RW a8i8
VRAM_memcpy VRAM_MAP1_LOC, MAP1_MIRROR, $800
VRAM_memcpy VRAM_MAP2_LOC, MAP2_MIRROR, $800
rtl

Main:
RW_forced a16i16
;Decompressing font and transfering it to VRAM
LZ4_decompress RES_FONT, EXRAM, y
VRAM_memcpy VRAM_TILES_LOC, EXRAM, y
LZ4_decompress RES_FONT2, EXRAM, y
VRAM_memcpy VRAM_TILES2_LOC, EXRAM, y

CGRAM_memcpy 0, RES_FONTPAL, 32

;Enable interlacing
lda #%00001001
sta $2133

lda     #bgmode(BG_MODE_5, 0, BG_SIZE_16X16, BG_SIZE_16X16, BG_SIZE_8X8, BG_SIZE_8X8) ;Mode 5 Hires + 16x16 character size
sta     BGMODE
lda     #bgnba(VRAM_TILES_LOC, VRAM_TILES2_LOC, 0, 0) ;Set tile location for 4bpp font and 2bpp font
sta     BG12NBA
lda     #bgsc(VRAM_MAP1_LOC, SC_SIZE_32X32) ;Set Map location for BG1
sta     BG1SC
lda     #bgsc(VRAM_MAP2_LOC, SC_SIZE_32X32) ;Set Map location for BG2
sta     BG2SC

lda     #tm(ON, ON, OFF, OFF, OFF) ;Enable BG1+BG2
sta     TM
lda     #tm(ON, ON, OFF, OFF, OFF) ;Subscreen needed for hires mode for some reason, or else it produces vertical stripes
sta     TS

lda     #inidisp(ON, DISP_BRIGHTNESS_MAX) ;Turn on screen after next VBlank
sta     SFX_inidisp	

; Enable VBlank handling
VBL_on
; Set VBL handler
VBL_set VBL_term
jsr day_one
jsr day_two
:
bra :-

.export Print
.export NextLine
.export PrintLn
.export PrintHex
.export ClearScreen

Print:
RW_forced a16i16
sta z:$60 ;holds the start position of the string
sty z:$62 ;holds the length of the string
stz z:$66 ;holds the current position of where in the string we are while looping.
ldx z:$64 ;holds the cursor position
;Two different loops, one for each tilemap
Print1_loop:
lda z:$66 
cmp z:$62
bcs Print1_Done ;compare current position against length of string and jump out of the loop based on that
tay             ; Transfer current position from a to y, it's faster than loading it again
lda ($60), y    ; load word at y position of address referenced in $60 into a
iny             ; increment twice since we are only after every other byte
iny
sty z:$66         ; store position 
and #$00FF      ; zero out the high byte of the loaded word since we only need the lower. This is faster than switching a into 8 bit mode and back into 16 bit mode later
asl             ; shift left, effectively multiply by 2, we need this since the ascii to tile table is two bytes per entry
phx
tax             ; transfer into y to use as an index
lda f:RES_ASCII_TABLE, x  ;load the right tile to use from the RES_ASCII_TABLE
plx
sta f:MAP1_MIRROR, x      ;Store it at the tilemap mirror, indexed by the cursor position
inx
inx                     ;increment cursor position
txa
and #$7FF
tax                     ;This truncates the highes bit, making the cursor loop around to the top instead of jumping outside the tilemap
jmp Print1_loop  
Print1_Done:            
lda #1                  
sta z:$66                 ;Store 1 instead of 0 in current position since we're now doing odd bytes instead of even
ldx z:$64                 ;Reload cursor position to get back to the beginning of the string
Print2_loop:            ;basically the same thing as loop 1
lda z:$66
dec a
cmp z:$62
bcs Print2_Done
ldy z:$66
lda ($60), y
iny
iny
sty z:$66
and #$00FF
asl
phx
tax
lda f:RES_ASCII_TABLE, x
plx
sta f:MAP2_MIRROR, x
inx
inx
txa
and #$7FF
tax                     ;This truncates the highes bit, making the cursor loop around to the top instead of jumping outside the tilemap
jmp Print2_loop
Print2_Done:
stx z:$64                ;store cursor position back
lda z:$62                ;bug "fix" if the string length is not divisable by two, we wrote a garbage tile at the end. Let's fix that and replace it with a space         
bit #1                 ;test uneven string length
bne FixLastTile
rtl

FixLastTile:
dex
dex
lda f:RES_ASCII_TABLE+$40
sta f:MAP2_MIRROR, x
rtl


NextLine:
RW a16i16
lda z:$64  ; load cursor position
and #$7C0 ; basically rounds down to the nearest multiple of 64, so to the beginning of the current line
clc      ; Clear carry to get a clean result
adc #64  ; add another line
sta z:$64  ; store cursor position
rtl

PrintLn:
RW a16i16
jsl Print
jml NextLine


PrintHex:
RW a8
pha ;push a to stack for later use
lsr
lsr
lsr
lsr ;shift it to the bottom
cmp #$0A ;If higher than 9, we need to add 7 to get to the A-F ascii characters
bcs Add7_1
Add7_1End:
add #48  ;Add 48 cause that's where 0-9 characters are
sta $00  ;store in $00, this will be loaded by the Print subroutine later
pla      ;Restore a from the stack to process the second nibble
and #$0F ;get lower nibble of byte
cmp #$0A ;same as above
bcs Add7_2
Add7_2End:
add #48
sta $01

RW a16i16
lda #$0000 ;String is at 0000 in RAM
ldy #$2    ;String is 4 characters Long
jml Print

RW a8i8
Add7_1:
add #7
jmp Add7_1End
Add7_2:
add #7
jmp Add7_2End


RW a16i16
ClearScreen:
;Pretty straight forward. Just memset every tile to 00 00, making them blank tiles
WRAM_memset MAP1_MIRROR, $800, 0
WRAM_memset MAP2_MIRROR, $800, 0
stz $64 ;reset cursor position
rtl

;I've written this bit at 5:30 am, it does not work. Will work on this later
ScrollToCursor:
RW_forced a16i16
lda $64
and #$7C0
lsr
lsr
sta $80
RW a8i8
sta BG1VOFS
lda $81
asl
sta BG1VOFS
lda $80
sta BG2VOFS
lda $81
asl
stz BG2VOFS
rtl


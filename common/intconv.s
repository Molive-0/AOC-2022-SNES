.include "libSFX.i"

proc strtobin
.export strbin
.code
;
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                                                                             *
;*                CONVERT ASCII NUMBER STRING TO 32-BIT BINARY                 *
;*                                                                             *
;*                by BigDumbDinosaur,  modifications by Molive                 *
;*                                                                             *
;* This 6502 assembly language program converts a null-terminated ASCII number *
;* string into a 32-bit unsigned binary value in little-endian format.  It can *
;* accept a number in binary, octal, decimal or hexadecimal format.            *
;*                                                                             *
;* --------------------------------------------------------------------------- *
;*                                                                             *
;* Copyright (C)1985 by BCS Technology Limited.  All rights reserved.          *
;*                                                                             *
;* Permission is hereby granted to copy and redistribute this software,  prov- *
;* ided this copyright notice remains in the source code & proper  attribution *
;* is given.  Any redistribution, regardless of form, must be at no charge  to *
;* the end user.  This code MAY NOT be incorporated into any package  intended *
;* for sale unless written permission has been given by the copyright holder.  *
;*                                                                             *
;* THERE IS NO WARRANTY OF ANY KIND WITH THIS SOFTWARE.  It's free, so no mat- *
;* ter what, you'll get your money's worth.                                    *
;*                                                                             *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;
;	Calling Syntax:
;
;		ldx #<numstr
;		ldy #>numstr
;		jsr strbin
;		bcs error
;
;	All registers are modified.  The result of the conversion is left in
;	location PFAC in unsigned, little-endian format (see source code).
;	The contents of PFAC are undefined if strbin exits with an error.
;	The maximum number that can be converted is 4,294,967,295 or (2^32)-1.
;
;	numstr must point to a null-terminated character string in the format:
;
;		[%|@|$]DDD...DDD
;
;	where %, @ or $ are optional radices specifying, respectively, base-2,
;	base-8 or base-16.  If no radix is specified, base-10 is assumed.
;
;	DDD...DDD represents the characters that comprise the number that is
;	to be converted.  Permissible values for each instance of D are:
;
;		Radix  Description  D - D
;		-------------------------
;		  %    Binary       0 - 1
;		  @    Octal        0 - 7
;		 None  Decimal      0 - 9
;		  $    Hexadecimal  0 - 9
;		                    A - F
;		-------------------------
;
;	Conversion is not case-sensitive.  Leading zeros are permissible, but
;	not leading blanks.  The maximum string length including the null
;	terminator is 127.  An error will occur if a character in the string
;	to be converted is not appropriate for the selected radix, the con-
;	verted value exceeds $FFFFFFFF or an undefined radix is specified.
;
;================================================================================
;
;ATOMIC CONSTANTS
;
;
;	------------------------------------------
;	Define the above to suit your application.
;	------------------------------------------
;
a_maskuc =%01011111            ;case conversion mask
a_hexnum ='A'-'9'-1            ;hex to decimal difference
n_radix  =4                    ;number of supported radixes
s_fac    =4                    ;binary accumulator size
;
;================================================================================
;
;ZERO PAGE STORAGE
;
pfac     =ZPAD            ;primary accumulator
ptr01    =ZPAD+s_fac                 ;input string pointer
stridx   =ZPAD+s_fac+2               ;string index
sfac     =ZPAD+s_fac+3           ;secondary accumulator
bitsdig  =ZPAD+s_fac+3+s_fac
curntnum =ZPAD+s_fac+3+s_fac+1
radxflag =ZPAD+s_fac+3+s_fac+3
valdnum  =ZPAD+s_fac+3+s_fac+4
;
;	------------------------------------------------------
;	Define the above to suit your application.  Moving the
;	accumulators to absolute storage will result in an
;	approximate 20 percent increase in execution time &
;	will require some program restructuring to avoid out-
;	of-range relative branches.
;	------------------------------------------------------
;
;================================================================================
;
;CONVERT NULL-TERMINATED STRING TO 32 BIT BINARY
;
;
strbin:  
          RW_forced a16i16
          stx z:ptr01           ;save string pointer
          RW i8
;
strbin01: stz z:pfac        ;clear
          stz z:pfac+2        ;clear
          stz z:curntnum        ;clear
;
;	------------------------
;	process radix if present
;	------------------------
;
         lda #0
         RW a8
         ldy #0                ;starting string index
         clc                   ;assume no error for now
         lda (ptr01),y         ;get a char
         bne strbin02
;
         rtl                   ;null string, so exit
;
strbin02: ldx #n_radix-1
;
strbin03: cmp f:radxtab,x         ;recognized radix?
         beq strbin04          ;yes
;
         dex
         bpl strbin03          ;try next
;
         stx z:radxflag          ;assuming decimal...
         inx                   ;which might be wrong
;
strbin04: lda f:basetab,x         ;number bases table
         sta z:valdnum           ;set valid numeral range
         lda f:bitstab,x         ;get bits per digit
         sta z:bitsdig           ;store
         txa                   ;was radix specified?
         beq strbin05          ;no
;
         iny                   ;move past radix
;
strbin05: sty stridx            ;save string index
;
;	--------------------------------
;	process number portion of string
;	--------------------------------
;
strbin06: clc                   ;assume no error for now
         lda (ptr01),y         ;get numeral
         beq strbin17          ;end of string
;
         inc stridx            ;point to next
         cmp #'a'              ;check char range
         bcc strbin07          ;not ASCII LC
;
         cmp #'z'+1
         bcs strbin08          ;not ASCII LC
;
         and #a_maskuc         ;do case conversion
;
strbin07: sec
;
strbin08: sbc #'0'              ;change numeral to binary
         bcc strbin16          ;numeral > 0
;
         cmp #10
         bcc strbin09          ;numeral is 0-9
;
         sbc #a_hexnum         ;do a hex adjust
;
strbin09: cmp z:valdnum           ;check range
         bcs strbin17          ;out of range
;
         sta z:curntnum          ;save processed numeral
         bit z:radxflag          ;working in base 10?
         bpl strbin11          ;no
;
;	-----------------------------------------------------------
;	Prior to combining the most recent numeral with the partial
;	result, it is necessary to left-shift the partial result
;	result 1 digit.  The operation can be described as N*base,
;	where N is the partial result & base is the number base.
;	N*base with binary, octal & hex is a simple repetitive
;	shift.  A simple shift won't do with decimal, necessitating
;	an (N*8)+(N*2) operation.  PFAC is copied to SFAC to gener-
;	ate the N*2 term.
;	-----------------------------------------------------------
;
         RW a16
         clc
         lda pfac           ;N
         rol                   ;N=N*2
         sta sfac
         lda pfac+2            ;N
         rol                   ;N=N*2
         sta sfac+2
;
         bcs strbin17          ;overflow = error
;
strbin11: ldx z:bitsdig           ;bits per digit
;
strbin12: asl pfac              ;compute N*base for binary,...
                               ;octal &...
         rol pfac+2            ;hex or...
                               ;N*8 for decimal
         bcs strbin17          ;overflow
;
         dex
         bne strbin12          ;next shift
;
         RW a8
         bit z:radxflag          ;check base
         RW a16
         bpl strbin14          ;not decimal
;
;	-------------------
;	compute (N*8)+(N*2)
;	-------------------
;
         lda pfac            ;N*8
         adc sfac            ;N*2
         sta pfac            ;now N*10
         lda pfac+2            ;N*8
         adc sfac+2            ;N*2
         sta pfac+2            ;now N*10
;
         bcs strbin17          ;overflow
;
;	-------------------------------------
;	add current numeral to partial result
;	-------------------------------------
;
strbin14: clc
         lda pfac              ;N
         adc z:curntnum          ;N=N+D
         sta pfac
;
         lda pfac+2
         adc #0                ;account for carry
         sta pfac+2
;
         bcs strbin17          ;overflow
;
;	----------------------
;	ready for next numeral
;	----------------------
;
         RW a8
         ldy stridx            ;string index
         bpl strbin06          ;get another numeral
;
;	----------------------------------------------
;	if string length > 127 fall through with error
;	----------------------------------------------
;
strbin16: sec                   ;flag an error
;
strbin17: rtl                   ;done
;
;================================================================================
;
;CONVERSION TABLES
;
basetab:
  .byte 10,2,8,16       ;number bases per radix
bitstab:
  .byte 3,1,3,4         ;bits per digit per radix
radxtab:
  .byte " %@$"          ;valid radix symbols
;
;================================================================================
;
;DYNAMIC STORAGE
;
;
;================================================================================

endproc

proc bintostr
.export binstr
.export strbuf
.code

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                                                                             *
;*                CONVERT 32-BIT BINARY TO ASCII NUMBER STRING                 *
;*                                                                             *
;*                by BigDumbDinosaur,  modifications by Molive                 *
;*                                                                             *
;* This 6502 assembly language program converts a 32-bit unsigned binary value *
;* into a null-terminated ASCII string whose format may be in  binary,  octal, *
;* decimal or hexadecimal.                                                     *
;*                                                                             *
;* --------------------------------------------------------------------------- *
;*                                                                             *
;* Copyright (C)1985 by BCS Technology Limited.  All rights reserved.          *
;*                                                                             *
;* Permission is hereby granted to copy and redistribute this software,  prov- *
;* ided this copyright notice remains in the source code & proper  attribution *
;* is given.  Any redistribution, regardless of form, must be at no charge  to *
;* the end user.  This code MAY NOT be incorporated into any package  intended *
;* for sale unless written permission has been given by the copyright holder.  *
;*                                                                             *
;* THERE IS NO WARRANTY OF ANY KIND WITH THIS SOFTWARE.  It's free, so no mat- *
;* ter what, you're getting a great deal.                                      *
;*                                                                             *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;
;	CALLING SYNTAX:
;
;	        LDA #RADIX         ;radix character, see below
;	        LDX #<OPERAND      ;binary value address LSB
;	        LDY #>OPERAND      ;binary value address MSB
;	        (ORA #%10000000)   ;radix suppression, see below
;	        JSR BINSTR         ;perform conversion
;	        STX ZPPTR          ;save string address LSB
;	        STY ZPPTR+1        ;save string address MSB
;	        TAY                ;string length
;	LOOP    LDA (ZPPTR),Y      ;copy string to...
;	        STA MYSPACE,Y      ;safe storage, will include...
;	        DEY                ;the terminator
;	        BPL LOOP
;
;	CALLING PARAMETERS:
;
;	.A      Conversion radix, which may be any of the following:
;
;	        '%'  Binary.
;	        '@'  Octal.
;	        '$'  Hexadecimal.
;
;	        If the radix is not one of the above characters decimal will be
;	        assumed.  Binary, octal & hex conversion will prepend the radix
;	        character to the string.  To suppress this feature set bit 7 of
;	        the radix.
;
;	.X      The address of the 32-bit binary value (operand) that is to be
;	        converted.  The operand must be in little-endian format.
;
;	REGISTER RETURNS:
;
;	.Y      The printable string length.  The exact length will depend on
;	        the radix that has been selected, whether the radix is to be
;	        prepended to the string & the number of significant digits.
;	        Maximum possible printable string lengths for each radix type
;	        are as follows:
;
;	        %  Binary   33
;	        @  Octal    12
;	           Decimal  11
;	        $  Hex       9
;
;	.X      The LSB/MSB address at which the null-terminated conversion
;	        string will be located.  The string will be assembled into a
;	        statically allocated buffer and should be promptly copied to
;	        user-defined safe storage.
;
;	.C      The carry flag will always be clear.
;
;	APPROXIMATE EXECUTION TIMES in CLOCK CYCLES:
;
;	        Binary    5757
;	        Octal     4533
;	        Decimal  13390
;	        Hex       4373
;
;	The above execution times assume the operand is $FFFFFFFF, the radix
;	is to be prepended to the conversion string & all workspace other than
;	the string buffer is on zero page.  Relocating ZP workspace to absolute
;	memory will increase execution time approximately 8 percent.
;
;================================================================================
;
;ATOMIC CONSTANTS
;
a_hexdec ='A'-'9'-2            ;hex to decimal difference
m_bits   =32                   ;operand bit size
m_cbits  =48                   ;workspace bit size
m_strlen =m_bits+1             ;maximum printable string length
n_radix  =4                    ;number of supported radices
s_pfac   =m_bits/8             ;primary accumulator size
s_ptr    =2                    ;pointer size
s_wrkspc =m_cbits/8            ;conversion workspace size
;
;================================================================================
;
;CONVERT 32-BIT BINARY TO NULL-TERMINATED ASCII NUMBER STRING
;
;	----------------------------------------------------------------
;	WARNING! If this code is run on an NMOS MPU it will be necessary
;	         to disable IRQs during binary to BCD conversion unless
;	         the target system's IRQ handler clears decimal mode.
;	         Refer to the FACBCD subroutine.
;	----------------------------------------------------------------
;
;
binstr:  
         RW_assume a8i16
         stx z:ptr01             ;operand pointer
         tay                   ;protect radix
;
         RW a16
binstr01:lda z:0,x         ;copy operand to...
         sta z:pfac            ;workspace
         lda z:2,x         
         sta z:pfac+2
;
         RW a8i8
         stz z:stridx            ;initialize string index
;
;	--------------
;	evaluate radix
;	--------------
;
         tya                   ;radix character
         asl                   ;extract format flag &...
         ror z:formflag          ;save it
         lsr                   ;extract radix character
         ldx #n_radix-1        ;total radices
;
binstr03: cmp f:radxtab,x         ;recognized radix?
         beq binstr04          ;yes
;
         dex
         bne binstr03          ;try next
;
;	------------------------------------
;	radix not recognized, assume decimal
;	------------------------------------
;
binstr04: stx z:radix             ;save radix index for later
         txa                   ;converting to decimal?
         bne binstr05          ;no
;
;	------------------------------
;	prepare for decimal conversion
;	------------------------------
;
         jsr facbcd            ;convert operand to BCD
         lda #0
         bra binstr09          ;skip binary stuff
;
;	-------------------------------------------
;	prepare for binary, octal or hex conversion
;	-------------------------------------------
;
binstr05: bit z:formflag
         bmi binstr06          ;no radix symbol wanted
;
         lda f:radxtab,x         ;radix table
         sta strbuf            ;prepend to string
         inc z:stridx            ;bump string index
;
binstr06:
         RW a16
         lda z:pfac            ;copy operand to...
         sta z:wrkspc01        ;workspace in...
         lda z:pfac+2            ;copy operand to...
         sta z:wrkspc01+2        ;workspace in...
         stz z:wrkspc01+4        ;workspace in...
;
;	----------------------------
;	set up conversion parameters
;	----------------------------
;
binstr09: RW a8 
         stz z:wrkspc02          ;initialize byte counter
         ldx z:radix             ;radix index
         lda f:numstab,x         ;numerals in string
         sta z:wrkspc02+1        ;set remaining numeral count
         lda f:bitstab,x         ;bits per numeral
         sta z:wrkspc02+2        ;set
         lda f:lzsttab,x         ;leading zero threshold
         sta z:wrkspc02+3        ;set
;
;	--------------------------
;	generate conversion string
;	--------------------------
;
         
binstr10: RW a16 
         lda #0
         ldy z:wrkspc02+2        ;bits per numeral
;
binstr11:
;
         asl z:wrkspc01        ;shift out a bit...
         rol z:wrkspc01+2      
         rol z:wrkspc01+4        
;
         rol                   ;bit to .A
         dey
         bne binstr11          ;more bits to grab
;
         tay                   ;if numeral isn't zero...
         bne binstr13          ;skip leading zero tests
;
         ldx z:wrkspc02+1        ;remaining numerals
         cpx z:wrkspc02+3        ;leading zero threshold
         bcc binstr13          ;below it, must convert
;
         ldx z:wrkspc02          ;processed byte count
         beq binstr15          ;discard leading zero
;
binstr13: cmp #10               ;check range
         bcc binstr14          ;is 0-9
;
         adc #a_hexdec         ;apply hex adjust
;
binstr14: adc #'0'              ;change to ASCII
         ldy z:stridx            ;string index
         sta strbuf,y          ;save numeral in buffer
         RW a8
         inc z:stridx            ;next buffer position
         inc z:wrkspc02          ;bytes=bytes+1
;
binstr15: RW_assume a16i8
         RW a8
         dec z:wrkspc02+1        ;numerals=numerals-1
         bne binstr10          ;not done
;
;	-----------------------
;	terminate string & exit
;	-----------------------
;
         lda #0
         ldx z:stridx            ;printable string length
         sta strbuf,x          ;terminate string
         txy
         clc                   ;all okay
         rtl
;
;================================================================================
;
;CONVERT PFAC INTO BCD
;
;	---------------------------------------------------------------
;	Uncomment noted instructions if this code is to be used  on  an
;	NMOS system whose interrupt handlers do not clear decimal mode.
;	---------------------------------------------------------------
;
facbcd:   RW_assume a8i8
          RW a16
;
         lda z:pfac            ;value to be converted
         pha                   ;protect
         lda z:pfac+2            
         pha                  
;
         lda #1
         stz z:wrkspc01        ;clear final result
         sta z:wrkspc02        ;clear scratchpad
         stz z:wrkspc01+2        ;clear final result
         stz z:wrkspc02+2        ;clear scratchpad
         stz z:wrkspc01+4        ;clear final result
         stz z:wrkspc02+4        ;clear scratchpad
;
         sed                   ;select decimal mode
         ldy #m_bits-1         ;bits to convert -1
;
facbcd03: clc                   ;no carry at start
;
         ror z:pfac+2            ;grab LS bit in operand
         ror z:pfac            
;
         bcc facbcd06          ;LS bit clear
;
         clc
         ldx #s_wrkspc-2
;
         lda z:wrkspc01        ;partial result
         adc z:wrkspc02        ;scratchpad
         sta z:wrkspc01        ;new partial result
         lda z:wrkspc01+2        ;partial result
         adc z:wrkspc02+2        ;scratchpad
         sta z:wrkspc01+2        ;new partial result
         lda z:wrkspc01+4        ;partial result
         adc z:wrkspc02+4        ;scratchpad
         sta z:wrkspc01+4        ;new partial result
;
facbcd06:         clc
;
         lda z:wrkspc02        ;scratchpad
         adc z:wrkspc02        ;double &...
         sta z:wrkspc02        ;save
         lda z:wrkspc02+2        ;scratchpad
         adc z:wrkspc02+2        ;double &...
         sta z:wrkspc02+2        ;save
         lda z:wrkspc02+4        ;scratchpad
         adc z:wrkspc02+4        ;double &...
         sta z:wrkspc02+4        ;save
;
         dey
         bpl facbcd03          ;next operand bit
;
;
         pla                   ;operand
         sta z:pfac+2           ;restore
         pla                   ;operand
         sta z:pfac           ;restore

         cld
         RW a8i8
         rts
;
;================================================================================
;
;PER RADIX CONVERSION TABLES
;
bitstab:  .byte 4,1,3,4         ;bits per numeral
lzsttab:  .byte 2,9,2,3         ;leading zero suppression thresholds
numstab:  .byte 12,48,16,12     ;maximum numerals
radxtab:  .byte 0,"%@$"         ;recognized symbols
;
;================================================================================
;
;STATIC STORAGE
;
.segment "LORAM"
strbuf:  .res m_strlen+1        ;conversion string buffer
;
;================================================================================
;
;	---------------------------------
;	The following may be relocated to
;	absolute storage if desired.
;	---------------------------------
;
.export pfac
pfac = ZPAD         ;primary accumulator
wrkspc01= ZPAD + s_pfac          ;conversion...
wrkspc02= ZPAD + s_pfac + s_wrkspc    ;workspace
ptr01= ZNMI+11    ;string format flag
formflag= ZNMI+13    ;string format flag
radix= ZNMI+14          ;radix index
stridx= ZNMI+15             ;string buffer index
;
;================================================================================
endproc
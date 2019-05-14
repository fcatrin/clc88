	icl '../os/symbols.asm'
	
	org BOOTADDR
	
   lda VSTATUS
   and #(255 - VSTATUS_EN_INTS)
   sta VSTATUS
   	
	lda #<vblank
	sta VBLANK_VECTOR
	lda #>vblank
	sta VBLANK_VECTOR+1
	lda #<dli
	sta HBLANK_VECTOR
   lda #>dli
   sta HBLANK_VECTOR+1

   lda VSTATUS
   ora #VSTATUS_EN_INTS
   sta VSTATUS
	
	lda #0
	ldx #OS_SET_VIDEO_MODE
	jsr OS_CALL
	
	lda DLIST
	sta TMPVARS
	lda DLIST+1
	sta TMPVARS+1 
   ldy #10
   lda (TMPVARS), y
   ora #$80
   sta (TMPVARS), y
	
	ldy #0
copy:
	lda message, y
	cmp #255
	beq rainbow
	sta (TEXT_START), y
	iny
	bne copy
	ldx #0
rainbow:
   ; clc
	; lda VCOUNT
	; adc FRAMECOUNT
	; sta WSYNC
	; sta VCOLOR0
	jmp rainbow
	
dli:
   pha
   lda #$66
   sta VCOLOR0
   pla
   rti

vblank:
   pha
   lda #$BF
   sta VCOLOR0
   pla
   rti
	
message:
	.byte 40, 101, 108, 108, 111, 0, 55, 111, 114, 108, 100, 1, 1, 1, 1, 255


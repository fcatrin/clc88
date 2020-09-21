	icl '../os/symbols.asm'
	
	org BOOTADDR

   lda #0
   ldy #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
	
   lda VSTATUS
   and #(255 - VSTATUS_EN_INTS)
   sta VSTATUS
   	
   mwa #vblank VBLANK_VECTOR_USER
   mwa #dli    HBLANK_VECTOR_USER
   
   lda #1
   sta VLINEINT

   lda VSTATUS
   ora #VSTATUS_EN_INTS
   sta VSTATUS
	
   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
	
	ldy #0
copy:
	lda message, y
	cmp #255
	beq rainbow
	sta (RAM_TO_VRAM), y
	iny
	bne copy
	ldx #0
rainbow:
    clc
	lda VCOUNT
	adc FRAMECOUNT
	sta WSYNC
	sta VCOLOR0
	jmp rainbow
	
dli:
   pha
   lda #$66
   sta WSYNC
   sta VCOLOR0
   pla
   rts

vblank:
   pha
   lda #$BF
   sta VCOLOR0
   pla
   rts
	
message:
   .by "Hello world!!!!", 96, 255

   icl '../os/stdlib.asm'

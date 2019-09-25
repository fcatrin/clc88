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
   ; clc
	; lda VCOUNT
	; adc FRAMECOUNT
	; sta WSYNC
	; sta VCOLOR0
	jmp rainbow

vblank:
   pha
   lda #$BF
   sta VCOLOR0
   
   ; lda #$AF
   ; sta POKEY0_AUDC1
   ; sta POKEY1_AUDC1
   
   lda FRAMECOUNT
   sta POKEY0_AUDF1
   sta POKEY0_AUDF2
   sta POKEY0_AUDF3
   sta POKEY0_AUDF4
   
   cmp #255
   bne noinc
   inc vol
noinc:
   lda vol
   and #$0F
   ora #$A0

   sta POKEY0_AUDC1
   sta POKEY0_AUDC2
   sta POKEY0_AUDC3
   sta POKEY0_AUDC4

   lda vol
   asl
   sta VCOLOR0
   
   lda #30
   sta POKEY1_AUDF1
   lda #$AF
   sta POKEY1_AUDC1
      
   pla
   rts
	
message:
   .by "Hello world!!!!", 96, 255

vol: .byte 0

   icl '../os/stdlib.asm'

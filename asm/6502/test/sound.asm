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
	beq stop
	sta (RAM_TO_VRAM), y
	iny
	bne copy
	ldx #0
stop:
	jmp stop

vblank:
   pha
   tya
   pha
   lda #128
   sta POKEY0_AUDF1
   sta POKEY1_AUDF1

   lda FRAMECOUNT
   
   cmp #255
   bne noinc
   inc dist
noinc:
   lda dist
   asl
   asl
   asl
   asl
   asl
   ora #$0F
   sta VCOLOR0

   lda #$2F
   sta POKEY0_AUDC1
   sta POKEY1_AUDC1

   lda dist
   adc #'0'
   sta (RAM_TO_VRAM), y

   pla
   tay

   pla
   rts
	
message:
   .by "Hello world!!!!", 96, 255

vol: .byte 0
dist: .byte 0


   icl '../os/stdlib.asm'

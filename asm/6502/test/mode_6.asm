	icl '../os/symbols.asm'
	
	org BOOTADDR
	
	lda #6
	ldx #OS_SET_VIDEO_MODE
	jsr OS_CALL
	
	mwa SUBPAL_START VRAM_TO_RAM
	jsr lib_vram_to_ram
	
	ldy #0
   lda #$9A
	sta (RAM_TO_VRAM), y
	iny
	lda #$38
	sta (RAM_TO_VRAM), y
   iny
   lda #$C8
   sta (RAM_TO_VRAM), y
   iny
   lda #$4C
   sta (RAM_TO_VRAM), y
	
	mwa TEXT_START VRAM_TO_RAM
	jsr lib_vram_to_ram
	
	ldx #20
copy_line	
	ldy #0
copy:
	lda message, y
	sta (RAM_TO_VRAM), y
	iny
	cpy #32
	bne copy
	
	adw RAM_TO_VRAM #160
	dex
	bne copy_line
stop:
	jmp stop
	
message:
	.byte $11, $11, $11, $11
	.byte $22, $22, $22, $22
	.byte $33, $33, $33, $33
	.byte $44, $44, $44, $44
	.byte $55, $55, $55, $55
	.byte $66, $66, $66, $66
	.byte $77, $77, $77, $77
   .byte $88, $88, $88, $88

   icl '../os/stdlib.asm'
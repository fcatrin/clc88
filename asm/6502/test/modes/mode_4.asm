	icl '../../os/symbols.asm'
	
	org BOOTADDR
	
	lda #4
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
	
	mwa DISPLAY_START VRAM_TO_RAM
	jsr lib_vram_to_ram
	
	ldx #20
copy_line	
	ldy #0
copy:
	lda message, y
	sta (RAM_TO_VRAM), y
	iny
	cpy #28
	bne copy
	
	adw RAM_TO_VRAM #40
	dex
	bne copy_line
stop:
	jmp stop
	
message:
	.byte $AA, $AA, $AA, $AA
	.byte $55, $55, $55, $55
	.byte $A5, $A5, $A5, $A5
	.byte $FF, $FF, $FF, $FF
	.byte $00, $00, $11, $11
	.byte $22, $22, $33, $33
   .byte $64, $e6, $6e, $46

   icl '../../os/stdlib.asm'
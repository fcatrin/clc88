	icl '../os/symbols.asm'
	
	org BOOTADDR

   lda #0
   ldy #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
   
next_frame:
	lda FRAMECOUNT
wait:
	cmp FRAMECOUNT
	beq wait
	jsr keybscan
	jmp next_frame
	
keybscan:
    mwa DISPLAY_START VRAM_TO_RAM
    jsr lib_vram_to_ram

	lda #0
	sta KSTAT
	sta SCREENPOS

next_reg:
	ldy KSTAT
	lda KEY_STATUS, y
next_bit:
	rol
	sta STATUS
	lda #'0'
	bcc key_off
	lda #'1'
key_off:
    ldy SCREENPOS
	sta (RAM_TO_VRAM), y
	iny
	tya
	cpy #8
	beq next_row
	sty SCREENPOS
	lda STATUS
	jmp next_bit
	 
next_row:
	inc KSTAT 
	lda KSTAT
	cmp #16
	bne next_line
	rts
	
next_line:
	lda #0
	sta SCREENPOS
	adw RAM_TO_VRAM #40
	jmp next_reg

KSTAT     .byte 0
SCREENPOS .byte 0
STATUS    .byte 0	
	
   icl '../os/stdlib.asm'

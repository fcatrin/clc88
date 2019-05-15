	icl '../os/symbols.asm'
	
	org BOOTADDR
	
	lda #3
	ldx #OS_SET_VIDEO_MODE
	jsr OS_CALL
	lda #$92
	sta $F9
	
	ldy #0
copy:
	lda message, y
	cmp #255
	beq stop
	sta (TEXT_START), y
	iny
	bne copy
stop:
	jmp stop
	
message:
	.byte 40, 101, 108, 108, 111, 0, 55, 111, 114, 108, 100, 1, 1, 1, 1, 255


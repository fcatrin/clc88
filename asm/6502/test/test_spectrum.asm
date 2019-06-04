	icl '../os/symbols.asm'
	
	org BOOTADDR
	
	lda #1
	ldx #OS_SET_VIDEO_MODE
	jsr OS_CALL
	
	ldy #0
copy:
	lda message, y
	cmp #255
	beq stop
	sta (TEXT_START), y
	iny
	bne copy
stop:
	lda VCOUNT
	sta WSYNC
	sta VCOLOR0
	jmp stop
	
message:
	.byte 40, 101, 108, 108, 111, 0, 55, 111, 114, 108, 100, 1, 1, 1, 1, 255


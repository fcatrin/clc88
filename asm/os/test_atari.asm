	icl 'symbols.asm'
	
	org BOOTADDR
	
	lda #0
	ldx #OS_SET_VIDEO_MODE
	jsr OS_CALL
	
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
   clc
	lda VCOUNT
	adc FRAMECOUNT
	sta WSYNC
	sta VCOLOR0
	jmp rainbow
	
message:
	.byte 40, 101, 108, 108, 111, 0, 55, 111, 114, 108, 100, 1, 1, 1, 1, 255


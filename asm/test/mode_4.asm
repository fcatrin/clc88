	icl '../os/symbols.asm'
	
	org BOOTADDR
	
	lda #4
	ldx #OS_SET_VIDEO_MODE
	jsr OS_CALL
	lda #$92
	sta $F9
	sta VCOLOR0
	
	mwa SUBPAL_START VRAM_TO_RAM
	ldx #OS_VRAM_TO_RAM
	jsr OS_CALL
	lda VRAM_PAGE
	sta VPAGE
	
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
	ldx #OS_VRAM_TO_RAM
	jsr OS_CALL
	lda VRAM_PAGE
	sta VPAGE
	
	ldy #0
copy:
	lda message, y
	cmp #255
	beq stop
	sta (RAM_TO_VRAM), y
	iny
	bne copy
stop:
	jmp stop
	
message:
	.byte 40, 101, 108, 108, 111, 0, 55, 111, 114, 108, 100, 1, 1, 1, 1, 255


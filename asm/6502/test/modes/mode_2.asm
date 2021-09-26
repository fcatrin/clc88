	icl '../../os/symbols.asm'
	
	org BOOTADDR

   lda #2
   ldy #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

   mwa DISPLAY_START VADDR
	
	ldy #0
copy:
	lda message, y
	cmp #255
	beq stop
	sta VDATA
	iny
	bne copy

stop:
	jmp stop
	
message:
	.by "Hello world!!!!", 255

   icl '../../os/stdlib.asm'

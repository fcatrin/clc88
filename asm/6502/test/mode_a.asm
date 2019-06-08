	icl '../os/symbols.asm'
	
	org BOOTADDR

   lda #0
   sta ROS8
   lda #$0A
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
	

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

stop:
	jmp stop
	
message:
	.byte 40, 101, 108, 108, 111, 0, 55, 111, 114, 108, 100, 1, 1, 1, 1, 255

   icl '../os/stdlib.asm'

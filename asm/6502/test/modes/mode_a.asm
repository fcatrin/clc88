	icl '../../os/symbols.asm'
	
	org BOOTADDR

   lda #0
   sta ROS7
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
	.by "Hello world!!!!", 255

   icl '../../os/stdlib.asm'

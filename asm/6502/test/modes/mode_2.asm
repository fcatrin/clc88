	icl '../../os/symbols.asm'
	
	org BOOTADDR

   mva #1 ROS7
   lda #2
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

   mwa DISPLAY_START VADDRW
	
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

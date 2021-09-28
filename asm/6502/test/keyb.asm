	icl '../os/symbols.asm'
	
	org BOOTADDR

   lda #1
   sta ROS7
   lda #0
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
   adw DISPLAY_START #(18 + 4*40) DST_ADDR

	lda #0
	sta KSTAT

next_reg:
   mwa DST_ADDR VADDRW
	ldy KSTAT
	lda KEY_STATUS, y
	ldx #0
next_bit:
	rol
	sta STATUS
	lda #'0'
	bcc key_off
	lda #'1'
key_off:
   sta VDATA
	inx
	cpx #8
	beq next_row
	lda STATUS
	jmp next_bit
	 
next_row:
	inc KSTAT 
	lda KSTAT
	cmp #16
	bne next_line
	rts
	
next_line:
	adw DST_ADDR #40
	jmp next_reg

KSTAT     .byte 0
SCREENPOS .byte 0
STATUS    .byte 0	
	
   icl '../os/stdlib.asm'

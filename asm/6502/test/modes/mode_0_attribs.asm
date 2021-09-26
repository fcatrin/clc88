	icl '../../os/symbols.asm'
	
	org BOOTADDR

   lda #1
   sta ROS7
   lda #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

; copy test attrbutes
   mwa ATTRIB_START VADDR
   
   ldy #0
copy_attribs:   
   lda attribs, y
   beq display_message
   sta VDATA
   iny
   bne copy_attribs
   
display_message:
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
	.byte 'Hello world!', 255
attribs:	
	.byte $9F, $92, $1E, $E1, $01, $02, $03, $04, $21, $22, $23, $24
	.byte $1F, $2F, $3F, $4F, $5F, $00

   icl '../../os/stdlib.asm'

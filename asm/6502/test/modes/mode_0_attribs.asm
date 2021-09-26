	icl '../../os/symbols.asm'
	
	org BOOTADDR

   lda #1
   sta ROS7
   lda #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

   lda #$0F
   mwa ATTRIB_SIZE SIZE
   mwa ATTRIB_START VADDR
   jsr lib_vram_set
   

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
	.byte 40, 101, 108, 108, 111, 0, 55, 111, 114, 108, 100, 1, 1, 1, 1, 255
attribs:	
	.byte $0F, $01, $1E, $E1, $01, $02, $03, $04, $21, $22, $23, $24
	.byte $1F, $2F, $3F, $4F, $5F, $00

   icl '../../os/stdlib.asm'

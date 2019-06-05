	icl '../os/symbols.asm'
	
	org BOOTADDR

   lda #1
   sta ROS8
   lda #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

   mwa SUBPAL_START VRAM_TO_RAM
   jsr lib_vram_to_ram

   ldy #0
set_subpal:
   tya
   sta (RAM_TO_VRAM), y
   iny
   cpy #16
   bne set_subpal

   mwa ATTRIB_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   
   ldy #0
copy_attribs:   
   lda attribs, y
   beq display_message
   sta (RAM_TO_VRAM), y
   iny
   bne copy_attribs
   
display_message:
   mwa TEXT_START VRAM_TO_RAM
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
attribs:	
	.byte $0F, $F0, $1E, $E1, $01, $02, $03, $04, $21, $22, $23, $24
	.byte $1F, $2F, $3F, $4F, $5F, $00

   icl '../os/stdlib.asm'

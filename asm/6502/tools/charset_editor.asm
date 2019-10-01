   icl '../os/symbols.asm'
	
   org BOOTADDR

   lda #0
   ldy #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

   jsr prepare_editor_charset
   jsr display_charset
   
halt 
   jsr halt
   
.proc display_charset
   ldx #4
   ldy #19
   jsr screen_position

   ldx #0
next_row
   ldy #0
next_char
   txa
   sta (RAM_TO_VRAM), y
   inx
   iny
   cpy #32
   bne next_char
   adw RAM_TO_VRAM #40
   cpx #$80
   bne next_row
   rts
.endp

.proc prepare_editor_charset
   mwa CHARSET_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   adw RAM_TO_VRAM #8
   
   mwa #block_chars SRC_ADDR
   mwa RAM_TO_VRAM DST_ADDR
   mwa #5*8 SIZE
   jmp memcpy      
.endp

block_chars:
	.byte 0, 0, 0, 0, 0, 0, 0, 1
	.byte 0, 0, 0, 0, 0, 0, 0, 255
	.byte 1, 1, 1, 1, 1, 1, 1, 1
	.byte 1, 1, 1, 1, 1, 1, 1, 255
	.byte 255, 255, 255, 255, 255, 255, 255 ,255


   icl '../os/stdlib.asm'

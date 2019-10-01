   icl '../os/symbols.asm'
	
   org BOOTADDR

   lda #0
   ldy #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

   jsr prepare_editor_charset
   jsr draw_char_editor_borders
   jsr display_charset
   
   jsr draw_char_editor
   
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

.proc draw_char_editor_borders
   ldx #2
   ldy #2
   jsr screen_position
   
   lda #1
   ldy #0
   sta (RAM_TO_VRAM), y
   iny
   lda #2
border_top
   sta (RAM_TO_VRAM), y
   iny
   cpy #9
   bne border_top
   
   ldy #0
   ldx #8
border_left
   adw RAM_TO_VRAM #40
   lda #3
   sta (RAM_TO_VRAM), y
   dex
   bne border_left
   rts
.endp

.proc draw_char_editor
   mwa #0 SRC_ADDR
   lda char_index
   asl
   rol SRC_ADDR+1
   asl
   rol SRC_ADDR+1
   asl
   rol SRC_ADDR+1
   sta SRC_ADDR
   
   mwa CHARSET_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   adw SRC_ADDR RAM_TO_VRAM
   
   ldx #3
   ldy #3
   jsr screen_position
   
   mva #0 charset_index
   
   ldy #0
next_row
   lda (SRC_ADDR), y
   ldy #0
next_bit
   asl
   sta R0
   lda #4
   scc
   lda #5
   sta (RAM_TO_VRAM), y
   lda R0
   iny
   cpy #8
   bne next_bit
   
   adw RAM_TO_VRAM #40
   inc charset_index
   ldy charset_index
   cpy #8
   bne next_row
   rts
   
charset_index .byte 0
.endp

char_index
	.byte 65

block_chars:
	.byte 0, 0, 0, 0, 0, 0, 0, 1
	.byte 0, 0, 0, 0, 0, 0, 0, 255
	.byte 1, 1, 1, 1, 1, 1, 1, 1
	.byte 1, 1, 1, 1, 1, 1, 1, 255
	.byte 255, 255, 255, 255, 255, 255, 255 ,255


   icl '../os/stdlib.asm'

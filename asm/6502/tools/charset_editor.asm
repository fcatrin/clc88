   icl '../os/symbols.asm'
	
   org BOOTADDR

   lda #0
   ldy #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

   jsr display_charset
   
halt 
   jsr halt
   
.proc display_charset
   ldx #4
   ldy #15
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
   cpx #0
   bne next_row
   rts
   
   
.endp

   icl '../os/stdlib.asm'

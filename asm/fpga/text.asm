// screen handling routines (for the FPGA version)

.proc txt_put_char
   sta screen_char
   lda screen_state
   cmp #1
   beq set_attr
   lda screen_char
   and #$f0
   cmp #$f0
   beq control_char
   lda screen_char
   sta VDATA
   lda screen_attr
   sta VDATA_AUX
   rts
   
control_char
   lda screen_char
   and #$0f   
   beq set_state_attr
   rts
   
set_state_attr:
   lda #1
   sta screen_state
   rts
   
set_attr:
   lda screen_char
   sta screen_attr
   lda #0
   sta screen_state
   rts   
   
.endp

.proc txt_clear_screen
   sta screen_attr
   jsr init_screen_addr
  
   ldx SCREEN_SIZE+1
   inx
   ldy SCREEN_SIZE
next_write:   
   lda #$0
   sta VDATA
   lda screen_attr
   sta VDATA_AUX
   dey
   bne next_write
   dex
   bne next_write
   jmp init_screen_addr
.endp

.proc init_screen_addr
   mwa DISPLAY_START  VADDRW
   mwa ATTRIB_START   VADDRW_AUX
   rts  
.endp
   
   org $200
screen_state  .byte  0
screen_char   .byte  0   
screen_attr   .byte 0
      
  
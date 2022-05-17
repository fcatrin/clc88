.proc charset_on_key
   lda last_key
   cmp #16
   jeq charset_char_select_up
   cmp #17
   jeq charset_char_select_down
   cmp #14
   jeq charset_char_select_left
   cmp #15
   jeq charset_char_select_right
   rts
.endp

.proc charset_char_select_left
   dec charset_char_x
   spl
   mva #31 charset_char_x
   jmp charset_char_highlight
.endp

.proc charset_char_select_right
   inc charset_char_x
   lda charset_char_x
   cmp #32
   sne
   mva #0 charset_char_x
   jmp charset_char_highlight
.endp

.proc charset_char_select_up
   dec charset_char_y
   spl
   mva #3 charset_char_y
   jmp charset_char_highlight
.endp

.proc charset_char_select_down
   inc charset_char_y
   lda charset_char_y
   cmp #4
   sne
   mva #0 charset_char_y
   jmp charset_char_highlight
.endp

.proc charset_char_highlight
   jsr charset_char_update
   lda charset_char_y
   asl
   asl
   asl
   asl
   asl
   clc
   adc charset_char_x
   sta charset_char_index
   jmp draw_char_editor
.endp


.proc charset_char_update
   mwa charset_char_attrib_last RAM_TO_VRAM
   lda RAM_TO_VRAM
   ora RAM_TO_VRAM+1
   beq not_reset_attrib
   
   ldy #0
   mva #$9F (RAM_TO_VRAM),y
   
not_reset_attrib
   adb charset_char_x #CHARSET_POS_X screen_pos_x
   adb charset_char_y #CHARSET_POS_Y screen_pos_y
   ldx screen_pos_x
   ldy screen_pos_y
   jsr screen_position_attrib
   
   mwa RAM_TO_VRAM charset_char_attrib_last
   
   ldy #0
   mva #$2f (RAM_TO_VRAM),y
   rts
.endp   

charset_char_x .byte 0
charset_char_y .byte 0
charset_char_attrib_last .word 0

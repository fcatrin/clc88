.proc charpix_char_onkey
   cmp #16
   jeq charpix_char_select_up
   cmp #17
   jeq charpix_char_select_down
   cmp #14
   jeq charpix_char_select_left
   cmp #15
   jeq charpix_char_select_right
   cmp #66
   jeq charpix_toggle
   rts
.endp

.proc charpix_char_select_left
   dec charpix_char_x
   spl
   mva #7 charpix_char_x
   jmp charpix_char_highlight
.endp

.proc charpix_char_select_right
   inc charpix_char_x
   lda charpix_char_x
   cmp #8
   sne
   mva #0 charpix_char_x
   jmp charpix_char_highlight
.endp

.proc charpix_char_select_up
   dec charpix_char_y
   spl
   mva #7 charpix_char_y
   jmp charpix_char_highlight
.endp

.proc charpix_char_select_down
   inc charpix_char_y
   lda charpix_char_y
   cmp #8
   sne
   mva #0 charpix_char_y
   jmp charpix_char_highlight
.endp

.proc charpix_char_highlight
   jmp charpix_char_update
.endp

.proc charpix_char_update
   mwa charpix_char_attrib_last RAM_TO_VRAM
   lda RAM_TO_VRAM
   ora RAM_TO_VRAM+1
   beq not_reset_attrib
   
   ldy #0
   mva #$10 (RAM_TO_VRAM),y
   
not_reset_attrib
   adb charpix_char_x #CHARPIX_POS_X screen_pos_x
   adb charpix_char_y #CHARPIX_POS_Y screen_pos_y
   ldx screen_pos_x
   ldy screen_pos_y
   jsr screen_position_attrib
   
   mwa RAM_TO_VRAM charpix_char_attrib_last
   
   ldy #0
   mva #$23 (RAM_TO_VRAM),y
   rts
.endp

.proc charpix_toggle
   jsr get_char_addr

   adb SRC_ADDR charpix_char_y
   scc
   inc SRC_ADDR+1
   
   ldy #0
   ldx charpix_char_x
   lda charpix_bitmask, x
   tax
   
   and (SRC_ADDR), y
   beq set_on
   txa
   eor #$FF
   and (SRC_ADDR), y
   sta (SRC_ADDR), y
   jmp draw_char_editor
   
set_on:
   txa
   ora (SRC_ADDR), y
   sta (SRC_ADDR), y
   jmp draw_char_editor
.endp   

charpix_char_x .byte 0
charpix_char_y .byte 0
charpix_char_attrib_last .word 0
charpix_bitmask .byte 128, 64, 32, 16, 8, 4, 2, 1

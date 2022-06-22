.proc charpix_on_key
   lda last_key
   beq no_key
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
no_key:
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
   mwa charpix_char_attrib_last VADDRB
   lda VADDRB
   ora VADDRB+1
   beq not_reset_attrib

   mva #$01 VDATA
   
not_reset_attrib
   adb charpix_char_x #CHARPIX_POS_X screen_pos_x
   adb charpix_char_y #CHARPIX_POS_Y screen_pos_y
   ldx screen_pos_x
   ldy screen_pos_y
   jsr screen_position_attrib
   
   mwa VADDRB_AUX charpix_char_attrib_last
   mva #$10 VDATA_AUX
   rts
.endp

.proc charpix_toggle
   jsr get_char_addr
   mwa SRC_ADDR VADDR

   adb VADDRB charpix_char_y
   scc
   inc VADDRB+1

   mva #AUTOINC_KEEP VAUTOINC

   ldx charpix_char_x
   lda charpix_bitmask, x
   tax
   
   and VDATA
   beq set_on
   txa
   eor #$FF
   and VDATA
   sta VDATA
   jmp bit_done
   
set_on:
   txa
   ora VDATA
   sta VDATA

bit_done
   mva #AUTOINC_INC VAUTOINC
   jmp draw_char_editor
.endp   

charpix_char_x .byte 0
charpix_char_y .byte 0
charpix_char_attrib_last .word 0
charpix_bitmask .byte 128, 64, 32, 16, 8, 4, 2, 1

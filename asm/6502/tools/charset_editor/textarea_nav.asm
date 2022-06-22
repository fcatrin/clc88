.proc textarea_on_key
   lda last_key
   cmp #16
   jeq textarea_select_up
   cmp #17
   jeq textarea_select_down
   cmp #14
   jeq textarea_select_left
   cmp #15
   jeq textarea_select_right
   rts
.endp

.proc textarea_select_left
   dec textarea_x
   spl
   mva #35 textarea_x
   jmp textarea_highlight
.endp

.proc textarea_select_right
   inc textarea_x
   lda textarea_x
   cmp #36
   sne
   mva #0 textarea_x
   jmp textarea_highlight
.endp

.proc textarea_select_up
   dec textarea_y
   spl
   mva #3 textarea_y
   jmp textarea_highlight
.endp

.proc textarea_select_down
   inc textarea_y
   lda textarea_y
   cmp #4
   sne
   mva #0 textarea_y
   jmp textarea_highlight
.endp

.proc textarea_highlight
   jmp textarea_update
.endp


.proc textarea_update
   mwa textarea_attrib_last VADDRB
   lda VADDRB
   ora VADDRB+1
   beq not_reset_attrib
   
   mva #$01 VDATA
   
not_reset_attrib
   adb textarea_x #TEXTAREA_POS_X screen_pos_x
   adb textarea_y #TEXTAREA_POS_Y screen_pos_y
   ldx screen_pos_x
   ldy screen_pos_y
   jsr screen_position_attrib
   
   mwa VADDRB_AUX textarea_attrib_last
   mva #$10 VDATA_AUX
   rts
.endp   

textarea_x .byte 0
textarea_y .byte 0
textarea_attrib_last .word 0

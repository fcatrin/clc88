   icl '../os/include/symbols.asm'

POS_BASE = 22*80+9
POS_CAPS  = POS_BASE
POS_SHIFT = POS_CAPS  + 6 
POS_CTRL  = POS_SHIFT + 7
POS_ALT   = POS_CTRL  + 6
BORDER_COLOR = $2167

    org USERADDR

    mwa #BORDER_COLOR VBORDER

    mwa #palette_dark SRC_ADDR
    jsr gfx_upload_palette

    mva #01 ATTRIB_DEFAULT
    lda #0
    ldx #OS_SET_VIDEO_MODE
    jsr OS_CALL

    lda VSTATUS
    ora VSTATUS_EN_INTS
    sta VSTATUS

    jsr calc_screen_offset
   
next_frame:
    lda FRAMECOUNT
wait:
    cmp FRAMECOUNT
    beq wait

    ldx #OS_KEYB_POLL
    jsr OS_CALL

    lda KEY_PRESSED
    cmp last_key_pressed
    bne new_key
    lda in_auto_repeat
    bne do_auto_repeat

    lda auto_repeat_wait_max
    cmp auto_repeat_wait
    beq auto_repeat_start

    inc auto_repeat_wait
    jmp ignore_key

auto_repeat_start:
    lda #1
    sta in_auto_repeat
    jmp repeat_key
   
do_auto_repeat:
    lda auto_repeat_delay_max
    cmp auto_repeat_delay
    bne keep_waiting
    lda #0
    sta auto_repeat_delay
    jmp repeat_key
keep_waiting:
    inc auto_repeat_delay
    jmp ignore_key
   
new_key
    sta last_key_pressed
    lda #0
    sta auto_repeat_wait
    sta auto_repeat_delay
    sta in_auto_repeat
   
repeat_key:   
    jsr cursor_off
    jsr print_key
   
ignore_key:
    jsr cursor_on
    jsr keybprint
    jmp next_frame
	
keybprint:
    lda #$ff
    sta R5
    lda caps
    beq no_caps
    lda #$df
    sta R5

no_caps:
    jsr print_caps

    lda #$ff
    sta R5
    lda KEY_META
    and #KEY_META_SHIFT
    beq no_shift
    lda #$df
    sta R5
	
no_shift:
    jsr print_shift

    lda #$ff
    sta R5
    lda KEY_META
    and #KEY_META_CTRL
    beq no_ctrl
    lda #$df
    sta R5
no_ctrl:
    jsr print_ctrl
	
    lda #$ff
    sta R5
    lda KEY_META
    and #KEY_META_ALT
    beq no_alt
    lda #$df
    sta R5
no_alt:
    jmp print_alt
	
print_caps:
    mwa #key_caps R0
    mwa #POS_CAPS R2
    jmp print

print_shift:
    mwa #key_shift R0
    mwa #POS_SHIFT R2
    jmp print

print_ctrl:
    mwa #key_ctrl R0
    mwa #POS_CTRL R2
    jmp print

print_alt:
    mwa #key_alt R0
    mwa #POS_alt R2
    jmp print

print:
    mwa DISPLAY_START VADDR
    adw VADDRB R2

    ldy #0
print_c:
    lda (R0), y
    beq end_print
    and R5
    sta VDATA
    iny
    bne print_c
end_print:
    rts

print_key:
    lda KEY_META
    and #KEY_META_SHIFT
    beq print_key_noshift
    lda last_key_pressed
    cmp #14
    jeq cursor_home
    cmp #15
    jeq cursor_end

print_key_noshift
    lda KEY_META
    and #KEY_META_CTRL
    beq print_key_noctrl
    lda last_key_pressed
    cmp #14
    jeq word_prev
    cmp #15
    jeq word_next
   
print_key_noctrl:   
    lda last_key_pressed
    cmp #46
    jeq line_feed
    cmp #14
    jeq cursor_left
    cmp #15
    jeq cursor_right
    cmp #16
    jeq cursor_up
    cmp #17
    jeq cursor_down
    cmp #32
    jeq backspace
    cmp #47
    jeq caps_toggle

    jsr calc_screen_offset
    mwa DISPLAY_START VADDR
    adw VADDRB pos_offset

    mwa #key_conversion_shift R0
    lda KEY_META
    and #KEY_META_SHIFT
    bne search_key_start

    MWA #key_conversion_alt R0
    lda KEY_META
    and #KEY_META_ALT
    bne search_key_start

    MWA #key_conversion_normal R0

search_key_start:
    ldy #0
search_key:   
    lda (R0), y
    beq end_print_key
    cmp last_key_pressed
    bne next_char
    iny
    lda (R0), y
    ldx caps
    beq normal_key

    cmp #'A'
    bcc normal_key
    cmp #'Z'+1
    bcs check_lower
    ora #$20
    jmp normal_key

check_lower   
    cmp #'a'
    bcc normal_key
    cmp #'z'+1
    bcs normal_key

alpha_key:   
    and #$DF

normal_key:
    sta VDATA
    inc pos_x
    lda pos_x
    cmp #80
    jeq line_feed
    rts
next_char:   
    iny
    iny
    bne search_key
end_print_key:
    rts

calc_screen_offset:
    mwa #0 pos_offset

    // pos_offset = y*64
    lda pos_y
    asl
    rol pos_offset+1
    asl
    rol pos_offset+1
    asl
    rol pos_offset+1
    asl
    rol pos_offset+1
    asl
    rol pos_offset+1
    asl
    rol pos_offset +1
    sta pos_offset

    // pos_offset += y*16   => pos_offset = y*(64+16 from above)
    mva #0 pos_offset_aux
    lda pos_y
    asl
    rol pos_offset_aux
    asl
    rol pos_offset_aux
    asl
    rol pos_offset_aux
    asl
    rol pos_offset_aux
    clc
    adc pos_offset
    sta pos_offset
    lda pos_offset_aux
    adc pos_offset+1
    sta pos_offset+1

    // add x
    clc
    lda pos_x
    adc pos_offset
    sta pos_offset
    lda #0
    adc pos_offset+1
    sta pos_offset+1
    rts

backspace:
    lda pos_x
    cmp #0
    beq backspace_wrap_left
    dec pos_x
    jmp backspace_del
backspace_wrap_left:
    lda pos_y
    cmp #0
    beq backspace_abort
    lda #79
    sta pos_x
    dec pos_y
backspace_del:
    mwa DISPLAY_START VADDR
    jsr calc_screen_offset
    adw VADDRB pos_offset
    mva #0 VDATA
backspace_abort:
    rts
   
line_feed:
    lda pos_y
    cmp #24
    beq line_feed_end
    lda #0
    sta pos_x
    inc pos_y
line_feed_end
    rts

cursor_left:
    lda pos_x
    cmp #0
    beq cursor_wrap_left
    dec pos_x
    jmp calc_screen_offset
cursor_wrap_left:
    lda #79
    sta pos_x
    jmp calc_screen_offset
   
cursor_right:
    lda pos_x
    cmp #79
    beq cursor_wrap_right
    inc pos_x
    jmp calc_screen_offset
cursor_wrap_right:   
    lda #0
    sta pos_x
    jmp calc_screen_offset

cursor_up:
    lda pos_y
    cmp #0
    beq cursor_wrap_up
    dec pos_y
    jmp calc_screen_offset
cursor_wrap_up:   
    lda #20
    sta pos_y
    jmp calc_screen_offset

cursor_down:
    lda pos_y
    cmp #20
    beq cursor_wrap_down
    inc pos_y
    jmp calc_screen_offset
cursor_wrap_down:   
    lda #0
    sta pos_y
    jmp calc_screen_offset

cursor_on:
    lda #1
    sta is_cursor_on
    lda #$10
    jmp change_cursor_attr

cursor_off:
    lda #0
    sta is_cursor_on
    lda #$01
change_cursor_attr:
    pha
    jsr calc_screen_offset
    mwa ATTRIB_START VADDR
    adw VADDRB pos_offset
    pla
    sta VDATA
    rts

cursor_home:
    lda pos_x
    sta R0
    bne cursor_home_start
    rts
   
cursor_home_start:   
    lda #0
    sta pos_x
    jsr calc_screen_offset
    adw VADDRB pos_offset

    ldy #0
cursor_home_next:   
    lda VDATA
    bne cursor_home_found
    iny
    cpy R0
    bne cursor_home_next
    ldy #0
cursor_home_found:
    sty pos_x
    jmp calc_screen_offset

cursor_end:
    mwa DISPLAY_START VADDR
    lda pos_x
    sta R0
    cmp #79
    bne cursor_end_start
    rts

cursor_end_start:   
    lda #0
    sta pos_x
    jsr calc_screen_offset
    adw VADDRB pos_offset

    ldy #79
cursor_end_next:   
    lda VDATA
    bne cursor_end_found
    dey
    cpy R0
    bne cursor_end_next
    ldy #79
cursor_end_found:
    sty pos_x
    jmp calc_screen_offset

word_prev:
    ldx #1

word_prev_next:
    mwa DISPLAY_START VADDR
    mwa pos_x pos_save

    lda pos_x
    bne word_prev_x
    lda pos_y
    bne word_prev_y
    rts
word_prev_y:
    lda #79
    sta pos_x
    dec pos_y
    jmp word_prev_start

word_prev_x:
    dec pos_x

word_prev_start:
    jsr calc_screen_offset
    adw VADDRB pos_offset
    lda VDATA
    bne word_prev_next
    cpx #1
    bne word_prev_end
    dex
    jmp word_prev_next
word_prev_end:   
    mwa pos_save pos_x
    rts

word_next:
    mwa DISPLAY_START display_base
      
word_next_next:
    mwa display_base VADDR

    lda pos_x
    cmp #79
    bne word_next_x
    lda pos_y
    cmp #22
    bne word_next_y
    rts
word_next_y:
    lda #0
    sta pos_x
    inc pos_y
    jmp word_next_start

word_next_x:
    inc pos_x

word_next_start:
    jsr calc_screen_offset
    adw VADDRB pos_offset
    lda VDATA
    bne word_next_next
    rts

caps_toggle:
    lda caps
    eor #1
    sta caps
    rts

last_key_pressed:
    .byte 0

palette_dark:
    .word $2104
    .word $9C0A
    .word $BC0E
    .word $43B5

is_cursor_on: .byte 0
   
pos_x:  .byte 0
pos_y:  .byte 0
pos_offset:     .word 0
pos_offset_aux: .byte 0
pos_save:       .word 0

in_auto_repeat: .byte 0
auto_repeat_wait:  .byte 0
auto_repeat_delay: .byte 0

auto_repeat_wait_max:  .byte 20
auto_repeat_delay_max: .byte 3

caps: .byte 1

display_base: .word 0

key_caps:
    .byte 'caps', 0
key_shift:
    .byte 'shift', 0
key_ctrl:
    .byte 'ctrl', 0
key_alt:
    .byte 'alt', 0

    icl '../os/graphics.asm'
    icl '../os/ram_vram.asm'
    icl '../os/libs/keyboard.asm'
    icl '../os/libs/stdlib.asm'

    org EXECADDR
    .word USERADDR
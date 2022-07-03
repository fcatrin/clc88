   icl '../../os/include/symbols.asm'

BORDER_COLOR = $2167
DLIST_ADDR = $0200

ROWS = 30

VRAM_SCREEN_DATA_ADDR = $0400

    org USERADDR
   
start:   
    mwa #BORDER_COLOR VBORDER

    mwa #dlist_addr VDLIST
    mwa #dlist_addr VADDR

    mwa #display_list SRC_ADDR
    ldx display_list_size
    jsr gfx_upload_short

    lda VSTATUS
    ora #VSTATUS_ENABLE
    sta VSTATUS

    mwa #tiles_palette SRC_ADDR
    jsr gfx_upload_palette

    mwa #screen_data_size SIZE
    mwa #screen_data SRC_ADDR
    mwa #VRAM_SCREEN_DATA_ADDR VADDR
    jsr gfx_upload_data

    mwa tile_patterns_size SIZE
    mwa #tile_patterns SRC_ADDR
    mwa tile_vram_address VADDR
    jsr gfx_upload_data

    mwa #dlist_addr vram_scroll_addr
    adw vram_scroll_addr #3

main_loop:
    lda FRAMECOUNT
wait_frame:
    cmp FRAMECOUNT
    beq wait_frame

    lda scroll_speed_x
    beq do_scroll_y
    inc frame_wait_x
    lda frame_wait_x
    cmp scroll_speed_x
    bne do_scroll_y
    mva #0 frame_wait_x

    inc dl_scroll_fine_x
    lda dl_scroll_fine_x
    and #7
    sta dl_scroll_fine_x
    bne do_scroll_y

    ldx dl_scroll_left
    inx
    cpx dl_scroll_width
    bne write_scroll_x
    ldx #0
write_scroll_x:
    stx dl_scroll_left

do_scroll_y:
    lda scroll_speed_y
    beq send_scroll
    inc frame_wait_y
    lda frame_wait_y
    cmp scroll_speed_y
    bne send_scroll
    mva #0 frame_wait_y

    inc dl_scroll_fine_y
    lda dl_scroll_fine_y
    and #7
    sta dl_scroll_fine_y
    bne send_scroll

    ldx dl_scroll_top
    inx
    cpx dl_scroll_height
    bne write_scroll_y
    ldx #0
write_scroll_y
    stx dl_scroll_top

send_scroll:
    mwa vram_scroll_addr VADDR
    ldx #0
next_scroll_value:
    lda dl_scroll_left, x
    sta VDATA
    inx
    cpx #4
    bne next_scroll_value
    jsr adjust_speed
    jmp main_loop

adjust_speed:
    lda BUTTONS
    and #1
    bne btn_1_is_down
    sta btn_1_status
    lda BUTTONS
    and #2
    bne btn_2_is_down
    sta btn_2_status
    rts

btn_1_is_down:
    lda btn_1_status
    bne btn_1_wait_for_release
    mva #1 btn_1_status
    mva #0 frame_wait_x
    ldx scroll_speed_x
    inx
    cpx #3
    bne no_reset_speed_x
    ldx #0
no_reset_speed_x:
    stx scroll_speed_x
btn_1_wait_for_release:
    rts

btn_2_is_down:
    lda btn_2_status
    bne btn_2_wait_for_release
    mva #1 btn_2_status
    mva #0 frame_wait_y
    ldx scroll_speed_y
    inx
    cpx #3
    bne no_reset_speed_y
    ldx #0
no_reset_speed_y
    stx scroll_speed_y
btn_2_wait_for_release:
    rts


display_list:
    .word $23F0
    .word VRAM_SCREEN_DATA_ADDR
dl_scroll_width  .byte 32
dl_scroll_height .byte 26
dl_scroll_left   .byte 0
dl_scroll_top    .byte 0
dl_scroll_fine_x .byte 0
dl_scroll_fine_y .byte 0

    .word $0f00

display_list_size:
    .byte * - display_list + 1

vram_scroll_addr   .word 0

frame_wait_x .byte 0
frame_wait_y .byte 0

scroll_speed_x .byte 0
scroll_speed_y .byte 0

btn_1_status .byte 0
btn_2_status .byte 0

    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/libs/stdlib.asm'
    icl '../include/gfx/set_01/palette.asm'
    icl '../include/gfx/set_01/screen.asm'
    icl '../include/gfx/set_01/tiles.asm'

    org EXECADDR
    .word start
   
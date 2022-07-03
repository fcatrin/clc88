   icl '../../os/include/symbols.asm'

   org USERADDR

BORDER_COLOR = $2167
DLIST_ADDR = $0200
VRAM_SCREEN_CHAR_ADDR = $0400
VRAM_SCREEN_ATTR_ADDR = $0a00

start
    mwa #BORDER_COLOR VBORDER
    mwa #VRAM_SCREEN_CHAR_ADDR DISPLAY_START
    mwa #VRAM_SCREEN_ATTR_ADDR ATTRIB_START
    mwa #dlist_addr VDLIST
    mwa #dlist_addr VADDR

    mwa #display_list SRC_ADDR
    ldx display_list_size
    jsr gfx_upload_short

    jsr text_test

    mwa #dlist_addr vram_scroll_left_addr
    adw vram_scroll_left_addr #4

    mwa #dlist_addr vram_scroll_fine_x_addr
    adw vram_scroll_fine_x_addr #5

main_loop:
    lda FRAMECOUNT
wait_frame:
    cmp FRAMECOUNT
    beq wait_frame

    inc frame_wait
    lda frame_wait
    cmp #2
    bne main_loop
    mva #0 frame_wait

    inc dl_scroll_fine_x
    lda dl_scroll_fine_x
    and #7
    tay
    sta dl_scroll_fine_x
    bne write_fine_scroll_x

    ldx dl_scroll_left
    inx
    cpx dl_scroll_width
    bne write_scroll_x
    ldx #0
write_scroll_x:
    mwa vram_scroll_left_addr VADDR
    stx VDATA
    stx dl_scroll_left
write_fine_scroll_x
    mwa vram_scroll_fine_x_addr VADDR
    sty VDATA

    jmp main_loop


display_list:
    .word $21F0
    .word VRAM_SCREEN_CHAR_ADDR
    .word VRAM_SCREEN_ATTR_ADDR
dl_scroll_width  .byte 100
dl_scroll_height .byte 3
dl_scroll_left   .byte 0
dl_scroll_top    .byte 1
dl_scroll_fine_x .byte 0
dl_scroll_fine_y .byte 2
    .word $0f00
display_list_size:
    .byte * - display_list + 1

vram_scroll_left_addr   .word 0
vram_scroll_fine_x_addr .word 0
frame_wait .byte 0

    icl '../../test/include/text_test.asm'
    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/text.asm'
    icl '../../os/libs/stdlib.asm'

    org EXECADDR
    .word start
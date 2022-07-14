   icl '../../os/include/symbols.asm'

BORDER_COLOR = $0000
DLIST_ADDR = $0200

pixels_width = 240
pitch        = pixels_width / 4
top_lines    = 100
image_height = 120
bottom_lines = 20

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

    mwa #palette SRC_ADDR
    jsr gfx_upload_palette

    mwa #pixel_data            SRC_ADDR
    mwa #VRAM_SCREEN_DATA_ADDR DST_ADDR
    adw DST_ADDR #(pitch*top_lines)
    jsr rle_uncompress_16

main_loop:
    lda FRAMECOUNT
wait_frame:
    cmp FRAMECOUNT
    beq wait_frame
    inc dl_scroll_fine_x
    lda dl_scroll_fine_x
    cmp #8
    bne push_scroll
    mva #0 dl_scroll_fine_x
    inc dl_scroll_left
    lda dl_scroll_left
    cmp dl_scroll_width
    bne push_scroll
    mva #0 dl_scroll_left

push_scroll:
    mwa #(DLIST_ADDR+3) VADDR
    mva dl_scroll_left VDATA
    lda VDATA
    mva dl_scroll_fine_x VDATA
    jmp main_loop


display_list:
    .word $24F0
    .word VRAM_SCREEN_DATA_ADDR
dl_scroll_width  .byte 60
dl_scroll_height .byte 30
dl_scroll_left   .byte 0
dl_scroll_top    .byte 0
dl_scroll_fine_x .byte 0
dl_scroll_fine_y .byte 0
    .word $0f00

display_list_size:
    .byte * - display_list + 1

    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/libs/stdlib.asm'

    icl '../include/rle_16.asm'
    icl '../include/gfx/bitmap_05/palette.asm'
    icl '../include/gfx/bitmap_05/image.asm'

    org EXECADDR
    .word start
   
   icl '../../os/include/symbols.asm'

BORDER_COLOR = $0000
DLIST_ADDR = $0200

pixels_width = 480
pitch        = pixels_width / 2
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

    mwa #(pixels_width*top_lines) SIZE
    mwa #VRAM_SCREEN_DATA_ADDR DST_ADDR
    mwa DST_ADDR VADDR
fill_top:
    lda #$33
    sta VDATA
    dew SIZE
    lda SIZE
    ora SIZE+1
    bne fill_top

    mwa #(pixels_width*bottom_lines) SIZE
    mwa #VRAM_SCREEN_DATA_ADDR DST_ADDR
    adw DST_ADDR #(pitch*(top_lines+image_height))
    mwa DST_ADDR VADDR
fill_bottom:
    lda #$1f
    sta VDATA
    dew SIZE
    lda SIZE
    ora SIZE+1
    bne fill_bottom

    mwa #pixel_data            SRC_ADDR
    mwa #VRAM_SCREEN_DATA_ADDR DST_ADDR
    adw DST_ADDR #(pitch*top_lines)
    jsr rle_uncompress_256

main_loop:
    jmp main_loop

display_list:
    .word $25F0
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

    icl '../include/rle_256.asm'
    icl '../include/gfx/bitmap_03/palette.asm'
    icl '../include/gfx/bitmap_03/image.asm'

    org EXECADDR
    .word start
   
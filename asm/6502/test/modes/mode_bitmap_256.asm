   icl '../../os/include/symbols.asm'

BORDER_COLOR = $9439
DLIST_ADDR = $0200

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

    mwa #BORDER_COLOR palette ; patch index 0 with sky color

    mwa #palette SRC_ADDR
    jsr gfx_upload_palette

    mwa #pixel_data            SRC_ADDR
    mwa #VRAM_SCREEN_DATA_ADDR DST_ADDR
    adw DST_ADDR #10240
    jsr rle_uncompress_256

main_loop:
    jmp main_loop

display_list:
    .word $15F0
    .word VRAM_SCREEN_DATA_ADDR
    .word $0f00

display_list_size:
    .byte * - display_list + 1

    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/libs/stdlib.asm'

    icl '../include/rle_256.asm'
    icl '../include/gfx/bitmap_02/image.asm'
    icl '../include/gfx/bitmap_02/palette.asm'

    org EXECADDR
    .word start
   
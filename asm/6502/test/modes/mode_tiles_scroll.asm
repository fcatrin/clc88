   icl '../../os/include/symbols.asm'

BORDER_COLOR = $2167
DLIST_ADDR = $0200

ROWS = 30

VRAM_SCREEN_DATA_ADDR = $0400

    org USERADDR
   
start:   
    mwa #BORDER_COLOR VBORDER

    mwa #dlist_addr VDLIST
    mwa #dlist_addr VADDRW
   
    ldx #0
copy_dl:
    lda display_list, x
    sta VDATA
    inx
    cpx display_list_size
    bne copy_dl

    lda VSTATUS
    ora #VSTATUS_ENABLE
    sta VSTATUS

    mwa #tiles_palette SRC_ADDR
    jsr gfx_upload_palette

    mwa #screen_data_size SIZE
    mwa #screen_data SRC_ADDR
    mwa #VRAM_SCREEN_DATA_ADDR VADDRW
    ldy #0
upload_screen_data:
    lda (SRC_ADDR), y
    sta VDATA
    inw SRC_ADDR
    dew SIZE
    lda SIZE
    ora SIZE+1
    bne upload_screen_data

    mwa tile_patterns_size SIZE
    mwa #tile_patterns SRC_ADDR
    mwa tile_vram_address VADDRW
    ldy #0
upload_tiles_data:
    lda (SRC_ADDR), y
    sta VDATA
    inw SRC_ADDR
    dew SIZE
    lda SIZE
    ora SIZE+1
    bne upload_tiles_data

halt:
    jmp halt

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

    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/libs/stdlib.asm'
    icl '../include/gfx/set_01/palette.asm'
    icl '../include/gfx/set_01/screen.asm'
    icl '../include/gfx/set_01/tiles.asm'

    org EXECADDR
    .word start
   
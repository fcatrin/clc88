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

halt:
    jmp halt

display_list:
    .word $13F0
    .word VRAM_SCREEN_DATA_ADDR
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
   
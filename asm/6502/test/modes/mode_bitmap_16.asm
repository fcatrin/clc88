   icl '../../os/include/symbols.asm'

BORDER_COLOR = $2167
DLIST_ADDR = $0200

VRAM_SCREEN_DATA_ADDR = $0400

    org USERADDR
   
start:   
    mwa #BORDER_COLOR VBORDER

    mwa #dlist_addr VDLIST
    mwa #dlist_addr VADDR
   
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

    mwa #bitmap_palette SRC_ADDR
    jsr gfx_upload_palette

    mwa pixel_data_size SIZE
    mwa #pixel_data SRC_ADDR
    mwa #VRAM_SCREEN_DATA_ADDR VADDR
    ldy #0
upload_screen_data:
    lda (SRC_ADDR), y
    sta VDATA
    inw SRC_ADDR
    dew SIZE
    lda SIZE
    ora SIZE+1
    bne upload_screen_data

halt:
    jmp halt

display_list:
    .word $04F0
    .word VRAM_SCREEN_DATA_ADDR
    .word $0f00

display_list_size:
    .byte * - display_list + 1

bitmap_palette:
    .word $0000, $6a44, $b364, $9244, $2124, $4a49, $4a44, $9489, $0240, $0360, $0480, $06c0, $4fe0, $97e4, $b7e9, $fecd
    .word $0000, $4a44, $9364, $dc84, $b364, $6a44, $b364, $9244, $0004, $200d, $4a56, $6b6d, $9492, $f800, $249f, $ffff
    .word $0000, $4a44, $9364, $dc84, $b364, $6a44, $b364, $9244, $0240, $2360, $4da0, $dda0, $4a40, $fec0, $fff2, $fffb
    .word $0000, $4a40, $9364, $dc84, $b364, $6a44, $2124, $6a4d, $6b72, $b5bb, $dedf, $dfff, $0012, $0016, $001f, $ffff
    .word $0000, $4a44, $9364, $dc84, $b364, $6a44, $b364, $9244, $4b76, $95bf, $b000, $f800, $ffff, $2124, $9240, $dc80
    .word $0000, $9364, $dc84, $b364, $2124, $4a49, $4a44, $9489, $0240, $0360, $0480, $06c0, $4fe0, $97e4, $b7e9, $fecd

    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/libs/stdlib.asm'

    icl '../include/gfx/bitmap/image.asm'

    org EXECADDR
    .word start
   
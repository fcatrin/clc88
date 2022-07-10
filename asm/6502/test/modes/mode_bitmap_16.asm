   icl '../../os/include/symbols.asm'

BORDER_COLOR = $2167
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

    mwa #palette SRC_ADDR
    jsr gfx_upload_palette

    mwa #pixel_data            SRC_ADDR
    mwa #VRAM_SCREEN_DATA_ADDR DST_ADDR
    jsr rle_uncompress_16

main_loop:
    lda FRAMECOUNT
wait_frame
    cmp FRAMECOUNT
    beq wait_frame

    ldx #OS_KEYB_POLL
    jsr OS_CALL

    lda KEY_PRESSED
    cmp last_key
    beq wait_frame
    sta last_key
    cmp #0
    beq wait_frame

    lda palette_index
    eor #1
    sta palette_index
    bne set_palette_natural
    mwa #palette SRC_ADDR
    jmp set_palette
set_palette_natural
    mwa #palette_natural SRC_ADDR
set_palette:
    jsr gfx_upload_palette
    jmp main_loop

display_list:
    .word $04F0
    .word VRAM_SCREEN_DATA_ADDR
    .word $0f00

display_list_size:
    .byte * - display_list + 1

palette_index  .byte 0
last_key       .byte 0

palette_natural:
    .word $0863, $7144, $2a0f, $712b, $a145, $99a5, $218c, $9964
    .word $b2f2, $1af2, $ba2b, $dd6f, $74c7, $b352, $fdc6, $e6d7


    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/libs/stdlib.asm'

    icl '../include/rle_16.asm'
    icl '../include/gfx/bitmap/image.asm'
    icl '../include/gfx/bitmap/palette.asm'

    org EXECADDR
    .word start
   
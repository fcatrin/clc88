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

    ldy #0
    mwa #pixel_data SRC_ADDR

copy_limits:
    lda (SRC_ADDR), y
    sta rle_end_addr_even, y
    iny
    cpy #4
    bne copy_limits

    adw rle_end_addr_even #pixel_data
    adw rle_end_addr_odd  #pixel_data
    adw SRC_ADDR #4

    mwa rle_end_addr_even rle_end_addr
    mwa #VRAM_SCREEN_DATA_ADDR VADDR
upload_screen_data_even:
    jsr rle_decode
    cmp #$ff
    beq odd_pixels

    sta VDATA
    jmp upload_screen_data_even

odd_pixels:
    mwa rle_end_addr_odd rle_end_addr
    mwa #VRAM_SCREEN_DATA_ADDR VADDR
    mwa #VRAM_SCREEN_DATA_ADDR VADDR_AUX
upload_screen_data_odd:
    jsr rle_decode
    cmp #$ff
    beq main_loop

    asl
    asl
    asl
    asl
    ora VDATA
    sta VDATA_AUX
    jmp upload_screen_data_odd

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

rle_decode
    lda size_rle_raw
    bne cont_rle_raw
    lda size_rle
    bne cont_rle

    lda rle_raw_nibble
    beq nibble_complete
    mva #0 rle_raw_nibble
    inw SRC_ADDR

nibble_complete:
    cpw SRC_ADDR rle_end_addr
    bne next_rle_block
    lda #$ff
    rts

next_rle_block:
    ldy #0
    lda (SRC_ADDR), y
    bmi process_as_rle
    tay
    and #$70
    lsr
    lsr
    lsr
    lsr
    sta size_rle_raw
    mva #0 rle_raw_nibble
    tya
    and #$0f
    jmp rle_inc_and_ret

process_as_rle
    tay
    and #$70
    lsr
    lsr
    lsr
    lsr
    sta size_rle
    tya
    and #$0f
    sta data_rle

rle_inc_and_ret
    inw SRC_ADDR
    rts

cont_rle_raw:
    dec size_rle_raw
    ldy #0
    lda (SRC_ADDR), y
    tax
    lda rle_raw_nibble
    eor #$1
    sta rle_raw_nibble
    beq low_nibble
    txa
    lsr
    lsr
    lsr
    lsr
    rts
low_nibble
    inw SRC_ADDR
    txa
    and #$0f
    rts

cont_rle:
    dec size_rle
    lda data_rle
    rts

palette_index  .byte 0
last_key       .byte 0
size_rle_raw   .byte 0
size_rle       .byte 0
data_rle       .byte 0
rle_raw_nibble .byte 0
rle_end_addr      .word 0
rle_end_addr_even .word 0
rle_end_addr_odd  .word 0

palette_natural:
    .word $0863, $7144, $2a0f, $712b, $a145, $99a5, $218c, $9964
    .word $b2f2, $1af2, $ba2b, $dd6f, $74c7, $b352, $fdc6, $e6d7


    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/libs/stdlib.asm'

    icl '../include/gfx/bitmap/image.asm'
    icl '../include/gfx/bitmap/palette.asm'

    org EXECADDR
    .word start
   
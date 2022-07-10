; requires
; SRC_ADDR : compressed image address
; DST_ADDR : vram address

.proc rle_uncompress_256
    ldy #0

copy_limits:
    lda (SRC_ADDR), y
    sta rle_end_addr_even, y
    iny
    cpy #4
    bne copy_limits

    adw rle_end_addr_even SRC_ADDR
    adw rle_end_addr_odd  SRC_ADDR
    adw SRC_ADDR #4

    mwa rle_end_addr_even rle_end_addr
    mwa DST_ADDR VADDR
upload_screen_data_even:
    jsr rle_decode_256
    bmi odd_pixels

    sta VDATA
    lda VDATA
    jmp upload_screen_data_even

odd_pixels:
    mwa rle_end_addr_odd rle_end_addr
    mwa DST_ADDR VADDR
    lda VDATA
upload_screen_data_odd:
    jsr rle_decode_256
    bmi rle_complete

    sta VDATA
    lda VDATA
    jmp upload_screen_data_odd
rle_complete:
    rts
.endp

.proc rle_decode_256
    lda size_rle_raw
    bne cont_rle_raw
    lda size_rle
    bne cont_rle

nibble_complete:
    cpw SRC_ADDR rle_end_addr
    bne next_rle_block
    ldy #$ff
    rts

next_rle_block:
    ldy #0
    lda (SRC_ADDR), y
    bmi process_as_rle
    sta size_rle_raw
    inw SRC_ADDR
    lda (SRC_ADDR), y
    jmp rle_inc_and_ret

process_as_rle
    and #$7f
    sta size_rle
    inw SRC_ADDR
    lda (SRC_ADDR), y
    sta data_rle
    jmp rle_inc_and_ret

cont_rle_raw:
    dec size_rle_raw
    ldy #0
    lda (SRC_ADDR), y

rle_inc_and_ret:
    inw SRC_ADDR
    ldy #0
    rts

cont_rle:
    dec size_rle
    lda data_rle
    ldy #0
    rts

.endp

size_rle_raw   .byte 0
size_rle       .byte 0
data_rle       .byte 0
rle_end_addr      .word 0
rle_end_addr_even .word 0
rle_end_addr_odd  .word 0

; requires
; SRC_ADDR : compressed image address
; DST_ADDR : vram address

.proc rle_uncompress_16
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
    jsr rle_decode_16
    cmp #$ff
    beq odd_pixels

    sta VDATA
    jmp upload_screen_data_even

odd_pixels:
    mwa rle_end_addr_odd rle_end_addr
    mwa DST_ADDR VADDR
    mwa DST_ADDR VADDR_AUX
upload_screen_data_odd:
    jsr rle_decode_16
    cmp #$ff
    beq rle_complete

    asl
    asl
    asl
    asl
    ora VDATA
    sta VDATA_AUX
    jmp upload_screen_data_odd
rle_complete:
    rts
.endp

.proc rle_decode_16
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

.endp

size_rle_raw   .byte 0
size_rle       .byte 0
data_rle       .byte 0
rle_raw_nibble .byte 0
rle_end_addr      .word 0
rle_end_addr_even .word 0
rle_end_addr_odd  .word 0

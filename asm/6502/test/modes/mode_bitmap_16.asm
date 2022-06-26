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
    beq halt

    asl
    asl
    asl
    asl
    ora VDATA
    sta VDATA_AUX
    jmp upload_screen_data_odd

halt:
    jmp halt

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

size_rle_raw   .byte 0
size_rle       .byte 0
data_rle       .byte 0
rle_raw_nibble .byte 0
rle_end_addr      .word 0
rle_end_addr_even .word 0
rle_end_addr_odd  .word 0


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
   
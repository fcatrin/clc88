
; file_name in SRC_ADDR
; VRAM address in VADDR

.proc load_image
    ; mwa #file_name_image SRC_ADDR
    lda #ST_MODE_READ
    jsr storage_file_open
    cmp #$ff
    jeq failure

    sta file_handle_image
next_block:
    mwa #image_buffer DST_ADDR
    mwa #$100 SIZE
    lda file_handle_image
    jsr storage_file_read_block
    cpx #ST_RET_SUCCESS
    bne close_image_file

    ldx #0
next_pixel:
    lda image_buffer, x
    sta VDATA
    inx
    cpx SIZE
    bne next_pixel
    jmp next_block

close_image_file:
    lda file_handle_image
    jmp storage_file_close
failure:
    rts
.endp

file_handle_image:
    .byte 0

image_buffer:
    .rept 256
    .byte 0
    .endr

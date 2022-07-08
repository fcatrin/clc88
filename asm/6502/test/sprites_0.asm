   icl '../os/include/symbols.asm'
   
   org USERADDR

start
    lda #1
    ldx #OS_SET_VIDEO_MODE
    jsr OS_CALL

    mwa #sprites_palette SRC_ADDR
    jsr gfx_upload_palette_sprites

    mwa sprite_vram_address VADDR
    mwa sprite_patterns_size SIZE
    mwa #sprite_patterns SRC_ADDR
    jsr gfx_upload_data

    ldx #(2*4*2)
    mva #$40 sprite_data,x
    inx
    inx
    mva #$40 sprite_data,x

    mwa sprite_data_size SIZE
    mwa #sprite_data SRC_ADDR
    mwa #$b000 VADDR
    mwa #$b000 VSPRITES
    jsr gfx_upload_data

    lda VSTATUS
    ora #VSTATUS_EN_SPRITES
    sta VSTATUS

    jsr text_test
main_loop:
    ; jmp main_loop
    lda FRAMECOUNT
wait_frame:
    cmp FRAMECOUNT
    beq wait_frame

    ldx #(4*4*2)+2
    inc sprite_data, x
    sne
    inc sprite_data+1, x
    lda sprite_data+1, x
    cmp #2
    sne
    lda #0
    sta sprite_data+1, x

    ; brute force for now
    mwa sprite_data_size SIZE
    mwa #sprite_data SRC_ADDR
    mwa #$b000 VADDR
    jsr gfx_upload_data


    jmp main_loop

    icl '../test/include/text_test.asm'
    icl '../os/graphics.asm'
    icl '../os/ram_vram.asm'
    icl '../os/text.asm'
    icl '../os/libs/stdlib.asm'

    icl 'include/gfx/set_01/palette.asm'
    icl 'include/gfx/set_01/sprites.asm'

    org EXECADDR
    .word start
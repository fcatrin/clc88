
.proc text_test
    mwa #palette_dark SRC_ADDR
    jsr gfx_upload_palette

    ; set default attribute for the whole screen
    lda #$01
    jsr txt_clear_screen

    mwa #test_string SRC_ADDR
    ldy #0
    ldx #0
print:
    lda (SRC_ADDR), y
    beq print_done
    jsr txt_put_char
    iny
    bne print
    inc SRC_ADDR+1
    inx
    cpx #10
    bne print
print_done:
    rts
.endp

palette_dark:
    .word $2104
    .word $9C0A
    .word $BC0E
    .word $43B5

test_string:
    .byte 'This is Compy CLC-88 testing VRAM port access and attributes! '
    .byte $F0, $02
    .byte 'Now in color'
    .byte $F0, $01
    .byte ', then '
    .byte $F0, $03
    .byte 'another color '
    .byte $F0, $01
    .byte 'and back to normal... '
    .byte 'This is Compy CLC-88 testing VRAM port access and attributes! '
    .byte $F0, $02
    .byte 'Now in color'
    .byte $F0, $01
    .byte ', then '
    .byte $F0, $03
    .byte 'another color '
    .byte $F0, $01
    .byte 'and back to normal. Font by Ascrnet.', 0

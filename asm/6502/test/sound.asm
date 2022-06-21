    icl '../os/include/symbols.asm'

    org USERADDR

    lda #0
    ldx #OS_SET_VIDEO_MODE
    jsr OS_CALL

    lda #255
    sta POKEY0_AUDF1

    lda #$CF
    sta POKEY0_AUDC1

halt:
    jmp halt

    icl '../os/libs/stdlib.asm'

    org EXECADDR
    .word USERADDR
   icl '../../os/include/symbols.asm'
   
   org USERADDR

start
    lda #2
    ldx #OS_SET_VIDEO_MODE
    jsr OS_CALL

    jsr text_test
halt:
    jmp halt

    icl '../../test/include/text_test.asm'
    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/text.asm'
    icl '../../os/libs/stdlib.asm'

    org EXECADDR
    .word start
   icl '../../os/include/symbols.asm'

BORDER_COLOR = $0000
DLIST_ADDR = $0200

COLOR_SKY = $3947
COLOR_GROUND = $B5B3

pixels_width = 960
pitch        = pixels_width / 4
top_lines    = 100
image_0_height = 147
bottom_lines = 20

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

    jsr set_scanline_interrupt

    mwa #palette SRC_ADDR
    jsr gfx_upload_palette

    ; patch sky color
    mva #5 VPAL_INDEX
    mva #<COLOR_SKY VPAL_VALUE
    mva #>COLOR_SKY VPAL_VALUE

    ; read image from storage
    mwa #VRAM_SCREEN_DATA_ADDR SRC_ADDR
    adw SRC_ADDR #pitch*0
    mwa SRC_ADDR VADDR
    mwa #file_name_image_0 SRC_ADDR
    jsr load_image

    mwa #VRAM_SCREEN_DATA_ADDR SRC_ADDR
    adw SRC_ADDR #pitch*120
    mwa SRC_ADDR VADDR
    mwa #file_name_image_1 SRC_ADDR
    jsr load_image


main_loop:
    ; jmp main_loop
    lda FRAMECOUNT
wait_frame:
    cmp FRAMECOUNT
    beq wait_frame

    and #1
    beq no_scroll_0

    inc dl_scroll_fine_x
    lda dl_scroll_fine_x
    cmp #8
    bne no_scroll_0
    mva #0 dl_scroll_fine_x
    inc dl_scroll_left
    lda dl_scroll_left
    cmp dl_scroll_width
    bne no_scroll_0
    mva #0 dl_scroll_left

no_scroll_0:
    inc dl_scroll_fine_x_1
    lda dl_scroll_fine_x_1
    cmp #8
    bne no_scroll_1
    mva #0 dl_scroll_fine_x_1
    inc dl_scroll_left_1
    lda dl_scroll_left_1
    cmp dl_scroll_width_1
    bne no_scroll_1
    mva #0 dl_scroll_left_1

no_scroll_1:
    mwa #(DLIST_ADDR+3) VADDR
    mva dl_scroll_left VDATA
    lda VDATA
    mva dl_scroll_fine_x VDATA

    mwa #(DLIST_ADDR+8) VADDR
    mva dl_scroll_left_1 VDATA
    lda VDATA
    mva dl_scroll_fine_x_1 VDATA
    jmp main_loop

.proc set_scanline_interrupt
    mwa #dli    HBLANK_VECTOR_USER
    mwa #vblank VBLANK_VECTOR_USER

    lda #21*8
    sta VLINEINT

    lda VSTATUS
    ora #VSTATUS_EN_INTS
    sta VSTATUS
    rts
.endp

.proc dli
    pha
    ; mwa #COLOR_GROUND VBORDER
    pla
    rts
.endp

.proc vblank
    pha
    ; mwa #COLOR_SKY VBORDER
    pla
    rts
.endp


display_list:
    .word $2478
    .word VRAM_SCREEN_DATA_ADDR
dl_scroll_width  .byte 120
dl_scroll_height .byte 30
dl_scroll_left   .byte 0
dl_scroll_top    .byte 0
dl_scroll_fine_x .byte 0
dl_scroll_fine_y .byte 0
    .word $2478
    .word (VRAM_SCREEN_DATA_ADDR + pitch*120)
dl_scroll_width_1  .byte 120
dl_scroll_height_1 .byte 30
dl_scroll_left_1   .byte 0
dl_scroll_top_1    .byte 0
dl_scroll_fine_x_1 .byte 0
dl_scroll_fine_y_1 .byte 0
    .word $0f00

display_list_size:
    .byte * - display_list + 1

file_name_image_0:
    .byte 'mountains.bin', 0
file_name_image_1:
    .byte 'ground.bin', 0

    icl 'palette.asm'
    icl 'utils.asm'

    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/storage.asm'
    icl '../../os/libs/stdlib.asm'

    org EXECADDR
    .word start
   
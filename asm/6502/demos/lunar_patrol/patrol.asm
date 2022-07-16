   icl '../../os/include/symbols.asm'

BORDER_COLOR = $0000
DLIST_ADDR = $0200

SKY_COLOR = $3947

pixels_width = 360
pitch        = pixels_width / 2
top_lines    = 100
image_height = 120
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

    ; read palette from storage
    mwa #file_name_palette SRC_ADDR
    lda #ST_MODE_READ
    jsr storage_file_open
    cmp #$ff
    jeq main_loop

    sta file_handle_palette
    mwa #palette DST_ADDR
    mwa #$200 SIZE
    lda file_handle_palette
    jsr storage_file_read_block

    lda file_handle_palette
    jsr storage_file_close

    mwa #palette SRC_ADDR
    jsr gfx_upload_palette

    ; patch sky color
    mva #5 VPAL_INDEX
    mva #<SKY_COLOR VPAL_VALUE
    mva #>SKY_COLOR VPAL_VALUE
    mwa #SKY_COLOR VBORDER

    ; read image from storage
    mwa #VRAM_SCREEN_DATA_ADDR VADDR

    mwa #file_name_image SRC_ADDR
    lda #ST_MODE_READ
    jsr storage_file_open
    cmp #$ff
    jeq main_loop

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
    jsr storage_file_close

main_loop:
    ; jmp main_loop
    lda FRAMECOUNT
wait_frame:
    cmp FRAMECOUNT
    beq wait_frame
    inc dl_scroll_fine_x
    lda dl_scroll_fine_x
    cmp #8
    bne push_scroll
    mva #0 dl_scroll_fine_x
    inc dl_scroll_left
    lda dl_scroll_left
    cmp dl_scroll_width
    bne push_scroll
    mva #0 dl_scroll_left

push_scroll:
    mwa #(DLIST_ADDR+3) VADDR
    mva dl_scroll_left VDATA
    lda VDATA
    mva dl_scroll_fine_x VDATA
    jmp main_loop


display_list:
    .word $24F0
    .word VRAM_SCREEN_DATA_ADDR
dl_scroll_width  .byte 120
dl_scroll_height .byte 30
dl_scroll_left   .byte 0
dl_scroll_top    .byte 0
dl_scroll_fine_x .byte 0
dl_scroll_fine_y .byte 0
    .word $0f00

display_list_size:
    .byte * - display_list + 1

file_name_image:
    .byte 'mountains.bin', 0
file_name_palette:
    .byte 'palette.bin', 0
file_handle_image:
    .byte 0
file_handle_palette:
    .byte 0

image_buffer:
    .rept 256
    .byte 0
    .endr

palette:
    .rept 512
    .byte 0
    .endr


    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/storage.asm'
    icl '../../os/libs/stdlib.asm'

    org EXECADDR
    .word start
   
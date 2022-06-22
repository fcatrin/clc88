    icl '../../os/include/symbols.asm'
	
CHARSET_EDIT = $4000	

CHARPIX_POS_X = 3
CHARPIX_POS_Y = 3

TEXTAREA_POS_X = 2
TEXTAREA_POS_Y = 13

CHARSET_POS_X = 4
CHARSET_POS_Y = 22

BORDER_COLOR = $2167

    org USERADDR

    mwa #BORDER_COLOR VBORDER

    mwa #palette_dark SRC_ADDR
    jsr gfx_upload_palette

    lda #$01
    sta ATTRIB_DEFAULT
    ldx #OS_SET_VIDEO_MODE
    jsr OS_CALL

    jsr set_scanline_interrupt

    ; charsets are aligned to pages of $400 bytes
    ; charset register holds the page number
    ;
    ; Example:
    ; charset at byte address $0000 => page 0
    ; charset at byte address $0400 => page 1
    ;
    ; Chroni uses word adresses
    ; charset at word address $0000 => page 0
    ; charset at word address $0200 => page 1
    ;
    ; The following code find the next available page after VRAM_FREE using word addresses
    ; src_addr = (vram_free + $01ff) % $0200
    ; page = (src_addr & $fe00) >> 9

    mwa VRAM_FREE SRC_ADDR
    adw SRC_ADDR #$1FF ; align to word $200,  src_addr = (vram_free + $1ff) % $200
    mva #0 SRC_ADDR
    lda SRC_ADDR+1
    and #$FE
    sta SRC_ADDR+1
    mwa SRC_ADDR charset_edit_start

    lsr
    sta charset_edit_start_page

    ; copy original font from $0000 to the new address
    mwa #$0000 VADDR
    mwa charset_edit_start VADDR_AUX
    ldx #4
    ldy #0
copy_page
    lda VDATA
    sta VDATA_AUX
    iny
    bne copy_page
    dex
    bne copy_page

    jsr prepare_editor_charset
    jsr draw_char_editor_borders
    jsr display_charset

    jsr draw_char_editor

    jsr charpix_char_update

main_loop 

    jsr keyb_read
    cmp last_key
    beq no_key_pressed
    sta last_key

    jsr editor_on_key

no_key_pressed:
    jmp main_loop

.proc display_charset
    ldx #CHARSET_POS_X
    ldy #CHARSET_POS_Y
    jsr screen_position
    mwa VADDRB SRC_ADDR

    ldx #0
next_row
    ldy #0
next_char
    txa
    sta VDATA
    inx
    iny
    cpy #32
    bne next_char
    adw SRC_ADDR SCREEN_PITCH
    mwa SRC_ADDR VADDRB
    cpx #$80
    bne next_row
    rts
.endp

.proc prepare_editor_charset
    ; redefine chars from 1-5
    mwa #4 VADDR
    ldx #0
copy:
    lda block_chars, x
    sta VDATA
    inx
    cpx #(5*8)
    bne copy
    rts
.endp

.proc draw_char_editor_borders
    ldx #2
    ldy #2
    jsr screen_position
    mwa VADDRB DST_ADDR

    mva #1 VDATA ; top left corner

    ldy #8
    lda #2
border_top:
    sta VDATA
    dey
    bne border_top

    ldx #8
border_left:
    adw DST_ADDR SCREEN_PITCH
    mwa DST_ADDR VADDRB
    mva #3 VDATA
    dex
    bne border_left
    rts
.endp

.proc get_char_addr
    mwa #0 SRC_ADDR ; SRC_ADDR = charset_char_index * 8 + charset_edit_start
    lda charset_char_index
    asl
    rol SRC_ADDR+1
    asl
    rol SRC_ADDR+1
    sta SRC_ADDR

    adw SRC_ADDR charset_edit_start
    rts
.endp

.proc draw_char_editor
    jsr get_char_addr
    mwa SRC_ADDR VADDR_AUX

    ldx #CHARPIX_POS_X
    ldy #CHARPIX_POS_Y
    jsr screen_position
    mwa VADDRB DST_ADDR

    mva #0 charset_index

    ldy #0
next_row
    lda VDATA_AUX
    ldy #0
next_bit
    asl
    sta R0
    lda #4
    scc
    lda #5
    sta VDATA
    lda R0
    iny
    cpy #8
    bne next_bit
    adw DST_ADDR SCREEN_PITCH
    mwa DST_ADDR VADDRB
    inc charset_index
    lda charset_index
    cmp #8
    bne next_row
    rts

charset_index .byte 0
.endp

.proc editor_on_key
    lda last_key
    cmp #19
    beq set_edit_mode_0
    cmp #20
    beq set_edit_mode_1
    cmp #21
    beq set_edit_mode_2
    lda edit_mode
    jeq charpix_on_key
    cmp #1
    jeq textarea_on_key
    cmp #2
    jeq charset_on_key
    rts

set_edit_mode_0:
    mva #0 edit_mode
    rts
set_edit_mode_1:
    mva #1 edit_mode
    rts
set_edit_mode_2:
    mva #2 edit_mode
    rts

.endp

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
    lda #$66
    sta WSYNC
    sta VBORDER
    mva charset_edit_start_page VCHARSET
    pla
    rts
.endp

.proc vblank
    pha
    lda #0
    sta VBORDER
    mva #0 VCHARSET
    pla
    rts
.endp   

charset_edit_start .word 0
charset_edit_start_page .byte 0

charset_char_index .byte 0

last_key .byte 0

edit_mode .byte ; 0 = char, 1 = text, 2 = charset

block_chars:
    .byte 0, 0, 0, 0, 0, 0, 0, 1
    .byte 0, 0, 0, 0, 0, 0, 0, 255
    .byte 1, 1, 1, 1, 1, 1, 1, 1
    .byte 1, 1, 1, 1, 1, 1, 1, 255
    .byte 255, 255, 255, 255, 255, 255, 255 ,255

palette_dark:
    .word $2104
    .word $9C0A
    .word $BC0E
    .word $43B5

    icl 'charpix_nav.asm'
    icl 'charset_nav.asm'
    icl 'textarea_nav.asm'
    icl '../../os/libs/stdlib.asm'
    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'

    org EXECADDR
    .word USERADDR
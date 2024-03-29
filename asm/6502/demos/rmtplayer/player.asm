	icl '../../os/include/symbols.asm'

;
; MUSIC init & play
; example by Raster/C.P.U., 2003-2004
;
	icl "rmtplayr.asm"			;include RMT player routine

MODUL	equ $4000				;address of RMT module
VLINE	equ 16					;screen line for synchronization

	org BOOTADDR

start

    sei
    mwa #timer_irq IRQ_VECTOR
    cli

    mva #$12 ATTRIB_DEFAULT

    lda #1
    ldx #OS_SET_VIDEO_MODE
    jsr OS_CALL

    mwa #font SRC_ADDR
    mwa #0 VADDR
    jsr gfx_upload_font

    mwa #custom_palette SRC_ADDR
    ldx #OS_SET_VIDEO_PALETTE
    jsr OS_CALL

    jsr display_credits

    ; paint Song Info area
    mva #0  screen_margin_left
    mva #40 screen_margin_right
    mva #25 screen_margin_top
    mva #30 screen_margin_bottom

    lda #$34
    jsr screen_fill_attrib

    ; paint Credits Info area
    mva #25 screen_margin_left
    mva #40 screen_margin_right
    mva #0  screen_margin_top
    mva #25 screen_margin_bottom

    lda #$56
    jsr screen_fill_attrib

    jsr list_files
    jsr display_files

    jsr update_selected_line
   
loop
    lda is_playing
    beq skip_player

acpapx1	lda #$ff				;parameter overwrite (sync line counter value)
    sta SYS_TIMER_VL
acpapx2	lda #$ff				;parameter overwrite (sync line counter spacing)
    sta SYS_TIMER_VH
    sta SYS_TIMER_WR_EN
    sta SYS_TIMER_EN
    lda timer_flag
waipap
    cmp timer_flag
    beq waipap

    ; lda #8
    ; sta VBORDER
    jsr RASTERMUSICTRACKER+3	;1 play

    ; lda #0
    ; sta VBORDER

skip_player:   
    jsr process_keyboard

    jmp loop

stop_player:
    jmp RASTERMUSICTRACKER+9

tabpp  dta 156,78,52,39			;line counter spacing table for instrument speed from 1 to 4

.proc start_song
    jsr stop_player

    jsr clear_song_info
    ldx #12
    ldy #26
    mwa #label_loading SRC_ADDR
    jsr screen_print_at

    clc
    lda selected_line
    adc files_offset
    tax
    jsr file_name_get

    jsr load_song

    ; print song name at position 1, 22 with margins (1, 20) - (39, 22)

    jsr clear_song_info

    ldx #1
    ldy #26
    mwa #label_song SRC_ADDR
    jsr screen_print_at

    ldx #7
    ldy #26
    mwa song_text SRC_ADDR
    jsr screen_print_at


    ldx #<MODUL             ;low byte of RMT module to X reg
    ldy #>MODUL             ;hi byte of RMT module to Y reg
    lda #0                  ;starting song line 0-255 to A reg
    jsr RASTERMUSICTRACKER     ;Init
;Init returns instrument speed (1..4 => from 1/screen to 4/screen)
    sec
    sbc #1
    asl
    tay
    lda timer_speed_table, y
    sta acpapx1+1
    iny
    lda timer_speed_table, y
    sta acpapx2+1

; Display MONO / STEREO label
    mwa #label_mono SRC_ADDR
    lda v_tracks
    cmp #4
    seq
    mwa #label_stereo SRC_ADDR

    ldx #1
    ldy #28
    jsr screen_position
    jsr screen_print

setup_stereo_pokey:   
    lda v_tracks
    cmp #4
    beq set_pokey_mono
    lda #$55
    sta POKEY0_PANCTL
    lda #$AA
    sta POKEY1_PANCTL
    jmp set_pokey_done
set_pokey_mono:   
    lda #$FF
    sta POKEY0_PANCTL
    lda #$00
    sta POKEY1_PANCTL
set_pokey_done:
    lda #1
    sta is_playing
    rts
.endp

.proc clear_song_info
    lda #1
    sta screen_margin_left
    lda #39
    sta screen_margin_right

    lda #25
    sta screen_margin_top
    lda #29
    sta screen_margin_bottom

    jmp screen_clear
.endp

.proc process_keyboard
    jsr keyb_read
    cmp last_key
    beq process_end
    sta last_key

    cmp #16
    jeq key_up
    cmp #17
    jeq key_down
    cmp #46
    jeq key_enter
process_end:   
    rts
   
key_up:
    lda selected_line
    cmp #0
    bne line_up

    lda files_offset
    beq process_end

    jsr files_scroll_down
    dec files_offset

    ldx #1
    ldy #1
    jsr screen_position

    ldx files_offset
    jmp files_print_one

line_up   
    dec selected_line
    jmp update_selected_line

key_down:
    clc
    lda selected_line
    adc files_offset
    adc #1
    cmp files_read
    beq process_end

    lda selected_line
    cmp #22
    bne line_down

    jsr files_scroll_up
    inc files_offset

    ldx #1
    ldy #23
    jsr screen_position

    clc
    lda files_offset
    adc selected_line
    tax
    jsr files_print_one
    jmp update_selected_line

line_down   
    inc selected_line
    jmp update_selected_line

key_enter:
    clc
    lda files_offset
    adc selected_line
    tax
    lda DIR_ENTRIES_TYPES,x
    cmp #ST_TYPE_FILE
    jeq start_song

    txa
    pha
    lda #0
    sta files_offset
    sta selected_line
    jsr update_selected_line
    jsr files_display_clear

    pla
    tax
    jsr files_change_folder
    jsr list_files

    jmp display_files

last_key .byte 0
.endp

.proc display_credits
next_info_string   
    lda info_string_ndx
    asl
    tax
    mwa player_info_strings,x SRC_ADDR
    lda SRC_ADDR
    ora SRC_ADDR+1
    sne
    rts

    ldx info_string_ndx
    lda player_info_pos_y, x
    tay
    lda player_info_pos_x, x
    tax
    jsr screen_print_at

    inc info_string_ndx
    jmp next_info_string
info_string_ndx .byte 0
.endp

.proc update_selected_line
    lda selected_line
    jmp display_file_row
.endp   

timer_irq:
   pha
   lda SYS_TIMER_IRQ ; // just read the value on the debugger
   mva #1 SYS_TIMER_ACK
   inc timer_flag
not_yet
   pla
   rti

timer_flag .byte 0

timer_speed_table:
    .word 20000
    .word 10000
    .word 6666
    .word 5000

files_offset  .byte 0
selected_line .byte 0


song_text:
   .word 0

is_playing:   .byte 0
label_song:   .by 'SONG: ', 0
label_stereo: .by 'TYPE: STEREO', 0
label_mono:   .by 'TYPE: MONO  ', 0

label_loading .by 'Loading song...', 0

player_info_0 .by 'RMT player by', 0
player_info_1 .by 'Radek Sterba', 0
player_info_2 .by 'Raster/C.P.U.', 0
player_info_3 .by 'CLC88 port by', 0
player_info_4 .by 'Franco Catrin', 0

player_info_strings .word  player_info_0, player_info_1, player_info_2, player_info_3, player_info_4, 0
player_info_pos_x .byte 26, 26, 26, 26, 26
player_info_pos_y .byte 8, 9, 10, 12, 13

custom_palette
    .word $0000 ; border default
    .word $2AAE ; file list background
    .word $CE59 ; file list text
    .word $1189 ; song info background
    .word $ffff ; song info text
    .word $0107 ; credits background
    .word $EDE6 ; credits text
    .word $FE25 ; highlight text
    .word $640D ; player bars

    icl 'files.asm'
    icl 'loader.asm'
    icl '../../os/libs/stdlib.asm'
    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'

font:
    ins '../../../../res/fonts/charset_tims.bin'

    org EXECADDR
    .word start

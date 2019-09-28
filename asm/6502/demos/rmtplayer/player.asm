	icl '../../os/symbols.asm'

;
; MUSIC init & play
; example by Raster/C.P.U., 2003-2004
;
	icl "rmtplayr.asm"			;include RMT player routine

MODUL	equ $4000				;address of RMT module
VLINE	equ 16					;screen line for synchronization

	org BOOTADDR

start

   lda #0
   sta ROS7
   lda #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
	
	jsr display_credits
	
	; paint Song Info area
	mva #0  screen_margin_left
	mva #40 screen_margin_right
	mva #19 screen_margin_top
	mva #24 screen_margin_bottom
	
	lda #$52
	jsr screen_fill_attrib

   mva #25  screen_margin_left
   mva #40 screen_margin_right
   mva #0 screen_margin_top
   mva #19 screen_margin_bottom
   
   lda #$1A
   jsr screen_fill_attrib
	
   jsr list_files
   lda #0
   jsr display_files

   jsr update_selected_file
   
loop
   lda is_playing
   beq skip_player

acpapx1	lda #$ff				;parameter overwrite (sync line counter value)
	clc
acpapx2	adc #$ff				;parameter overwrite (sync line counter spacing)
	cmp #156
	bcc lop4
	sbc #156
lop4
	sta acpapx1+1
waipap
	cmp VCOUNT					;vertical line counter synchro
	bne waipap

   lda #10
   sta VCOLOR0
	jsr RASTERMUSICTRACKER+3	;1 play

   lda #0
   sta VCOLOR0

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
   ldy #21
   mwa #label_loading SRC_ADDR
   jsr screen_print_at 
   
   ldx selected_file
   jsr file_name_get

   jsr load_song
   
   ; print song name at position 1, 22 with margins (1, 20) - (39, 22)
   
   jsr clear_song_info
   
   ldx #1
   ldy #20
   mwa #label_song SRC_ADDR
   jsr screen_print_at
   
   ldx #7
   ldy #20
   mwa song_text SRC_ADDR
   jsr screen_print_at
   
   
   ldx #<MODUL             ;low byte of RMT module to X reg
   ldy #>MODUL             ;hi byte of RMT module to Y reg
   lda #0                  ;starting song line 0-255 to A reg
   jsr RASTERMUSICTRACKER     ;Init
;Init returns instrument speed (1..4 => from 1/screen to 4/screen)
   tay
   lda tabpp-1,y
   sta acpapx2+1           ;sync counter spacing
   lda #16+0
   sta acpapx1+1           ;sync counter init

; Display MONO / STEREO label
   mwa #label_mono SRC_ADDR
   lda v_tracks
   cmp #4
   seq
   mwa #label_stereo SRC_ADDR
   
   ldx #1
   ldy #22
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

   lda #20
   sta screen_margin_top
   lda #24
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
   lda selected_file
   cmp #0
   beq process_end
   dec selected_file
   jmp update_selected_file
   
key_down:
   ldx selected_file
   inx
   cpx files_read
   beq process_end
   inc selected_file
   jmp update_selected_file
   
key_enter:
   jmp start_song
   
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

.proc update_selected_file
   lda selected_file
   jmp display_file_row
.endp   

selected_file: .byte 0

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
player_info_pos_y .byte 6, 7, 8, 10, 11
   
   icl 'files.asm'
   icl 'loader.asm'
   icl '../../os/stdlib.asm'

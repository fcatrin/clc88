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
	
	mva #0  screen_margin_left
	mva #40 screen_margin_right
	mva #19 screen_margin_top
	mva #24 screen_margin_bottom
	
	lda #$52
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
   
   ldx selected_file
   jsr file_name_get

   jsr load_song
   
   ; print song name at position 2, 22 with margins (2, 20) - (38, 22)
   
   lda #2
   sta screen_margin_left
   lda #38
   sta screen_margin_right

   lda #20
   sta screen_margin_top
   lda #22
   sta screen_margin_bottom
   
   jsr screen_clear
   
   ldx #2
   ldy #20
   mwa #song_label SRC_ADDR
   jsr screen_print_at
   
   ldx #8
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
   mwa #mono_label SRC_ADDR
   lda v_tracks
   cmp #4
   seq
   mwa #stereo_label SRC_ADDR
   
   ldx #2
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

.proc update_selected_file
   lda selected_file
   jmp display_file_row
.endp   

selected_file: .byte 0

song_text:
   .word 0
   
is_playing:   .byte 0
song_label:   .by 'SONG: ', 0
stereo_label: .by 'TYPE: STEREO', 0
mono_label:   .by 'TYPE: MONO  ', 0
   
   icl 'files.asm'
   icl 'loader.asm'
   icl '../../os/stdlib.asm'

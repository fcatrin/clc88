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
	
	mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   
   jsr load_song
   mwa song_text SRC_ADDR
   ldy #0
next_song_char:   
   lda (SRC_ADDR), y
   sta (RAM_TO_VRAM), y
   beq song_text_done
   iny
   bne next_song_char
   
song_text_done:

;
	ldx #<MODUL					;low byte of RMT module to X reg
	ldy #>MODUL					;hi byte of RMT module to Y reg
	lda #0						;starting song line 0-255 to A reg
	jsr RASTERMUSICTRACKER		;Init
;Init returns instrument speed (1..4 => from 1/screen to 4/screen)
	tay
	lda tabpp-1,y
	sta acpapx2+1				;sync counter spacing
	lda #16+0
	sta acpapx1+1				;sync counter init

   lda v_tracks
   pha
   ora #'0'
   ldy #0
   sta (RAM_TO_VRAM), y
   pla
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

loop
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
;
   lda #10
   sta VCOLOR0
	jsr RASTERMUSICTRACKER+3	;1 play

   lda #0
   sta VCOLOR0
;
	jmp loop					;no => loop
;
stopmusic
;
	jsr RASTERMUSICTRACKER+9	;all sounds off
halt:
   jmp halt
;
;
tabpp  dta 156,78,52,39			;line counter spacing table for instrument speed from 1 to 4
;
;

.proc load_song
   mwa #test_path SRC_ADDR
   lda #ST_MODE_READ
   ldx #OS_FILE_OPEN
   jsr OS_CALL
   sta file_handle
   cmp #$FF
   bne read_xex_header
   lda #$4F ; bright border on error
   sta VCOLOR0
halt: jmp halt

read_xex_header:
   jsr read_byte           ; read start address skipping $FFFF values
   bne eof
   sta xex_start
   jsr read_byte
   bne eof
   sta xex_start+1
   and xex_start
   cmp #$FF
   beq read_xex_header
   
   jsr read_byte
   bne eof
   sta xex_end
   jsr read_byte
   bne eof
   sta xex_end+1
   
   mwa xex_start song_text
   mwa xex_start DST_ADDR
   
   ; use slow "carretero" method

read_next_byte
   jsr read_byte
   bne eof
   ldy #0
   sta (DST_ADDR), y
   cpw DST_ADDR xex_end
   beq read_xex_header
   inw DST_ADDR
   jmp read_next_byte
   
eof:
   lda file_handle
   ldx #OS_FILE_CLOSE
   jsr OS_CALL 
   
.endp

.proc read_byte
   ldx #OS_FILE_READ_BYTE
   lda file_handle
   jsr OS_CALL
   rts
.endp

.proc build_path
   ldx #0
copy_dirname:   
   lda dirname, x
   beq add_filename
   sta path,x
   inx
   bne copy_dirname
   
add_filename:   
   lda #'/'
   sta path,x
   inx
   
   txa
   clc
   adc #<path
   sta DST_ADDR
   lda #>path
   adc #0
   sta DST_ADDR+1
   
   ldx #0
copy_filename:
   lda filename,x
   sta path,x
   beq copy_done
   inx
   cpx #128
   bne copy_filename
copy_done:
   rts
.endp

file_handle:
   .byte 0
xex_start:
   .word 0
xex_end:
   .word 0
song_text:
   .word 0
   
dirname:
   .rept 256
   .byte 0
   .endr
filename:
   .rept 128
   .byte 0
   .endr
path:
   .rept 128+256
   .byte 0
   .endr
   
test_path:
   .byte '/home/fcatrin/git/clc88/asm/6502/demos/rmt/songs/commando.rmt', 0
   
   icl '../../os/stdlib.asm'

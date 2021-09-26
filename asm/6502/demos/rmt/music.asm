	icl '../../os/symbols.asm'

;
; MUSIC init & play
; example by Raster/C.P.U., 2003-2004
;
;
	icl "rmtplayr.asm"			;include RMT player routine
;
;
	opt h-						;RMT module is standard Atari binary file already
	ins "songs/acidjazzed_evening.rmt"				;include music RMT module
	opt h+
;
;
MODUL	equ $4000				;address of RMT module
; VCOUNT	equ $d40b				;vertical screen lines counter address
KEY		equ $2fc				;keypressed code
VLINE	equ 16					;screen line for synchronization
;

	org BOOTADDR
	jmp start

	org $3c00

start

   lda #1
   sta ROS7
   lda #1
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
	
	mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
	
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

;
	lda #255
	sta KEY						;no key pressed
;
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
   sta VBORDER
	jsr RASTERMUSICTRACKER+3	;1 play

   lda #0
   sta VBORDER
;
	lda KEY						;keyboard
	cmp #28						;ESCape key?
	bne loop					;no => loop
;
stopmusic
	lda #255
	sta KEY						;no key pressed
;
	jsr RASTERMUSICTRACKER+9	;all sounds off
;
	jmp (10)					;DOSVEC => exit to DOS
;
tabpp  dta 156,78,52,39			;line counter spacing table for instrument speed from 1 to 4
;
;
	run start					;run addr

   icl '../../os/stdlib.asm'
;
;that's all... ;-)
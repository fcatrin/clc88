   org $f000
   
   
COLS = 80
ROWS = 30

THIS_SCREEN_SIZE = COLS*ROWS

FONT_ROM_ADDR = $e000
BORDER_COLOR = $2167
DLIST_ADDR = $0200

text_location = $0400
attr_location = text_location + THIS_SCREEN_SIZE/2 
   
test_results  = $200
test_buffer_z = $20
test_buffer   = $300
   
demo:   
   lda #$aa // start testing basic functionality
   ldx #$bb // if this fails, it can be spotted easily
   ldy #$cc // in signal tap
   sta test_buffer_z
   stx test_buffer_z + 1
   sty test_buffer_z + 2
   ldx #0
copy_first_block:        // if this fails, testing will throw worng results
   lda test_buffer_z,x
   sta test_results, x
   inx
   cpx #3
   bne copy_first_block
   
   // start testing address modes st abs, ld abs,x, ld abs, y, ld z,y, ld z,y
   lda test_results
   sta test_results + 3
   ldx #1
   lda test_results,x
   sta test_results + 4
   ldy #2
   lda test_results,y
   sta test_results + 5
   ldx #1
   ldy test_results,x
   sty test_results + 6
   ldy #2
   ldx test_results,y
   stx test_results + 7
   
   ldy #2
   lda test_buffer_z,y
   sta test_results + 8
   ldx test_buffer_z,y
   stx test_results + 9

   ldx #1
   lda test_buffer_z,x
   sta test_results + 10
   ldy test_buffer_z,x
   sty test_results + 11
   
   // test st abs,x st abs, y, st z,x, st z,y
   lda #$55
   ldx #2
   sta test_buffer, x
   lda test_buffer, x
   sta test_results + 12
   
   lda #$66
   ldy #3
   sta test_buffer, y
   lda test_buffer, y
   sta test_results + 13
   
   // test inx, iny, dex, dey
   ldx #$20
   inx
   stx test_results + 14
   ldy #$30
   iny
   sty test_results + 15
   
   ldx #$40
   dex
   stx test_results + 16

   ldy #$50
   dey
   sty test_results + 17
   
   // test inc z, dec z
   lda #$60
   sta test_buffer_z
   inc test_buffer_z
   lda test_buffer_z
   sta test_results + 18
   
   lda #$70
   sta test_buffer_z
   dec test_buffer_z
   lda test_buffer_z
   sta test_results + 19
   
   // test flag z + branches

   ldx #3
   lda #0
   beq zero_ok
   ldx #4
zero_ok
   stx test_results + 20
   
   ldx #5
   lda #1
   bne nzero_ok
   ldx #6
nzero_ok
   stx test_results + 21
   
   // test branches back (z)
   ldy #$10
   ldx #3
test_back   
   iny
   dex
   bne test_back
   sty test_results + 22
   
   // test flag n
   ldx #$32
   lda #$80
   bmi minus_ok
   ldx #$30
minus_ok
   stx test_results + 23
   ldx #$42
   lda #0
   bpl plus_ok
   ldx #$40
plus_ok   
   stx test_results + 24
   
   // test cmp, cpx, cpy
   lda #$11
   ldx #$52
   cpx #$50
   bne cpxne_ok
   lda #$12
cpxne_ok
   sta test_results + 25
   lda #$13
   cpx #$52
   beq cpxeq_ok   
   lda #$14
cpxeq_ok
   sta test_results + 26   

   lda #$15
   ldy #$62
   cpy #$60
   bne cpyne_ok
   lda #$16
cpyne_ok
   sta test_results + 27
   lda #$17
   cpy #$62
   beq cpyeq_ok   
   lda #$18
cpyeq_ok
   sta test_results + 28   
   
   // display results if we reach this point!
   jsr display_results
   
   ldy #$1b
   lda #$33
   cmp #$44
   bne cmp_ne_ok
   ldy #$1c
cmp_ne_ok 
   sty test_results + 29
   ldy #$1d
   cmp #$33
   beq cmp_eq_ok
   ldy #$1e
cmp_eq_ok
   sty test_results + 30
   
   // test cmp/cpx/cpy with abs an z

   // cmp z
   ldy #$21
   lda #$11
   sta test_buffer_z
   lda #0
   cmp test_buffer_z
   bne cmpz_ne_ok
   ldy #$22
cmpz_ne_ok
   sty test_results + 31
   ldy #$23
   lda #$11
   cmp test_buffer_z
   beq cmpz_eq_ok
   ldy #$24
cmpz_eq_ok      
   sty test_results + 32
   
   // cpx z
   lda #$25
   ldx #$22
   stx test_buffer_z
   ldx #0
   cpx test_buffer_z
   bne cpxz_ne_ok
   lda #$26
cpxz_ne_ok
   sta test_results + 33
   lda #$27
   ldx #$22
   cpx test_buffer_z
   beq cpxz_eq_ok
   lda #$28
cpxz_eq_ok
   sta test_results + 34

   // cpy z
   lda #$35
   ldy #$33
   sty test_buffer_z
   ldy #0
   cpy test_buffer_z
   bne cpyz_ne_ok
   lda #$36
cpyz_ne_ok
   sta test_results + 35
   lda #$37
   ldy #$33
   cpy test_buffer_z
   beq cpyz_eq_ok
   lda #$38
cpyz_eq_ok
   sta test_results + 36

   jsr update_results

   // cmp abs
   ldy #$41
   lda #$aa
   sta test_buffer
   lda #0
   cmp test_buffer
   bne cmpa_ne_ok
   ldy #$42
cmpa_ne_ok
   sty test_results + 37
   ldy #$43
   lda #$aa
   cmp test_buffer
   beq cmpa_eq_ok
   ldy #$44
cmpa_eq_ok      
   sty test_results + 38
   
   // cpx abs
   lda #$45
   ldx #$bb
   stx test_buffer
   ldx #0
   cpx test_buffer
   bne cpxa_ne_ok
   lda #$46
cpxa_ne_ok
   sta test_results + 39
   lda #$47
   ldx #$bb
   cpx test_buffer
   beq cpxa_eq_ok
   lda #$48
cpxa_eq_ok
   sta test_results + 40

   // cpy z
   lda #$55
   ldy #$cc
   sty test_buffer
   ldy #0
   cpy test_buffer
   bne cpya_ne_ok
   lda #$56
cpya_ne_ok
   sta test_results + 41
   lda #$57
   ldy #$cc
   cpy test_buffer
   beq cpya_eq_ok
   lda #$58
cpya_eq_ok
   sta test_results + 42
   
   jsr update_results
   
   
   // test inc/dec with abs, z_x, abs_x

   lda #$92
   sta test_buffer
   inc test_buffer
   lda test_buffer
   sta test_results + 43
   
   lda #$a0
   sta test_buffer
   dec test_buffer
   lda test_buffer
   sta test_results + 44
   
   ldx #2
   lda #$a0
   sta test_buffer_z + 2
   inc test_buffer_z,x
   lda test_buffer_z,x
   sta test_results + 45

   lda #$b0
   sta test_buffer_z + 2
   dec test_buffer_z,x
   lda test_buffer_z,x
   sta test_results + 46

   lda #$b0
   sta test_buffer + 2
   inc test_buffer,x
   lda test_buffer,x
   sta test_results + 47

   lda #$c0
   sta test_buffer + 2
   dec test_buffer,x
   lda test_buffer,x
   sta test_results + 48
   
   jsr update_results
   
   // test lda z_x, abs_x, abs_y, ind_x, ind_y
   ldx #$23
   stx test_buffer_z + 2 ; z_x
   inx
   stx test_buffer + 2   ; abs_x
   inx
   stx test_buffer + 3   ; abs_y
   
   ldx #2
   lda test_buffer_z,x  
   sta test_results + 49
   lda test_buffer,x
   sta test_results + 50
   ldy #3
   lda test_buffer,y
   sta test_results + 51
   
   ldx #$33
   stx test_buffer+4
   mwa #test_buffer+1 $a2
   ldy #3
   lda ($a2), y           ; ind_y
   sta test_results + 52
   
   ldx #$44
   stx test_buffer+1
   ldx #2
   lda ($a0, x)
   sta test_results + 53  ; ind_x
   
   jsr update_results
   
   // test ldx z, z_y, abs, abs_y

   lda #$55
   sta test_buffer_z
   lda #$56
   sta test_buffer_z + 3
   lda #$57
   sta test_buffer
   lda #$58
   sta test_buffer + 3
   ldy #3
   ldx test_buffer_z
   stx test_results + 54
   ldx test_buffer_z, y
   stx test_results + 55
   ldx test_buffer
   stx test_results + 56
   ldx test_buffer,y
   stx test_results + 57

   // test ldy z, z_x, abs, abs_x

   lda #$65
   sta test_buffer_z
   lda #$66
   sta test_buffer_z + 4
   lda #$67
   sta test_buffer
   lda #$68
   sta test_buffer + 4
   ldx #4
   ldy test_buffer_z
   sty test_results + 58
   ldy test_buffer_z, x
   sty test_results + 59
   ldy test_buffer
   sty test_results + 60
   ldy test_buffer,x
   sty test_results + 61

   jsr update_results
   
   // now test everything else, sorted by instruction

   // test adc, all addressing modes
   // start with IMM mode, with and without carry
   clc
   lda #2
   adc #9                ; adc imm, c = 0
   sta test_results + 62 
   
   sec
   adc #$10              ; adc imm + c
   sta test_results + 63
   
   ldx #$22
   stx test_buffer_z
   lda #$11
   clc
   adc test_buffer_z     ; adc z
   sta test_results + 64
   
   ldx #$44
   stx test_buffer
   lda #$55
   clc
   adc test_buffer       ; adc abs
   sta test_results + 65
   
   ldx #$22
   stx test_buffer_z + 2
   inx
   stx test_buffer + 2
   inx
   stx test_buffer + 3
   lda #$10
   ldx #2
   ldy #3
   clc
   adc test_buffer_z, x   ; adc z_x
   sta test_results + 66
   clc
   adc test_buffer, x     ; adc abs_x
   sta test_results + 67
   clc
   adc test_buffer, y     ; adc abs_y
   sta test_results + 68
   
   mwa #test_buffer $a2
   ldx #$27
   stx test_buffer + 3
   ldx #$92
   stx test_buffer

   ldy #3
   lda #$42
   clc
   adc ($a2), y           ; adc ind_y
   sta test_results + 69  ; $27+$42
   
   ldx #2
   lda #$22
   clc
   adc ($a0, x)           ; adc ind_x
   sta test_results + 70  ; $22+$92
   
   
   jsr update_results
   
   // test and (imm, abs only)

   lda #$AA
   and #$f2
   sta test_results + 71
   
   lda #$55
   sta test_buffer
   lda #$1E
   and test_buffer
   sta test_results + 72
   
   lda #$55
   sec
   asl
   sta test_results + 73
   clc
   asl
   sta test_results + 74
   adc #1
   sta test_results + 75

   jsr update_results
   
   lda #1
   clc
   bcc carry_clear
   lda #2
carry_clear
   sta test_results + 76
   lda #3
   sec
   bcs carry_set
   lda #4
carry_set
   sta test_results + 77   
   
   ldx #$41
   ldy #$42
   stx test_results + 78
   lda #$aa
   sta test_buffer_z
   lda #3
   bit test_buffer_z
   bmi bit_minus_ok
   sty test_results + 78
bit_minus_ok
   ldx #$43
   ldy #$44
   stx test_results + 79
   lda #$2a
   sta test_buffer_z
   lda #3
   bit test_buffer_z
   bpl bit_plus_ok
   sty test_results + 79
bit_plus_ok   
   ldx #$45
   ldy #$46
   stx test_results + 80
   lda #$6a
   sta test_buffer_z
   lda #3
   bit test_buffer_z
   bvs bit_ov_ok
   sty test_results + 80
bit_ov_ok   
   ldx #$47
   ldy #$48
   stx test_results + 81
   lda #$2a
   sta test_buffer_z
   lda #3
   bit test_buffer_z
   bvc bit_nov_ok
   sty test_results + 81
bit_nov_ok   
   ldx #$49
   ldy #$4a
   stx test_results + 82
   lda #$aa
   sta test_buffer_z
   lda #$63
   bit test_buffer_z
   sta test_results + 83
   bne bit_nz_ok
   sty test_results + 82
bit_nz_ok
   ldx #$4b
   ldy #$4c
   stx test_results + 84
   lda #$8c
   sta test_buffer_z
   lda #$63
   bit test_buffer_z
   beq bit_z_ok
   sty test_results + 84
bit_z_ok

   ldx #$10
   ldy #$aa
   lda VSTATUS
   and #VSTATUS_EMULATOR
   bne brk_in_emulator
   lda #$01
   brk                    ; disabled for emulator
   inx
   jmp brk_not_in_emulator
brk_in_emulator
   inx
   iny
brk_not_in_emulator   
   stx test_results + 85
   sty test_results + 86
        
   
   jsr update_results
   
halt:
   nop
   jmp halt
      
   
expected_result:
   .byte $aa, $bb, $cc, $aa, $bb, $cc, $bb, $cc
   .byte $cc, $cc, $bb, $bb, $55, $66, $21, $31
   .byte $3f, $4f, $61, $6f, $03, $05, $13, $32
   .byte $42, $11, $13, $15, $17, $1b, $1d, $21
   .byte $23, $25, $27, $35, $37, $41, $43, $45
   .byte $47, $55, $57, $93, $9f, $a1, $af, $b1
   .byte $bf, $23, $24, $25, $33, $44, $55, $56
   .byte $57, $58, $65, $66, $67, $68, $0b, $1c
   .byte $33, $99, $32, $55, $79, $69, $b4, $a2
   .byte $14, $aa, $54, $56, $01, $03, $41, $43
   .byte $45, $47, $49, $63, $4b, $11, $ab
   .byte 0
   
display_list:
   .byte $42
   .word text_location 
   .word attr_location
.rept (ROWS-1)
   .byte $02
.endr 
   .byte $41

   
display_results:

   mwa #palette_dark SRC_ADDR
   jsr gfx_upload_palette

   mwa #$0000 VADDRW
   mwa #FONT_ROM_ADDR SRC_ADDR
   jsr gfx_upload_font

   mwa #dlist_addr VDLIST   
   mwa #dlist_addr VADDRW
   
   ldx #0
copy_dl:
   lda display_list, x
   sta VDATA
   inx
   bne copy_dl
   
   mwa #text_location DISPLAY_START
   mwa #attr_location ATTRIB_START
   

enable_chroni:
   
   lda VSTATUS
   ora #VSTATUS_ENABLE
   sta VSTATUS

update_results
   mwa DISPLAY_START VADDRW
   mwa ATTRIB_START  VADDRW_AUX

   ldx #0
next_result:   
   ldy #'1'
   lda expected_result,x
   beq no_more_results
   cmp test_results, x
   beq good_result
   ldy #'0'
good_result
   sty VDATA
   lda #$01
   sta VDATA_AUX
   inx
   cpx #72
   beq next_result
   txa
   and #$7
   bne next_result
   lda #$00
   sta VDATA
   sta VDATA_AUX
   jmp next_result
no_more_results   
   rts

palette_dark:
   .word $2104
   .word $9C0A
   .word $BC0E
   .word $43B5

.proc gfx_upload_palette
   lda #0
   sta VPAL_INDEX
   ldx #2
   ldy #0
set_palette:   
   lda (SRC_ADDR), y
   sta VPAL_VALUE
   iny
   bne set_palette
   dex
   bne set_palette
   rts
.endp   

.proc gfx_upload_font
   ldx #4
   ldy #0
upload_next:   
   lda (SRC_ADDR), y
   sta VDATA
   iny
   bne upload_next
   inc SRC_ADDR+1
   dex
   bne upload_next
   rts
.endp

my_irq:
   cmp #$01
   bne not_brk
   cpx #$10
   bne not_brk
   cpy #$aa
   bne not_brk
   inx
   iny
not_brk   
   rti


   org FONT_ROM_ADDR
   ins '../../../res/fonts/charset_atari.bin'

   
   org $FFFA

   .word nmi
   .word boot
   .word my_irq
   
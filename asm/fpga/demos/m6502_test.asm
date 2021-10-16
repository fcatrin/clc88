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
   
   // test inc z, dec z, inc abs, dec abs
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
   jmp display_results
   
expected_result:
   .byte $aa, $bb, $cc, $aa, $bb, $cc, $bb, $cc
   .byte $cc, $cc, $bb, $bb, $55, $66, $21, $31
   .byte $3f, $4f, $61, $6f, $03, $05, $13, $32
   .byte $42, $11, $13, $15, $17
   
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
   
   mwa DISPLAY_START VADDRW
   mwa ATTRIB_START  VADDRW_AUX

enable_chroni:
   
   lda VSTATUS
   ora #VSTATUS_ENABLE
   sta VSTATUS

   ldx #0
next_result:   
   ldy #'1'
   lda test_results,x
   cmp expected_result, x
   beq good_result
   ldy #'0'
good_result
   sty VDATA
   lda #$01
   sta VDATA_AUX
   inx
   txa
   and #$7
   bne noskip
   lda #$00
   sta VDATA
   sta VDATA_AUX
noskip:   
   cpx #29
   bne next_result
   
halt:
   nop
   jmp halt

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

   org FONT_ROM_ADDR
   ins '../../../res/fonts/charset_atari.bin'

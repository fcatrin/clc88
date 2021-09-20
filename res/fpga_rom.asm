   
SRC = $40
   
   org $fffc
   .word START

BG_COLOR = $29AC   
FG_COLOR = $F75B
BORDER_COLOR = $2167
   
   org $fe00
START:

   lda #0
   sta $9002

   LDA #0
   STA $9004
   
   ldx #0
set_palette:   
   lda palette_dark, x
   STA $9005
   inx
   bne set_palette

   lda #<BORDER_COLOR
   sta $900c

   lda #>BORDER_COLOR
   sta $900d
   
// copy 16*256 bytes from $e000 to VRAM $00000

   lda #0
   sta $9006
   sta $9007
   sta $9008
   sta SRC
   lda #$e0
   sta SRC+1
   
   ldx #0
   ldy #0
copy:   
   lda (SRC), y
   sta $9009
   iny
   bne copy
   inc SRC+1
   inx
   cpx #16
   bne copy

   ldx #0
load5:
   lda display_list, x
   sta dlist_in_ram, x
   inx
   bne load5
   
dlist_addr    = $1d00
dlist_in_vram = dlist_addr / 2
dlist_in_ram  = dlist_addr + $a000

   lda #<dlist_in_vram
   sta $9000
   lda #>dlist_in_vram
   sta $9001
   
   lda #<text_location
   sta $9006
   lda #>text_location
   sta $9007
      
load6:
   LDA test_string, x
   beq load_attr
   sta $9009
   inx
   bne load6
   
load_attr:
   lda #<attr_location
   sta $9006
   lda #>attr_location
   sta $9007
   ldx #0

load7:
   LDA test_attrs, x
   beq halt
   sta $9009
   inx
   bne load7
   
halt:
   JMP halt

text_location = $1e00
attr_location = $1e80

display_list:
   .byte $42
   .word text_location 
   .byte 0
   .word attr_location
   .byte 0
   .byte $02, $02, $02, $41

palette_dark:
   .word $2104
   .word $9C0A
   .word $AC0E
   .word $43B5

test_string:
   .byte 'This is Compy CLC-88 testing VRAM port access and attributes!', 0
   
test_attrs:
   .byte $01, $01, $01, $01, $01, $01, $01, $01, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $02
   .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
   .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
   .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
   
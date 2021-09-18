   org $fffc
   .word START

BG_COLOR = $29AC   
FG_COLOR = $F75B
BORDER_COLOR = $FC6A
   
   org $fe00
START:
   LDA #0
   STA $9004
   
   LDA #<BG_COLOR
   STA $9005
   
   LDA #>BG_COLOR
   STA $9005

   LDA #<FG_COLOR
   STA $9005
   
   LDA #>FG_COLOR
   STA $9005
   
   lda #<BORDER_COLOR
   sta $900c

   lda #>BORDER_COLOR
   sta $900d
   
   LDX #0
load1:
   LDA $e000, x
   sta $a000, x
   inx
   bne load1
load2:
   LDA $e100, x
   sta $a100, x
   inx
   bne load2
load3:
   LDA $e200, x
   sta $a200, x
   inx
   bne load3
load4:
   LDA $e300, x
   sta $a300, x
   inx
   bne load4
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

test_string:
   .byte 'This is Compy CLC-88 testing VRAM port access with autoincrement. Now display list is set via registers!', 0
   
test_attrs:
   .byte $01, $01, $10, $10, $01, $01, $01, $01, $10, $10, $10, $00
   
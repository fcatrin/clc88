   org $fffc
   .word START


text_location = $1e00

   org $fd00
display_list:
   .byte $42, $00, $1e, $00, $02, $02, $02, $41
    
   org $fe00
test_string:
   .byte 'This is Compy CLC-88 testing VRAM port access with autoincrement', 0
   
BG_COLOR = $29AC   
FG_COLOR = $F75B
   
   org $ff00
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
   sta $bd00, x
   inx
   bne load5
   
   lda #<text_location
   sta $9006
   lda #>text_location
   sta $9007
      
load6:
   LDA test_string, x
   beq halt
   sta $9009
   inx
   bne load6
   
halt:
   JMP halt
   
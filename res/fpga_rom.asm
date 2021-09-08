   org $fffc
   .word START

   org $fe00
   .byte 'This is Compy CLC-88'
   
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
   
   LDX #10
load:
   LDA $e030, x
   inx
   bne load
halt:
   JMP halt
   
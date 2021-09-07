   org $fffc
   .word START

   org $fe00
   .byte 'This is Compy CLC-88'
   
   org $ff00
START:
   LDA #0
   STA $9004
   
   LDA #1
   STA $9005
   
   LDA #0
   STA $9005
   
   LDX #10
load:
   LDA $e030, x
   inx
   bne load
halt:
   JMP halt
   
   org $fffc
   .word START

   org $fe00
   .byte 'This is Compy CLC-88'
   
   org $ff00
START:
   LDX #10
load:
   LDA $e030, x
   inx
   bne load
   JMP START
   
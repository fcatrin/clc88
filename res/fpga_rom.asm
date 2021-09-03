   org $fffc
   .word START

   org $fe00
   .byte 'This is Compy CLC-88'
   
   org $ff00
START:
   LDA #$92
   JMP START
   
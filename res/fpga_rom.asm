   org $fffc
   .word START
   
   org $ff00
START:
   LDA #92
   JMP START
   
   org $fffe
   .word START
   
   org $ff00
START:
   LDA #92
   JMP START
   
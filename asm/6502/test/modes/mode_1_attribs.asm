   icl '../../os/symbols.asm'
   
   org BOOTADDR

   lda #1
   sta ROS7
   lda #1
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

; copy test attrbutes
   mwa ATTRIB_START VADDR
   
   ldy #0
copy_attribs:   
   lda attribs, y
   beq display_message
   sta VDATA
   iny
   bne copy_attribs
   
display_message:
   mwa DISPLAY_START VADDR
   
   ldy #0
copy:
   lda message, y
   cmp #255
   beq stop
   sta VDATA
   iny
   bne copy
   
stop:
   jmp stop

   
message:
   .byte 'This is a multi color text using attributes', 255
attribs: 
.rept 5
   .byte $9F
.endr

.rept 5
   .byte $94
.endr

.rept 5
   .byte $92
.endr

.rept 5
   .byte $93
.endr

.rept 7
   .byte $9A
.endr

.rept 16
   .byte $F9
.endr
   .byte $00

   icl '../../os/stdlib.asm'

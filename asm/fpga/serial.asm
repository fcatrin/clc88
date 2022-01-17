.proc serial_init
   lda #$ff
   sta SERIAL_BLOCK_NDX
   lda #$00
   sta SERIAL_BLOCK_TYPE
   sta SERIAL_BLOCK_SIZE
   rts
.endp

; reads one byte from a buffered serial port
; returns:
; a = byte read
; n flag = 1 on EOF

.proc serial_get
   inc SERIAL_BLOCK_NDX
   ldx SERIAL_BLOCK_NDX
   cpx SERIAL_BLOCK_SIZE
   bne get_byte
   lda SERIAL_BLOCK_TYPE     ; Get next block, if any
   cmp #SERIAL_EOF_MARK
   bne get_block
   ldx #$80                  ; EOF
   rts
   
get_block:   
   jsr serial_read_block
   jmp serial_get

get_byte:
   lda SERIAL_BUFFER, x
   ldx #$00
   rts
.endp

.proc serial_read_block
   lda #65
   sta SYS_SERIAL_OUT
   
   ldx #0
   
wait:
   lda SYS_SERIAL_READY
   beq wait
   
   lda SYS_SERIAL_IN
   sta SERIAL_BUFFER, x
   inx
   cpx #SERIAL_BLOCK_LAST
   bne wait
   
   lda #$ff
   sta SERIAL_BLOCK_NDX
   rts
.endp
copy_block_with_params:
   ldy #5
copy_block_params:
   lda (COPY_PARAMS), y
   sta SRC_ADDR, y
   dey
   bpl copy_block_params

copy_block:
   ldy #0
copy_block_short:
   lda (SRC_ADDR), y
   sta (DST_ADDR), y
   iny
   cpy SIZE
   bne copy_block_short
   inc SRC_ADDR+1
   inc DST_ADDR+1
copy_skip_short:
   lda SIZE+1
   beq copy_block_end
   dec SIZE+1
   jmp copy_block_short
copy_block_end
   rts

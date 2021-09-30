.proc gfx_upload_palette
   lda #0
   sta VPAL_INDEX
   ldx #2
   ldy #0
set_palette:   
   lda (SRC_ADDR), y
   STA VPAL_VALUE
   iny
   bne set_palette
   dex
   bne set_palette
   rts
.endp   

.proc gfx_upload_font
   ldx #4
   ldy #0
upload_next:   
   lda (SRC_ADDR), y
   sta VDATA
   iny
   bne upload_next
   inc SRC_ADDR+1
   dex
   bne upload_next
   rts
.endp
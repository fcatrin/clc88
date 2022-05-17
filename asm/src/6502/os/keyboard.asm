.proc keyb_poll
   lda KEY_STATUS + 8
   and #$3F
   sta KEY_META
   lda KEY_STATUS + 15
   sta KEY_PRESSED
   rts
.endp

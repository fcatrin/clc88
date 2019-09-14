keyb_poll:
	lda KEY_STATUS + 8
	and #$3F
	sta KEY_META
	rts
	
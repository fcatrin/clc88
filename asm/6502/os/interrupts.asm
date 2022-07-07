
.proc interrupts_init
    ldx #0
copy_vector:
    lda interrupt_vectors, x
    sta NMI_VECTOR, x
    inx
    cpx #$0C
    bne copy_vector
    rts
.endp

; ROM NMI and IRQ handlers detect the source of the interrupt
; then they redirect to specific handlers
;
; Default specific handlers do basic stuff then redirect to user defined handlers
; User code can override these specific handlers to take full control

interrupt_vectors:
   .word nmi_os
   .word irq_os
   .word hblank_os    ; default value for HBLANK_VECTOR
   .word vblank_os    ; default value for VBLANK_VECTOR
   .word hblank_user  ; user handler ran from hblank_os
   .word vblank_user  ; user handler ran from vblank_os

; NMI can be triggered from
; * Horizontal Blank
; * Vertical Blank

nmi_os:
   cld
   bit VSTATUS
   bvc nmi_check_vblank
   jmp (HBLANK_VECTOR)
nmi_check_vblank:
   bpl nmi_done
   jmp (VBLANK_VECTOR)
nmi_done:
   rti

; IRQ is not used for now
irq_os:
   cld
   pha
   lda IRQ_VECTOR
   ora IRQ_VECTOR+1
   beq no_user_interrupt
   pla
   jmp (IRQ_VECTOR)
no_user_interrupt:
   pla
   rti

; OS HBLANK handler
; Just calls the user handler

hblank_os:
   jsr call_hblank_user
   rti

; OS VBLANK handler
; * Increments FRAMECOUNT
; * Use CHRONI_ENABLED to enable or disable Chroni in sync with VB
; * Finally calls user handler

vblank_os:
    pha
    adw FRAMECOUNT #1

    lda CHRONI_ENABLED
    beq set_chroni_disabled
    lda VSTATUS
    ora #VSTATUS_ENABLE
    sta VSTATUS
    bne chroni_enabled_set
set_chroni_disabled:
    lda VSTATUS
    and #($FF - VSTATUS_ENABLE)
    sta VSTATUS
chroni_enabled_set:
    jsr call_vblank_user
    pla
    rti

vblank_user:
    rts

hblank_user:
    rts

call_vblank_user:
    jmp (VBLANK_VECTOR_USER)

call_hblank_user:
    jmp (HBLANK_VECTOR_USER)

nmi:
	jmp nmi_os
irq:
	jmp irq_os

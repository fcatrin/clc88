#ifndef _Z80PORT_H
#define _Z80PORT_H

typedef struct
{
        void (*reset)(int);                     /* reset callback         */
        int  (*interrupt_entry)(int);   /* entry callback         */
        void (*interrupt_reti)(int);    /* reti callback          */
        int irq_param;                                  /* callback paramater */
} Z80_DaisyChain;

#define Z80_MAXDAISY    4               /* maximum of daisy chan device */

#define Z80_INT_REQ     0x01    /* interrupt request mask               */
#define Z80_INT_IEO     0x02    /* interrupt disable mask(IEO)  */

#define Z80_VECTOR(device,state) (((device)<<8)|(state))

#endif

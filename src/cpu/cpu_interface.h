#ifndef _CPU_INTERFACE_H
#define _CPU_INTERFACE_H

enum
{
        /* line states */
        CLEAR_LINE = 0,                         /* clear (a fired, held or pulsed) line */
        ASSERT_LINE,                            /* assert an interrupt immediately */
        HOLD_LINE,                                      /* hold interrupt line until acknowledged */
        PULSE_LINE,                                     /* pulse interrupt line for one instruction */

        /* internal flags (not for use by drivers!) */
        INTERNAL_CLEAR_LINE = 100 + CLEAR_LINE,
        INTERNAL_ASSERT_LINE = 100 + ASSERT_LINE,

        /* interrupt parameters */
        MAX_IRQ_LINES = 16,                     /* maximum number of IRQ lines per CPU */
        IRQ_LINE_NMI = 127                      /* IRQ line for NMIs */
};

/* get_reg/set_reg constants */
enum
{
        MAX_REGS = 128,                         /* maximum number of register of any CPU */

        /* This value is passed to activecpu_get_reg to retrieve the previous
         * program counter value, ie. before a CPU emulation started
         * to fetch opcodes and arguments for the current instrution. */
        REG_PREVIOUSPC = -1,

        /* This value is passed to activecpu_get_reg to retrieve the current
         * program counter value. */
        REG_PC = -2,

        /* This value is passed to activecpu_get_reg to retrieve the current
         * stack pointer value. */
        REG_SP = -3,

        /* This value is passed to activecpu_get_reg/activecpu_set_reg, instead of one of
         * the names from the enum a CPU core defines for it's registers,
         * to get or set the contents of the memory pointed to by a stack pointer.
         * You can specify the n'th element on the stack by (REG_SP_CONTENTS-n),
         * ie. lower negative values. The actual element size (UINT16 or UINT32)
         * depends on the CPU core. */
        REG_SP_CONTENTS = -4
};

/* Values passed to the cpu_info function of a core to retrieve information */
enum
{
        CPU_INFO_REG,
        CPU_INFO_FLAGS = MAX_REGS,
        CPU_INFO_NAME,
        CPU_INFO_FAMILY,
        CPU_INFO_VERSION,
        CPU_INFO_FILE,
        CPU_INFO_CREDITS,
        CPU_INFO_REG_LAYOUT,
        CPU_INFO_WIN_LAYOUT
};

UINT8 cpu_readop(UINT16 pc);
UINT8 cpu_readop_arg(UINT16 pc);
UINT8 cpu_readmem16(UINT16 addr);
void  cpu_writemem16(UINT16 addr, UINT8 value);
UINT8 cpu_readport16(UINT16 addr);
void  cpu_writeport16(UINT16 addr, UINT8 value);

int   cpu_getactivecpu();
void  change_pc16(UINT16 addr); // callback to inform PC was updated?

#define state_save_register_INT16(A, B, C, D, E)
#define state_save_register_INT8(A, B, C, D, E)
#define state_save_register_UINT16(A, B, C, D, E)
#define state_save_register_UINT8(A, B, C, D, E)

#endif

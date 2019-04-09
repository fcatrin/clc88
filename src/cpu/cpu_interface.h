#ifndef _CPU_INTERFACE_H
#define _CPU_INTERFACE_H

#include "emu.h"
#include "memory.h"

#define MAX_CPU 1

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

int    cpu_getactivecpu();
int    cpu_getexecutingcpu();
void   change_pc16(UINT16 addr); // callback to inform PC was updated?
UINT16 activecpu_get_pc();
int    activecpu_get_icount();

#define state_save_register_INT16(A, B, C, D, E)
#define state_save_register_INT8(A, B, C, D, E)
#define state_save_register_UINT16(A, B, C, D, E)
#define state_save_register_UINT8(A, B, C, D, E)

struct cpu_interface
{
	/* index (used to make sure we mach the enum above */
	unsigned	cpu_num;

	/* table of core functions */
	void		(*init)(void);
	void		(*reset)(void *param);
	void		(*exit)(void);
	int			(*execute)(int cycles);
	void		(*burn)(int cycles);
	unsigned	(*get_context)(void *reg);
	void		(*set_context)(void *reg);
	const void *(*get_cycle_table)(int which);
	void		(*set_cycle_table)(int which, void *new_table);
	unsigned	(*get_reg)(int regnum);
	void		(*set_reg)(int regnum, unsigned val);
	void		(*set_irq_line)(int irqline, int linestate);
	void		(*set_irq_callback)(int(*callback)(int irqline));
	const char *(*cpu_info)(void *context,int regnum);
	unsigned	(*cpu_dasm)(char *buffer,unsigned pc);

	/* IRQ and clock information */
	unsigned	num_irqs;
	int			default_vector;
	int *		icount;
	double		overclock;

	/* memory information */
	int			databus_width;
	mem_read_handler memory_read;
	mem_write_handler memory_write;
	mem_read_handler internal_read;
	mem_write_handler internal_write;
	offs_t		pgm_memory_base;
	void		(*set_op_base)(offs_t pc);
	int			address_shift;
	unsigned	address_bits;
	unsigned	endianess;
	unsigned	align_unit;
	unsigned	max_inst_len;
};

/* return a the total number of registered CPUs */
static INLINE int cpu_gettotalcpu(void)
{
	extern int totalcpu;
	return totalcpu;
}


#endif

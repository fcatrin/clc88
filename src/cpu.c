#include <stdio.h>
#include <stdlib.h>
#include "emu.h"
#include "bus.h"
#include "cpu/m6502/m6502.h"
#include "cpu/z80/z80.h"
#include "cpu/cpu_interface.h"
#include "cpu.h"
#include "monitor.h"

#define LOGTAG "CPU"
#ifdef TRACE_CPU
#define TRACE
#endif
#include "trace.h"

UINT16 cpu_pc;

v_cpu v_6502;
v_cpu v_z80;

int cpu_6502_irq_callback(int irq_line);

static v_cpu* cpu_6502_init() {
	v_6502.exec_break = FALSE;
	m6502_init();
	m6502_set_irq_callback(cpu_6502_irq_callback);
	return &v_6502;
}

static v_cpu* cpu_z80_init() {
	z80_init();
	return &v_z80;
}

v_cpu* cpu_init(enum CpuType cpuType) {
	switch (cpuType) {
	case CPU_M6502:
		return cpu_6502_init();
	default:
		return cpu_z80_init();
	}
}

static void cpu_6502_reset() {
	m6502_reset(NULL);
}

static int cpu_6502_run(int cycles) {
	return m6502_execute(cycles);
}

static void cpu_6502_irq(int do_interrupt) {
	m6502_set_irq_line(0, do_interrupt);
}

static void cpu_6502_nmi(int do_interrupt) {
	m6502_set_irq_line(IRQ_LINE_NMI, do_interrupt);
}

static unsigned cpu_6502_get_reg(int regnum) {
	return m6502_get_reg(regnum);
}

static void cpu_6502_set_reg(int regnum, unsigned val) {
	return m6502_set_reg(regnum, val);
}

static bool cpu_6502_is_ret_op(unsigned addr) {
	UINT8 op = cpu_readop(cpu_pc);
	return op == 0x60 || op == 0x40;
}

static unsigned cpu_6502_disasm(unsigned addr, char *dst) {
	return addr + Dasm6502(dst, addr);
}

static unsigned cpu_6502_get_pc() {
	return m6502_get_reg(M6502_PC);
}

static UINT8 cpu_6502_frame;
static void cpu_6502_set_ret_frame() {
	cpu_6502_frame = m6502_get_reg(M6502_S);
}

static bool cpu_6502_is_ret_frame() {
	return cpu_6502_frame == m6502_get_reg(M6502_S);
}

static void cpu_6502_halt(bool halted) {
	m6502_halt(halted);
}

static bool cpu_6502_is_halted() {
	return m6502_is_halted();
}

static void cpu_z80_reset() {
	z80_reset(NULL);
}

static int cpu_z80_run(int cycles) {
	return z80_execute(cycles);
}

v_cpu v_6502 = {
		CPU_M6502,
		cpu_6502_reset,
		cpu_6502_run,
		cpu_6502_irq,
		cpu_6502_nmi,
		cpu_6502_set_reg,
		cpu_6502_get_reg,
		cpu_6502_get_pc,
		cpu_6502_disasm,
		cpu_6502_is_ret_op,
		cpu_6502_set_ret_frame,
		cpu_6502_is_ret_frame,
		cpu_6502_halt,
		cpu_6502_is_halted
};

v_cpu v_z80 = {
		CPU_Z80,
		cpu_z80_reset,
		cpu_z80_run,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL
};

UINT8 cpu_readop(UINT16 pc) {
	return bus_read16(pc);
}
UINT8 cpu_readop_arg(UINT16 pc) {
	return bus_read16(pc);
}
UINT8 cpu_readmem16(UINT16 addr) {
	return bus_read16(addr);
}
void  cpu_writemem16(UINT16 addr, UINT8 value) {
	bus_write16(addr, value);
}
UINT8 cpu_readport16(UINT16 addr) {
	return bus_read16(addr);
}
void  cpu_writeport16(UINT16 addr, UINT8 value) {
	bus_write16(addr, value);
}

int cpu_6502_irq_callback(int irq_line) {
	return FALSE;
}

int   cpu_getactivecpu() {
	return 1;
}

char dasm[200];
void  change_pc16(UINT16 addr) {
	if (cpu_pc == addr) return;
	cpu_pc = addr;

	v_6502.exec_break = cpu_readop(cpu_pc) == 0x00;

	if (monitor_is_enabled() || monitor_is_stop(addr) || v_6502.exec_break) {
		// printf("monitor is enabled: %s, break is :%s\n", BOOLSTR(monitor_is_enabled()),	BOOLSTR(v_6502.exec_break));
		monitor_enter();
	}

	if (trace_enabled) {

#ifdef MAME_DEBUG
	Dasm6502(dasm, addr);
	LOGV(LOGTAG, "PC %04X %s", addr, dasm);
#else
	LOGV(LOGTAG, "PC %04X %02X", addr, cpu_readop(cpu_pc));
#endif

	}
}

UINT16 activecpu_get_pc() {
	return cpu_pc;
}

long cpunum_get_localtime(int activecpu) {
	return 0;
}
int  get_resource_tag() {
	return 0;
}
int  cpu_getexecutingcpu() {
	return 0;
}
void activecpu_abort_timeslice(){}


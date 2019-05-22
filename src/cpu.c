#include <stdio.h>
#include <stdlib.h>
#include "emu.h"
#include "bus.h"
#include "cpu/m6502/m6502.h"
#include "cpu/z80/z80.h"
#include "cpu/cpu_interface.h"
#include "cpu.h"

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
	if (v_6502.exec_break) exit(0);
	return m6502_execute(cycles);
}

static void cpu_6502_irq(int do_interrupt) {
	m6502_set_irq_line(0, do_interrupt);
}

static void cpu_6502_nmi(int do_interrupt) {
	m6502_set_irq_line(IRQ_LINE_NMI, do_interrupt);
}

static void cpu_z80_reset() {
	z80_reset(NULL);
}

static int cpu_z80_run(int cycles) {
	return z80_execute(cycles);
}

v_cpu v_6502 = {
		cpu_6502_reset,
		cpu_6502_run,
		cpu_6502_irq,
		cpu_6502_nmi
};

v_cpu v_z80 = {
		cpu_z80_reset,
		cpu_z80_run,
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

	//if (addr == 0xF2B2) trace_enabled = TRUE;
	//if (addr == 0xF2D4) trace_enabled = FALSE;

	if (trace_enabled) {

#ifdef MAME_DEBUG
	trace_enabled = FALSE;
	Dasm6502(dasm, addr);
	trace_enabled = TRUE;
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


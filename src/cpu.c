#include <stdio.h>
#include "cpu.h"
#include "emu.h"
#include "bus.h"
#include "cpu/m6502/m6502.h"
#include "cpu/z80/z80.h"
#include "cpu/cpu_interface.h"

v_cpu v_6502;
v_cpu v_z80;

static v_cpu cpu_6502_init() {
	m6502_init();
	return v_6502;
}

static v_cpu cpu_z80_init() {
	z80_init();
	return v_z80;
}

v_cpu cpu_init(enum CpuType cpuType) {
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

static void cpu_z80_reset() {
	z80_reset(NULL);
}

static int cpu_z80_run(int cycles) {
	return z80_execute(cycles);
}

v_cpu v_6502 = {
		cpu_6502_reset,
		cpu_6502_run
};

v_cpu v_z80 = {
		cpu_z80_reset,
		cpu_z80_run
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

int   cpu_getactivecpu() {
	return 1;
}
void  change_pc16(UINT16 addr) {

}

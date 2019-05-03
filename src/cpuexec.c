#include <stdio.h>
#include "emu.h"
#include "cpu.h"
#include "trace.h"

#define LOGTAG "CPUEXEC"

#define MIN_CYCLES 4

static v_cpu cpu;
static long cycles;
static int  cycles_acum;
static int  cycles_stolen;
static int  halt;

void cpuexec_init(v_cpu vcpu) {
	cpu = vcpu;
	cpu.reset();

	halt   = 0;
	cycles = 0;
	cycles_acum   = 0;
	cycles_stolen = 0;
}

void cpuexec_run(int cycles_to_add) {
	if (halt) return;

	cycles_acum += cycles_to_add;

	int cycles_to_run = cycles_acum - cycles_stolen;
	if (cycles_to_run < MIN_CYCLES) return;

	int cycles_ran = cpu.run(cycles_to_run);
	cycles += cycles_ran;
	cycles_stolen = cycles_ran - cycles_to_run;
	cycles_acum = 0;
}

void cpuexec_halt(int halted) {
	halt = halted;
}

void cpuexec_irq(int do_interrupt) {
	cpu.irq(do_interrupt);
}

void cpuexec_nmi(int do_interrupt) {
	cpu.nmi(do_interrupt);
}

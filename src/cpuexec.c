#include <stdio.h>
#include "emu.h"
#include "cpu.h"
#include "frontend/frontend.h"

#define LOGTAG "CPUEXEC"
#ifdef TRACE_CPUEXEC
#define TRACE
#endif
#include "trace.h"

#define MIN_CYCLES 4

static v_cpu *cpu;
static long cycles;
static int  cycles_acum;
static int  cycles_stolen;
static int  halt;

void cpuexec_init(v_cpu *vcpu) {
	cpu = vcpu;
	cpu->reset();

	halt   = 0;
	cycles = 0;
	cycles_acum   = 0;
	cycles_stolen = 0;
}

void cpuexec_run(int cycles_to_add) {
	LOGV(LOGTAG, "cpuexec_run cycles_to_add:%d halted:%s", cycles_to_add, (cpu->is_halted() ? "true" : "false"));
	if (cpu->is_halted() || !frontend_running()) {
		cycles_acum   = 0;
		cycles_stolen = 0;
		return;
	}

	cycles_acum += cycles_to_add;

	int cycles_to_run = cycles_acum - cycles_stolen;
	if (cycles_to_run < MIN_CYCLES) return;

	int cycles_ran = cpu->run(cycles_to_run);
	LOGV(LOGTAG, "cpuexec_run cycles_to_run: %d cycles_ran:%d halted:%s", cycles_to_run, cycles_ran, (cpu->is_halted() ? "true" : "false"));

	if (cpu->is_halted()) cycles_ran = cycles_to_run;

	cycles += cycles_ran;
	cycles_stolen = cycles_ran - cycles_to_run;
	cycles_acum = 0;
}

void cpuexec_halt(int halted) {
	LOGV(LOGTAG, "cpuexec_halt: %s", (halted ? "true": "false"));
	cpu->halt(halted);
}

void cpuexec_irq(int do_interrupt) {
	cpu->irq(do_interrupt);
}

void cpuexec_nmi(int do_interrupt) {
	cpu->nmi(do_interrupt);
}

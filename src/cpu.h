#ifndef __CPU_H__
#define __CPU_H__

#define MAX_CPU 1

enum CpuType {CPU_M6502, CPU_Z80};

typedef struct {
	void (*reset)();
	int  (*run)(int cycles);
	void (*irq)(int do_interrupt);
	void (*nmi)(int do_interrupt);
} v_cpu;

v_cpu cpu_init(enum CpuType cpuType);
void  cpu_reset(v_cpu *cpu);
int   cpu_run(v_cpu *cpu, int cycles);

/* MAME facade */

long cpunum_get_localtime(int activecpu);
int  get_resource_tag();
int  cpu_getexecutingcpu();

UINT16 activecpu_get_pc();
void   activecpu_abort_timeslice();

#endif

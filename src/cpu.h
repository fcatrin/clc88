#ifndef __CPU_H__
#define __CPU_H__

enum CpuType {CPU_M6502, CPU_Z80};

typedef struct {
	void (*reset)();
	int  (*run)(int cycles);
} v_cpu;

v_cpu cpu_init(enum CpuType cpuType);
void  cpu_reset(v_cpu *cpu);
int   cpu_run(v_cpu *cpu, int cycles);


#endif

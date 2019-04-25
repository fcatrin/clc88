#ifndef _CPUEXEC_H
#define _CPUEXEC_H

#define CPU_GO(cycles) cpuexec_run(cycles)
#define CPU_HALT cpuexec_halt(true)
#define CPU_PROCEED cpuexec_halt(false)

void cpuexec_init(v_cpu vcpu);
void cpuexec_run(int cycles);
void cpuexec_halt(int halted);

#endif

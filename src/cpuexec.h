#ifndef _CPUEXEC_H
#define _CPUEXEC_H

#define CPU_GO(cycles) cpuexec_run(cycles)
#define CPU_HALT() cpuexec_halt(1)
#define CPU_RESUME() cpuexec_halt(0)

void cpuexec_init(v_cpu *vcpu);
void cpuexec_run(int cycles);
void cpuexec_halt(int halted);
void cpuexec_irq(int do_interrupt);
void cpuexec_nmi(int do_interrupt);

#endif

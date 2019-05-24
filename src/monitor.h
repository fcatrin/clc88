#ifndef _MONITOR_H
#define _MONITOR_H

void monitor_init(v_cpu *cpu);

void monitor_enable();
void monitor_disable();

bool monitor_is_enabled();
bool monitor_is_breakpoint(unsigned addr);
bool monitor_is_stop(unsigned addr);

void monitor_enter();

#endif

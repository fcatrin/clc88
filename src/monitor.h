#ifndef _MONITOR_H
#define _MONITOR_H

void monitor_init(v_cpu *cpu);

void monitor_enable();
void monitor_disable();

bool monitor_is_enabled();
bool monitor_is_breakpoint(unsigned addr);
void monitor_breakpoint_set(unsigned addr);
void monitor_breakpoint_del(unsigned index);
bool monitor_is_stop(unsigned addr);

void monitor_enter();

void monitor_source_init();
void monitor_source_read_file(char *filename);

#endif

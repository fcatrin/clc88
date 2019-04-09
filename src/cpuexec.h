#ifndef _CPUEXEC_H
#define _CPUEXEC_H


/* Returns the current local time for a CPU, relative to the current timeslice */
double cpunum_get_localtime(int cpunum);
void   activecpu_abort_timeslice(void);

#endif

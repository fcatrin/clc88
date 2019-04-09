#include "emu.h"
#include "cpu_interface.h"

static UINT16 cpu_pc;

/*************************************
 *
 *	Other variables we own
 *
 *************************************/

int activecpu;		/* index of active CPU (or -1) */
int executingcpu;	/* index of executing CPU (or -1) */
int totalcpu;		/* total number of CPUs */

struct cpuinfo
{
	struct cpu_interface intf; 		/* copy of the interface data */
	int cputype; 					/* type index of this CPU */
	int family; 					/* family index of this CPU */
	void *context;					/* dynamically allocated context buffer */
};

static struct cpuinfo cpu[MAX_CPU];

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

int cpu_getactivecpu() {
	return 1;
}

int cpu_getexecutingcpu() {
	return 1;
}

void  change_pc16(UINT16 addr) {
	cpu_pc = addr;
}

UINT16 activecpu_get_pc() {
	return cpu_pc;
}

/*************************************
 *
 *	Interfaces to the active CPU
 *
 *************************************/

/*--------------------------
 	Adjust/get icount
--------------------------*/

void activecpu_adjust_icount(int delta)
{
	VERIFY_ACTIVECPU_VOID(activecpu_adjust_icount);
	*cpu[activecpu].intf.icount += delta;
}


int activecpu_get_icount(void)
{
	VERIFY_ACTIVECPU(0, activecpu_get_icount);
	return *cpu[activecpu].intf.icount;
}

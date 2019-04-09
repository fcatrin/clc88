#include <stdio.h>
#include "cpu/cpu_interface.h"

/*************************************
 *
 *	Macros to help verify executing CPU
 *
 *************************************/

#define VERIFY_EXECUTINGCPU(retval, name)					\
	int activecpu = cpu_getexecutingcpu();					\
	if (activecpu < 0)										\
	{														\
		logerror(#name "() called with no executing cpu!\n");\
		return retval;										\
	}

#define VERIFY_EXECUTINGCPU_VOID(name)						\
	int activecpu = cpu_getexecutingcpu();					\
	if (activecpu < 0)										\
	{														\
		logerror(#name "() called with no executing cpu!\n");\
		return;												\
	}


/*************************************
 *
 *	Macros to help verify CPU index
 *
 *************************************/

#define VERIFY_CPUNUM(retval, name)							\
	if (cpunum < 0 || cpunum >= cpu_gettotalcpu())			\
	{														\
		logerror(#name "() called for invalid cpu num!\n");	\
		return retval;										\
	}

#define VERIFY_CPUNUM_VOID(name)							\
	if (cpunum < 0 || cpunum >= cpu_gettotalcpu())			\
	{														\
		logerror(#name "() called for invalid cpu num!\n");	\
		return;												\
	}


struct cpuinfo
{
	int		suspend;				/* suspend reason mask (0 = not suspended) */
	int		nextsuspend;			/* pending suspend reason mask */
	int		eatcycles;				/* true if we eat cycles while suspended */
	int		nexteatcycles;			/* pending value */
	int		trigger;				/* pending trigger to release a trigger suspension */

	int 	iloops; 				/* number of interrupts remaining this frame */

	UINT64 	totalcycles;			/* total CPU cycles executed */
	double	localtime;				/* local time, relative to the timer system's global time */
	double	clockscale;				/* current active clock scale factor */

	int 	vblankint_countdown;	/* number of vblank callbacks left until we interrupt */
	int 	vblankint_multiplier;	/* number of vblank callbacks per interrupt */
	void *	vblankint_timer;		/* reference to elapsed time counter */
	double	vblankint_period;		/* timing period of the VBLANK interrupt */

	void *	timedint_timer;			/* reference to this CPU's timer */
	double	timedint_period; 		/* timing period of the timed interrupt */
};

static struct cpuinfo cpu[MAX_CPU];

/*************************************
 *
 *	General CPU variables
 *
 *************************************/

static struct cpuinfo cpu[MAX_CPU];

static int time_to_reset;
static int time_to_quit;

static int vblank;
static int current_frame;
static INT32 watchdog_counter;

static int cycles_running;
static int cycles_stolen;


/*************************************
 *
 *	Return cycles ran this iteration
 *
 *************************************/

int cycles_currently_ran(void)
{
	VERIFY_EXECUTINGCPU(0, cycles_currently_ran);
	return cycles_running - activecpu_get_icount();
}

/*************************************
 *
 *	Return the current local time for
 *	a CPU, relative to the current
 *	timeslice
 *
 *************************************/

double cpunum_get_localtime(int cpunum)
{
	double result;

	VERIFY_CPUNUM(0, cpunum_get_localtime);

	/* if we're active, add in the time from the current slice */
	result = cpu[cpunum].localtime;
	if (cpunum == cpu_getactivecpu())
	{
		int cycles = cycles_currently_ran();
		result += TIME_IN_CYCLES(cycles, cpunum);
	}
	return result;
}

/*************************************
 *
 *	Abort the timeslice for the
 *	active CPU
 *
 *************************************/

void activecpu_abort_timeslice(void)
{
	int current_icount;

	VERIFY_EXECUTINGCPU_VOID(activecpu_abort_timeslice);
	LOG(("activecpu_abort_timeslice (CPU=%d, cycles_left=%d)\n", cpu_getexecutingcpu(), activecpu_get_icount() + 1));

	/* swallow the remaining cycles */
	current_icount = activecpu_get_icount() + 1;
	cycles_stolen += current_icount;
	cycles_running -= current_icount;
	activecpu_adjust_icount(-current_icount);
}


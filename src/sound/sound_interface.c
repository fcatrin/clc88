#include "../timer.h"
#include "sound_interface.h"

static void *sound_update_timer;
static double refresh_period_inv;

int sound_scalebufferpos(int value)
{
	int result = (int)((double)value * timer_timeelapsed(sound_update_timer) * refresh_period_inv);
	if (value >= 0) return (result < value) ? result : value;
	else return (result > value) ? result : value;
}

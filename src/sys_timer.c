#include <stdio.h>
#include "emu.h"
#include "sys_timer.h"

void sys_timer_reset(sys_timer *timer) {
	timer->elapsed = 0;
	timer->timeout = 0;
	timer->enabled = 0;
	timer->triggered = FALSE;
}

void sys_timer_enable(sys_timer *timer, bool enabled) {
	timer->enabled = enabled;
}

bool sys_timer_is_enabled(sys_timer *timer) {
	return timer->enabled;
}

void sys_timer_set(sys_timer *timer, UINT32 microseconds) {
	timer->timeout = microseconds & 0xFFFFF; // hardware timers have a 20 bits resolution
}

void sys_timer_run(sys_timer *timer, UINT32 microseconds) {
	timer->elapsed += microseconds;

	if (timer->elapsed >= timer->timeout) {
		timer->triggered = TRUE && timer->enabled;
		timer->elapsed -= timer->timeout;
	}
}

bool sys_timer_is_triggered(sys_timer *timer) {
	return timer->triggered;
}

void sys_timer_clear(sys_timer *timer) {
	timer->triggered = FALSE;
}

UINT32 sys_timer_elapsed(sys_timer *timer) {
	return timer->elapsed;
}

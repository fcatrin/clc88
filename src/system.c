#include "system.h"

#include <stdio.h>
#include "emu.h"
#include "sys_timer.h"

#define MAX_TIMERS 8

sys_timer timers[MAX_TIMERS];

UINT8 sys_cpu_speed = 0;
UINT8 timer_index = 0;

UINT32 timeout;
UINT8 sys_timer_irq;

void system_register_write(UINT8 index, UINT8 value) {

	sys_timer *timer = &timers[timer_index];

	switch(index & 0x03) {
	case 0 : sys_cpu_speed = value & 0x3; break;
	case 1 : timer_index = value & 0x3; break;
	case 2 : timeout = (timeout & 0xFFF00) | value      ; break;
	case 3 : timeout = (timeout & 0xF00FF) | value <<  8; break;
	case 4 : timeout = (timeout & 0x0FFFF) | value << 16; break;
	case 5 : sys_timer_set(timer, timeout); break;
	case 6 : sys_timer_enable(timer, value); break;
	case 7 : sys_timer_clear(timer); break;
	}

}

UINT8 system_register_read(UINT8 index) {
	sys_timer *timer = &timers[timer_index];

	switch(index & 0x03) {
	case 0 : return sys_cpu_speed;
	case 1 : return timer_index;
	case 2 : return sys_timer_elapsed(timer) & 0x000FF;
	case 3 : return (sys_timer_elapsed(timer) & 0x0FF00) >> 8;
	case 4 : return (sys_timer_elapsed(timer) & 0xF0000) >> 16;
	case 6 : return sys_timer_is_enabled(timer);
	case 7 : return sys_timer_irq;
	}
	return 0;
}

void system_run(UINT32 microseconds) {
	for(int i=0; i<MAX_TIMERS; i++) {
		sys_timer *timer = &timers[i];
		sys_timer_run(timer, microseconds);
		sys_timer_irq = (sys_timer_irq << 1) | (sys_timer_is_triggered(timer) ? 1 : 0);
	}
}

bool system_has_irq() {
	return sys_timer_irq != 0;
}

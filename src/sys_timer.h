#ifndef __TIMER_H__
#define __TIMER_H__

typedef struct {
	unsigned elapsed;
	unsigned timeout;
	bool triggered;
} sys_timer;

void sys_timer_reset(sys_timer *timer);
void sys_timer_set(sys_timer *timer, UINT32 microseconds);
void sys_timer_run(sys_timer *timer, UINT32 microseconds);
bool sys_timer_is_triggered(sys_timer *timer);
void sys_timer_clear(sys_timer *timer);

#endif

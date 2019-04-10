#ifndef __MACHINE_H
#define __MACHINE_H

typedef struct {
	int sample_rate;
	int stereo;
} MachineDef;

extern MachineDef *Machine;

void machine_init();

#endif

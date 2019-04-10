#include "machine.h"

static MachineDef clc88_machine;
MachineDef *Machine;

void machine_init() {
	clc88_machine.sample_rate = 44100;
	clc88_machine.stereo = 1;
	Machine = &clc88_machine;
}

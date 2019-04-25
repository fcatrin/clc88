#include <stdio.h>
#include <stdlib.h>
#include "emu.h"
#include "frontend/frontend.h"
#include "cpu.h"
#include "cpuexec.h"
#include "memory.h"
#include "machine.h"
#include "video/screen.h"
#include "utils.h"
#include "video/chroni.h"

int main(int argc, char *argv[]) {
	if (frontend_init(argc, argv)) return 1;

	screen_init();

	machine_init();

	utils_load_xex("../asm/os/6502os.xex");

	v_cpu cpu;

	cpu = cpu_init(CPU_M6502);
	cpuexec_init(cpu);

	chroni_run();
	screen_update();

	frontend_sleep(5);
	frontend_done();

	return 0;
}
